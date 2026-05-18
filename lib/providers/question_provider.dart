import 'package:flutter/material.dart';
import '../models/question_model.dart';
import '../services/api_service.dart';
import '../services/ocr_service.dart';
import 'dart:io';

enum QuestionLoadState { idle, loading, loaded, error }

class QuestionProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  final OcrService _ocrService = OcrService();

  List<Question> _questions = [];
  QuestionLoadState _loadState = QuestionLoadState.idle;
  String? _error;

  // Question creation / OCR state
  List<ScanData> _questionQueue = [];
  bool _isScanning = false;
  bool _isUploading = false;
  bool _isSaving = false;
  String? _creationError;
  bool _creationSuccess = false;

  // Getters
  List<Question> get questions => _questions;
  QuestionLoadState get loadState => _loadState;
  String? get error => _error;
  List<ScanData> get questionQueue => _questionQueue;
  bool get isScanning => _isScanning;
  bool get isUploading => _isUploading;
  bool get isSaving => _isSaving;
  String? get creationError => _creationError;
  bool get creationSuccess => _creationSuccess;

  Future<void> loadQuestions({int? classNo, String? language}) async {
    _loadState = QuestionLoadState.loading;
    _error = null;
    notifyListeners();

    try {
      _questions = await _apiService.getQuestions(classNo: classNo, language: language);
      _loadState = QuestionLoadState.loaded;
    } on ApiException catch (e) {
      _error = e.message;
      _loadState = QuestionLoadState.error;
    } catch (e) {
      _error = 'Failed to load questions. Check your connection.';
      _loadState = QuestionLoadState.error;
    }
    notifyListeners();
  }

  Future<void> scanImage(File imageFile) async {
    _isScanning = true;
    _creationError = null;
    notifyListeners();

    try {
      // 1. Extract raw text via ML Kit
      final rawText = await _ocrService.recognizeMathText(imageFile.path);
      
      if (rawText.trim().isEmpty) {
        _creationError = 'No text detected. Try a clearer image.';
        _isScanning = false;
        notifyListeners();
        return;
      }

      // 2. Send to AI backend for structured parsing
      final results = await _apiService.processOcrText(rawText);
      
      if (results.isEmpty) {
        _creationError = 'Could not extract questions from the image.';
      } else {
        _questionQueue = results;
      }
    } on ApiException catch (e) {
      _creationError = e.message;
    } catch (e) {
      _creationError = 'Scanning failed. Please try again.';
    }

    _isScanning = false;
    notifyListeners();
  }

  void popQuestionFromQueue() {
    if (_questionQueue.isNotEmpty) {
      _questionQueue = _questionQueue.sublist(1);
    }
    notifyListeners();
  }

  Future<bool> saveQuestion(Question question) async {
    _isSaving = true;
    _creationError = null;
    _creationSuccess = false;
    notifyListeners();

    try {
      final saved = await _apiService.createQuestion(question);
      _questions.insert(0, saved);
      _creationSuccess = true;
      _isSaving = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _creationError = e.message;
      _isSaving = false;
      notifyListeners();
      return false;
    } catch (e) {
      _creationError = 'Failed to save question. Check your connection.';
      _isSaving = false;
      notifyListeners();
      return false;
    }
  }

  void resetCreationStatus() {
    _creationError = null;
    _creationSuccess = false;
    notifyListeners();
  }

  void clearQueue() {
    _questionQueue = [];
    notifyListeners();
  }
}
