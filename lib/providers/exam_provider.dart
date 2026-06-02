import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/exam_model.dart';
import '../models/test_model.dart';
import '../services/api_service.dart';
import '../utils/resource_manager.dart';
import '../services/offline_exam_service.dart';
import '../services/connectivity_manager.dart';

enum LoadState { idle, loading, error, loaded }

class ExamProvider with ChangeNotifier, NotifierResourceDisposal {
  final ApiService _apiService = ApiService();
  String get baseUrl => _apiService.baseUrl;
  
  final List<Exam> _exams = [];
  bool _isLoading = false;
  String? _currentAttemptId;
  String? _currentExamId;
  
  // Attempt State
  int _currentQuestionIndex = 0;
  Map<String, String> _userAnswers = {}; // questionId -> answer
  int _remainingSeconds = 0;
  Timer? _timer;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  bool _isDisposed = false;
  Future<void> _pendingAttemptSave = Future.value();
  Set<String> _visitedQuestionIds = {};
  Set<String> _markedForReview = {};

  ExamProvider() {
    _initConnectivityListener();
  }

  void _initConnectivityListener() {
    ConnectivityManager().initialize().then((_) {
      _connectivitySubscription = ConnectivityManager().statusChanges.listen((status) async {
        if (_isDisposed) return;
        if (status != ConnectivityResult.none) {
          debugPrint('[ExamProvider] Connectivity restored. Checking for resumable exam...');
          final cached = await checkForResumableExam();
          if (_isDisposed) return;
          if (cached != null && _currentAttemptId == null) {
            debugPrint('[ExamProvider] Found resumable exam, restoring state.');
            await resumeExam(cached);
          }
        }
      });
    }).catchError((e) {
      debugPrint('[ExamProvider] Failed to initialize connectivity listener: $e');
    });
  }


  // Added states for announcements and scheduled tests
  List<Announcement> _announcements = [];
  LoadState _announcementsState = LoadState.idle;
  String? _announcementsError;

  List<Exam> _scheduledTests = [];
  List<String> _completedExamIds = [];
  LoadState _testsState = LoadState.idle;
  final Map<String, double> _examDifficulties = {};

  List<Exam> get exams => _exams;
  bool get isLoading => _isLoading;
  int get currentQuestionIndex => _currentQuestionIndex;
  Map<String, String> get userAnswers => _userAnswers;
  int get remainingSeconds => _remainingSeconds;
  String? get currentAttemptId => _currentAttemptId;
  String? get currentExamId => _currentExamId;
  Set<String> get visitedQuestionIds => _visitedQuestionIds;
  Set<String> get markedForReview => _markedForReview;

  List<Announcement> get announcements => _announcements;
  LoadState get announcementsState => _announcementsState;
  String? get announcementsError => _announcementsError;

  List<Exam> get scheduledTests => _scheduledTests;
  List<String> get completedExamIds => _completedExamIds;
  LoadState get testsState => _testsState;
  Map<String, double> get examDifficulties => _examDifficulties;

  // ─── Persistence Resumption Engine ───────────────────────────────────────

  Future<void> _saveAttemptToPrefs() async {
    if (_currentAttemptId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('active_attempt_id', _currentAttemptId!);
      await prefs.setString('active_exam_id', _currentExamId ?? '');
      await prefs.setString('active_answers', jsonEncode(_userAnswers));
      await prefs.setInt('active_last_tick', DateTime.now().millisecondsSinceEpoch);
      await prefs.setInt('active_remaining_seconds', _remainingSeconds);
      await prefs.setStringList('active_visited_ids', _visitedQuestionIds.toList());
      await prefs.setStringList('active_marked_review_ids', _markedForReview.toList());
    } catch (e) {
      debugPrint('Error caching exam attempt locally: $e');
    }
  }

  void _scheduleAttemptSave() {
    _pendingAttemptSave = _pendingAttemptSave.then((_) => _saveAttemptToPrefs()).catchError((e) {
      debugPrint('Error scheduling exam attempt save: $e');
    });
  }

