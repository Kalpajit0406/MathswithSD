import 'dart:async';
import 'package:flutter/material.dart';
import '../models/exam_model.dart';
import '../services/api_service.dart';

class ExamProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  
  List<Exam> _exams = [];
  bool _isLoading = false;
  String? _currentAttemptId;
  
  // Attempt State
  int _currentQuestionIndex = 0;
  Map<String, String> _userAnswers = {}; // questionId -> answer
  int _remainingSeconds = 0;
  Timer? _timer;

  List<Exam> get exams => _exams;
  bool get isLoading => _isLoading;
  int get currentQuestionIndex => _currentQuestionIndex;
  Map<String, String> get userAnswers => _userAnswers;
  int get remainingSeconds => _remainingSeconds;

  Future<void> fetchExams(String token) async {
    _isLoading = true;
    notifyListeners();
    try {
      _exams = await _apiService.fetchExams(token);
    } catch (e) {
      debugPrint(e.toString());
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> startExam(String examId, String token) async {
    _currentQuestionIndex = 0;
    _userAnswers = {};
    // Find the exam to get its duration
    final exam = _exams.firstWhere((e) => e.id == examId);
    _remainingSeconds = exam.duration * 60;
    
    try {
      _currentAttemptId = await _apiService.startAttempt(examId, token);
      _startTimer();
      notifyListeners();
    } catch (e) {
      debugPrint(e.toString());
      rethrow;
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        _remainingSeconds--;
        notifyListeners();
      } else {
        _timer?.cancel();
      }
    });
  }

  void setAnswer(String questionId, String answer) {
    _userAnswers[questionId] = answer;
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

  Future<void> submitExam(List<Map<String, dynamic>> answers, String token) async {
    if (_currentAttemptId == null) return;
    
    _timer?.cancel();
    _isLoading = true;
    notifyListeners();

    try {
      await _apiService.submitAnswers(
        attemptId: _currentAttemptId!,
        answers: answers,
        token: token,
      );
      _currentAttemptId = null;
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
