import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/exam_model.dart';
import '../models/test_model.dart';
import '../services/api_service.dart';
import '../utils/resource_manager.dart';
import '../services/offline_exam_service.dart';
import '../services/connectivity_manager.dart';
import '../services/network_time_service.dart';
import '../services/websocket_service.dart';
import '../utils/network_error_handler.dart';

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
          if (kDebugMode) debugPrint('[ExamProvider] Connectivity restored. Checking for resumable exam...');
          final cached = await checkForResumableExam();
          if (_isDisposed) return;
          if (cached != null && _currentAttemptId == null) {
            if (kDebugMode) debugPrint('[ExamProvider] Found resumable exam, restoring state.');
            await resumeExam(cached);
          }
        }
      });
    }).catchError((e) {
      if (kDebugMode) debugPrint('[ExamProvider] Failed to initialize connectivity listener: $e');
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
      await prefs.setInt('active_last_tick', NetworkTimeService().istNow.millisecondsSinceEpoch);
      await prefs.setInt('active_remaining_seconds', _remainingSeconds);
      await prefs.setStringList('active_visited_ids', _visitedQuestionIds.toList());
      await prefs.setStringList('active_marked_review_ids', _markedForReview.toList());
    } catch (e) {
      if (kDebugMode) debugPrint('[ExamProvider] Error caching exam attempt locally: $e');
    }
  }

  void _scheduleAttemptSave() {
    _pendingAttemptSave = _pendingAttemptSave.then((_) => _saveAttemptToPrefs()).catchError((e) {
      if (kDebugMode) debugPrint('[ExamProvider] Error scheduling exam attempt save: $e');
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
      if (kDebugMode) debugPrint('[ExamProvider] Error clearing cached exam attempt: $e');
    }
  }

  Future<Map<String, dynamic>?> checkForResumableExam() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final attemptId = prefs.getString('active_attempt_id');
      if (attemptId == null) return null;
      
      final examId = prefs.getString('active_exam_id') ?? '';
      final answersRaw = prefs.getString('active_answers') ?? '{}';
      final lastTick = prefs.getInt('active_last_tick') ?? NetworkTimeService().istNow.millisecondsSinceEpoch;
      final cachedRemaining = prefs.getInt('active_remaining_seconds') ?? 0;
      final visitedRaw = prefs.getStringList('active_visited_ids') ?? [];
      final markedRaw = prefs.getStringList('active_marked_review_ids') ?? [];
      
      final elapsedSeconds = (NetworkTimeService().istNow.millisecondsSinceEpoch - lastTick) ~/ 1000;
      final calculatedRemaining = cachedRemaining - elapsedSeconds;

      if (calculatedRemaining <= 0) {
          if (kDebugMode) debugPrint('[ExamProvider] Resumable exam expired. Triggering auto-submit.');
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
            if (kDebugMode) debugPrint('[ExamProvider] Failed to auto-submit expired exam on restore.');
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
      if (kDebugMode) debugPrint('[ExamProvider] Error checking for resumable exam: $e');
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
      if (kDebugMode) debugPrint('[ExamProvider] Resume exam failed: $e');
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
      if (kDebugMode) debugPrint('[ExamProvider] Error loading announcements: $e');
      _announcementsError = friendlyNetworkError(e);
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
      if (kDebugMode) debugPrint('[ExamProvider] Error loading tests: $e');
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
      if (kDebugMode) debugPrint('[ExamProvider] Error loading exam difficulty: $e');
    }
  }

  Future<void> startExam(String examId) async {
    if (!ConnectivityManager().isOnline) {
      throw Exception('Exams require an active server connection and live session.');
    }

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

      // Establish WebSocket session for live telemetry & timer sync
      importServicesAndConnectWs(examId);

      if (!_isDisposed) notifyListeners();
    } catch (e) {
      if (kDebugMode) debugPrint('[ExamProvider] Error starting exam: $e');
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

  void importServicesAndConnectWs(String examId) {
    try {
      final wsService = ExamWebSocketService();
      wsService.connect(_currentAttemptId!, examId);
      wsService.onTimeUpdated = (serverSeconds) {
        _remainingSeconds = serverSeconds;
        if (!_isDisposed) notifyListeners();
      };
    } catch (e) {
      if (kDebugMode) debugPrint('[ExamProvider] Failed to connect WebSocket: $e');
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
    throw Exception('Offline examinations are disabled. Active server session is required.');
  }

  void setAnswer(String questionId, String answer) {
    if (_userAnswers[questionId] == answer) {
      _userAnswers.remove(questionId);
    } else {
      _userAnswers[questionId] = answer;
    }
    _scheduleAttemptSave();
    
    // Sync answer continuously over WebSocket (zero trust telemetry)
    if (_currentAttemptId != null && !_currentAttemptId!.startsWith('offline_')) {
      try {
        final syncVal = _userAnswers.containsKey(questionId) ? answer : '';
        ExamWebSocketService().syncAnswer(questionId, syncVal);
      } catch (e) {
        if (kDebugMode) debugPrint('[ExamProvider] WS answer sync failed.');
      }
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
      if (kDebugMode) debugPrint('[ExamProvider] Error marking current question visited: $e');
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
      if (kDebugMode) debugPrint('[ExamProvider] submitExam called while already loading. Ignoring duplicate call.');
      return;
    }
    
    _timer?.cancel();
    _isLoading = true;
    if (!_isDisposed) notifyListeners();

    try {
      ExamWebSocketService().disconnect();
    } catch (e) {
      if (kDebugMode) debugPrint('[ExamProvider] Error disconnecting WS: $e');
    }

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
            answeredAt: NetworkTimeService().istNow,
          );
          await OfflineExamService().saveOfflineResponse(response);
        }
        
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('offline_answers_$_currentExamId');
        } catch (e) {
          if (kDebugMode) debugPrint('[ExamProvider] Error clearing local offline cache: $e');
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
      if (kDebugMode) debugPrint('[ExamProvider] Error submitting exam: $e');
      rethrow;
    } finally {
      _isLoading = false;
      if (!_isDisposed) notifyListeners();
    }
  }

  Future<Map<String, dynamic>> getResult(String attemptId) async {
    _isLoading = true;
    if (!_isDisposed) notifyListeners();
    try {
      final response = await _apiService.getResultWithRetry(attemptId);
      return response['data'] ?? {};
    } catch (e) {
      if (kDebugMode) debugPrint('[ExamProvider] Error getting result: $e');
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
  Future<Map<String, dynamic>?> fetchStudentPerformance({String timeframe = 'week'}) async {
    try {
      final response = await _apiService.getPerformance(timeframe: timeframe);
      if (response['success'] == true && response['data'] != null) {
        return response['data'] as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('[ExamProvider] Error fetching student performance: $e');
      rethrow;
    }
  }
}