  Future<void> _clearAttemptFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('active_attempt_id');
      await prefs.remove('active_exam_id');
      await prefs.remove('active_answers');
      await prefs.remove('active_last_tick');
      await prefs.remove('active_remaining_seconds');
      await prefs.remove('active_visited_ids');
      await prefs.remove('active_marked_review_ids');
    } catch (e) {
      debugPrint('Error clearing cached exam attempt: $e');
    }
  }

  Future<Map<String, dynamic>?> checkForResumableExam() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final attemptId = prefs.getString('active_attempt_id');
      if (attemptId == null) return null;
      
      final examId = prefs.getString('active_exam_id') ?? '';
      final answersRaw = prefs.getString('active_answers') ?? '{}';
      final lastTick = prefs.getInt('active_last_tick') ?? DateTime.now().millisecondsSinceEpoch;
      final cachedRemaining = prefs.getInt('active_remaining_seconds') ?? 0;
      final visitedRaw = prefs.getStringList('active_visited_ids') ?? [];
      final markedRaw = prefs.getStringList('active_marked_review_ids') ?? [];
      
      final elapsedSeconds = (DateTime.now().millisecondsSinceEpoch - lastTick) ~/ 1000;
      final calculatedRemaining = cachedRemaining - elapsedSeconds;

      if (calculatedRemaining <= 0) {
        debugPrint('[ExamProvider] Resumable exam has expired. Triggering auto-submit.');
        try {
          final answers = Map<String, String>.from(jsonDecode(answersRaw));
          List<Map<String, dynamic>> submitPayload = answers.entries.map((e) => {
            'questionId': e.key,
            'answer': e.value,
          }).toList();
          
          await _apiService.submitAnswersWithRetry(
            attemptId: attemptId,
            answers: submitPayload,
            isAutoSubmitted: true,
            autoSubmitReason: '⏰ Exam duration expired while app was closed.',
          );
        } catch (err) {
          debugPrint('[ExamProvider] Failed to auto-submit expired exam on restore: $err');
        } finally {
          await _clearAttemptFromPrefs();
        }
        return null;
      }

      return {
        'attemptId': attemptId,
        'examId': examId,
        'answers': Map<String, String>.from(jsonDecode(answersRaw)),
        'remainingSeconds': calculatedRemaining,
        'visited': visitedRaw,
        'marked': markedRaw,
      };
    } catch (e) {
      debugPrint('Error checking for resumable exam: $e');
      return null;
    }
  }

  Future<bool> resumeExam(Map<String, dynamic> cachedData) async {
    try {
      final remaining = (cachedData['remainingSeconds'] as num?)?.toInt() ?? 0;
      if (remaining <= 0) {
        await _clearAttemptFromPrefs();
        return false;
      }

      _currentAttemptId = cachedData['attemptId'];
      _currentExamId = cachedData['examId'];
      _userAnswers = cachedData['answers'];
      _remainingSeconds = remaining;
      _currentQuestionIndex = 0;
      _visitedQuestionIds = Set<String>.from(cachedData['visited'] ?? []);
      _markedForReview = Set<String>.from(cachedData['marked'] ?? []);
      _startTimer();
      _markCurrentQuestionVisited();
      if (!_isDisposed) notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Resume Exam failed: $e');
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────

  Future<void> loadAnnouncements({String? targetClass}) async {
    _announcementsState = LoadState.loading;
    _announcementsError = null;
    if (!_isDisposed) notifyListeners();
    try {
      _announcements = await _apiService.getAnnouncementsWithRetry(targetClass: targetClass);
      _announcementsState = LoadState.loaded;
    } catch (e) {
      debugPrint('Error loading announcements: $e');
      _announcementsError = 'Failed to load announcements. Please check your internet connection.';
      _announcementsState = LoadState.error;
    }
    if (!_isDisposed) notifyListeners();
  }

  Future<void> loadTests() async {
    _testsState = LoadState.loading;
    if (!_isDisposed) notifyListeners();
    try {
      _scheduledTests = await _apiService.fetchExamsWithRetry();
      _completedExamIds = await _apiService.getCompletedExamIdsWithRetry();
      _testsState = LoadState.loaded;
      if (!_isDisposed) notifyListeners();

      // Load difficulties in the background
      for (var test in _scheduledTests) {
        loadExamDifficulty(test.id);
      }
    } catch (e) {
      debugPrint('Error loading tests: $e');
      _testsState = LoadState.error;
      if (!_isDisposed) notifyListeners();
    }
  }

  Future<void> loadExamDifficulty(String examId) async {
    if (_examDifficulties.containsKey(examId)) return;
    try {
      final diff = await _apiService.fetchExamDifficulty(examId);
      _examDifficulties[examId] = diff;
      if (!_isDisposed) notifyListeners();
    } catch (e) {
      debugPrint('Error loading exam difficulty: $e');
    }
  }

  Future<void> startExam(String examId) async {
    _currentQuestionIndex = 0;
    _userAnswers = {};
    _currentExamId = examId;
    _visitedQuestionIds = {};
    _markedForReview = {};
    
    // Find exam to set duration
    final exam = _scheduledTests.firstWhere((e) => e.id == examId);
    _remainingSeconds = exam.duration * 60;
    
    // Auto-mark first question as visited
    if (exam.questions.isNotEmpty) {
      _visitedQuestionIds.add(exam.questions[0].id);
    }
    
    try {
      final attemptData = await _apiService.startAttemptWithRetry(examId);
      _currentAttemptId = attemptData['id'] ?? attemptData['_id'] ?? '';
      
      // If server returns calculated remainingSeconds, override it!
      if (attemptData['remainingSeconds'] != null) {
        _remainingSeconds = (attemptData['remainingSeconds'] as num).toInt();
      }
      
      await _saveAttemptToPrefs();
      _startTimer();
      if (!_isDisposed) notifyListeners();
    } catch (e) {
      debugPrint('Error starting exam: $e');
      _timer?.cancel();
      _currentAttemptId = null;
      _currentExamId = null;
      _remainingSeconds = 0;
      _userAnswers = {};
      _visitedQuestionIds = {};
      _markedForReview = {};
      await _clearAttemptFromPrefs();
      rethrow;
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = createSafeTimer(const Duration(seconds: 1), (timer) async {
      if (_isDisposed || _currentAttemptId == null) {
        timer.cancel();
        return;
      }
      if (_remainingSeconds > 0) {
        _remainingSeconds--;
        if (_remainingSeconds % 5 == 0) {
            _scheduleAttemptSave();
        }
        if (!_isDisposed) notifyListeners();
      } else {
        _timer?.cancel();
      }
    });
  }

  Future<void> startExamOffline(String examId, int remainingSecs) async {
    _currentQuestionIndex = 0;
    _userAnswers = {};
    _currentExamId = examId;
    _currentAttemptId = 'offline_$examId';
    _remainingSeconds = remainingSecs;
    _visitedQuestionIds = {};
    _markedForReview = {};
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final answersRaw = prefs.getString('offline_answers_$examId');
      if (answersRaw != null) {
        _userAnswers = Map<String, String>.from(jsonDecode(answersRaw));
      }
      final visitedRaw = prefs.getStringList('offline_visited_$examId') ?? [];
      _visitedQuestionIds = Set<String>.from(visitedRaw);
      final markedRaw = prefs.getStringList('offline_marked_$examId') ?? [];
      _markedForReview = Set<String>.from(markedRaw);
    } catch (e) {
      debugPrint('Error loading cached offline answers: $e');
    }
    
    // Auto-mark first question as visited if empty
    final exam = _scheduledTests.firstWhere((e) => e.id == examId);
    if (_visitedQuestionIds.isEmpty && exam.questions.isNotEmpty) {
      _visitedQuestionIds.add(exam.questions[0].id);
    }
    
    await _saveAttemptToPrefs();
    _startTimer();
    if (!_isDisposed) notifyListeners();
  }

  void setAnswer(String questionId, String answer) {
    _userAnswers[questionId] = answer;
    _scheduleAttemptSave();
    
    if (_currentAttemptId != null && _currentAttemptId!.startsWith('offline_')) {
      final response = OfflineResponse(
        responseId: '${_currentAttemptId}_$questionId',
        examId: _currentExamId!,
        questionId: questionId,
        selectedAnswer: answer,
        timeSpent: 0,
        answeredAt: DateTime.now(),
      );
      OfflineExamService().saveOfflineResponse(response);
      SharedPreferences.getInstance().then((prefs) {
        prefs.setString('offline_answers_$_currentExamId', jsonEncode(_userAnswers));
      });
    }
    
    if (!_isDisposed) notifyListeners();
  }

  void nextQuestion(int totalQuestions) {
    if (_currentQuestionIndex < totalQuestions - 1) {
      _currentQuestionIndex++;
      _markCurrentQuestionVisited();
      if (!_isDisposed) notifyListeners();
    }
  }

  void previousQuestion() {
    if (_currentQuestionIndex > 0) {
      _currentQuestionIndex--;
      _markCurrentQuestionVisited();
      if (!_isDisposed) notifyListeners();
    }
  }

  void jumpToQuestion(int index) {
    if (index >= 0 && index != _currentQuestionIndex) {
      _currentQuestionIndex = index;
      _markCurrentQuestionVisited();
      if (!_isDisposed) notifyListeners();
    }
  }

  void markAsVisited(String questionId) {
    if (!_visitedQuestionIds.contains(questionId)) {
      _visitedQuestionIds.add(questionId);
      _scheduleAttemptSave();
      
      if (_currentAttemptId != null && _currentAttemptId!.startsWith('offline_')) {
        SharedPreferences.getInstance().then((prefs) {
          prefs.setStringList('offline_visited_$_currentExamId', _visitedQuestionIds.toList());
        });
      }
      
      if (!_isDisposed) notifyListeners();
    }
  }

  void toggleMarkForReview(String questionId) {
    if (_markedForReview.contains(questionId)) {
      _markedForReview.remove(questionId);
    } else {
      _markedForReview.add(questionId);
    }
    _scheduleAttemptSave();
    
    if (_currentAttemptId != null && _currentAttemptId!.startsWith('offline_')) {
      SharedPreferences.getInstance().then((prefs) {
        prefs.setStringList('offline_marked_$_currentExamId', _markedForReview.toList());
      });
    }
    
    if (!_isDisposed) notifyListeners();
  }

  void _markCurrentQuestionVisited() {
    if (_currentExamId == null) return;
    try {
      final exam = _scheduledTests.firstWhere((e) => e.id == _currentExamId);
      if (_currentQuestionIndex >= 0 && _currentQuestionIndex < exam.questions.length) {
        markAsVisited(exam.questions[_currentQuestionIndex].id);
      }
    } catch (e) {
      debugPrint('Error marking current question visited: $e');
    }
  }

  Future<void> submitExam(
    List<Map<String, dynamic>> answers, {
    bool isOffline = false,
    List<Map<String, dynamic>>? violations,
    bool isAutoSubmitted = false,
    String? autoSubmitReason,
    bool emulatorDetected = false,
    bool rootDetected = false,
  }) async {
    if (_currentAttemptId == null) return;
    if (_isLoading) {
      debugPrint('[ExamProvider] submitExam called while already loading. Ignoring duplicate call.');
      return;
    }
    
    _timer?.cancel();
    _isLoading = true;
    if (!_isDisposed) notifyListeners();

    try {
        await _pendingAttemptSave;
      if (isOffline) {
        await OfflineExamService().completeOfflineExam(_currentExamId!);
        for (var ans in answers) {
          final response = OfflineResponse(
            responseId: '${_currentAttemptId}_${ans['questionId']}',
            examId: _currentExamId!,
            questionId: ans['questionId'],
            selectedAnswer: ans['answer'] ?? '',
            timeSpent: 0,
            answeredAt: DateTime.now(),
          );
          await OfflineExamService().saveOfflineResponse(response);
        }
        
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('offline_answers_$_currentExamId');
        } catch (e) {
          debugPrint('Error clearing local offline answers: $e');
        }
      } else {
        await _apiService.submitAnswersWithRetry(
          attemptId: _currentAttemptId!,
          answers: answers,
          violations: violations,
          isAutoSubmitted: isAutoSubmitted,
          autoSubmitReason: autoSubmitReason,
          emulatorDetected: emulatorDetected,
          rootDetected: rootDetected,
        );
      }
      _currentAttemptId = null;
      _currentExamId = null;
      await _clearAttemptFromPrefs();
    } catch (e) {
      debugPrint('Error submitting exam: $e');
      rethrow;
    } finally {
      _isLoading = false;
      if (!_isDisposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _timer?.cancel();
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  /// Fetch student's performance analytics data
  Future<Map<String, dynamic>?> fetchStudentPerformance() async {
    try {
      return await _apiService.getPerformance();
    } catch (e) {
      debugPrint('Error fetching student performance: $e');
      rethrow;
    }
  }
}
