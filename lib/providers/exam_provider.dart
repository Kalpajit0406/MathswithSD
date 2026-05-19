import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/exam_model.dart';
import '../models/test_model.dart';
import '../services/api_service.dart';

enum LoadState { idle, loading, error, loaded }

class ExamProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  
  List<Exam> _exams = [];
  bool _isLoading = false;
  String? _currentAttemptId;
  String? _currentExamId;
  
  // Attempt State
  int _currentQuestionIndex = 0;
  Map<String, String> _userAnswers = {}; // questionId -> answer
  int _remainingSeconds = 0;
  Timer? _timer;

  // Added states for announcements and scheduled tests
  List<Announcement> _announcements = [];
  LoadState _announcementsState = LoadState.idle;
  String? _announcementsError;

  List<Exam> _scheduledTests = [];
  LoadState _testsState = LoadState.idle;

  List<Exam> get exams => _exams;
  bool get isLoading => _isLoading;
  int get currentQuestionIndex => _currentQuestionIndex;
  Map<String, String> get userAnswers => _userAnswers;
  int get remainingSeconds => _remainingSeconds;
  String? get currentAttemptId => _currentAttemptId;
  String? get currentExamId => _currentExamId;

  List<Announcement> get announcements => _announcements;
  LoadState get announcementsState => _announcementsState;
  String? get announcementsError => _announcementsError;

  List<Exam> get scheduledTests => _scheduledTests;
  LoadState get testsState => _testsState;

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
    } catch (e) {
      debugPrint('Error caching exam attempt locally: $e');
    }
  }

  Future<void> _clearAttemptFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('active_attempt_id');
      await prefs.remove('active_exam_id');
      await prefs.remove('active_answers');
      await prefs.remove('active_last_tick');
      await prefs.remove('active_remaining_seconds');
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
      
      final elapsedSeconds = (DateTime.now().millisecondsSinceEpoch - lastTick) ~/ 1000;
      final calculatedRemaining = cachedRemaining - elapsedSeconds;

      if (calculatedRemaining <= 0) {
        await _clearAttemptFromPrefs();
        return null;
      }

      return {
        'attemptId': attemptId,
        'examId': examId,
        'answers': Map<String, String>.from(jsonDecode(answersRaw)),
        'remainingSeconds': calculatedRemaining,
      };
    } catch (e) {
      debugPrint('Error checking for resumable exam: $e');
      return null;
    }
  }

  Future<bool> resumeExam(Map<String, dynamic> cachedData) async {
    try {
      _currentAttemptId = cachedData['attemptId'];
      _currentExamId = cachedData['examId'];
      _userAnswers = cachedData['answers'];
      _remainingSeconds = cachedData['remainingSeconds'];
      _currentQuestionIndex = 0;
      _startTimer();
      notifyListeners();
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
    notifyListeners();
    try {
      _announcements = await _apiService.getAnnouncements(targetClass: targetClass);
      _announcementsState = LoadState.loaded;
    } catch (e) {
      _announcementsError = 'Failed to load announcements';
      _announcementsState = LoadState.error;
    }
    notifyListeners();
  }

  Future<void> loadTests() async {
    _testsState = LoadState.loading;
    notifyListeners();
    try {
      _scheduledTests = await _apiService.fetchExams();
      _testsState = LoadState.loaded;
    } catch (e) {
      _testsState = LoadState.error;
    }
    notifyListeners();
  }

  Future<void> startExam(String examId) async {
    _currentQuestionIndex = 0;
    _userAnswers = {};
    _currentExamId = examId;
    
    // Find exam to set duration
    final exam = _scheduledTests.firstWhere((e) => e.id == examId);
    _remainingSeconds = exam.duration * 60;
    
    try {
      _currentAttemptId = await _apiService.startAttempt(examId);
      await _saveAttemptToPrefs();
      _startTimer();
      notifyListeners();
    } catch (e) {
      debugPrint(e.toString());
      rethrow;
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_remainingSeconds > 0) {
        _remainingSeconds--;
        if (_remainingSeconds % 5 == 0) {
          await _saveAttemptToPrefs();
        }
        notifyListeners();
      } else {
        _timer?.cancel();
      }
    });
  }

  void setAnswer(String questionId, String answer) {
    _userAnswers[questionId] = answer;
    _saveAttemptToPrefs();
    notifyListeners();
  }

  void nextQuestion(int totalQuestions) {
    if (_currentQuestionIndex < totalQuestions - 1) {
      _currentQuestionIndex++;
      notifyListeners();
    }
  }

  void previousQuestion() {
    if (_currentQuestionIndex > 0) {
      _currentQuestionIndex--;
      notifyListeners();
    }
  }

  Future<void> submitExam(List<Map<String, dynamic>> answers) async {
    if (_currentAttemptId == null) return;
    
    _timer?.cancel();
    _isLoading = true;
    notifyListeners();

    try {
      await _apiService.submitAnswers(
        attemptId: _currentAttemptId!,
        answers: answers,
      );
      _currentAttemptId = null;
      _currentExamId = null;
      await _clearAttemptFromPrefs();
    } catch (e) {
      debugPrint(e.toString());
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
