import 'dart:async';
import 'package:flutter/material.dart';
import 'connectivity_manager.dart';
import 'offline_exam_service.dart';
import 'api_service.dart';

enum SyncStatus { idle, syncing, success, error }

/// Manages synchronization of offline exam data with backend
class SyncManager {
  static final SyncManager _instance = SyncManager._internal();
  
  final ConnectivityManager _connectivityManager = ConnectivityManager();
  final OfflineExamService _offlineService = OfflineExamService();
  final ApiService _apiService = ApiService();
  
  StreamSubscription? _connectivitySubscription;
  
  SyncStatus _syncStatus = SyncStatus.idle;
  String? _syncError;
  int _syncedCount = 0;
  
  final _syncStatusController = StreamController<SyncStatus>.broadcast();
  
  bool _isInitialized = false;
  bool _isSyncing = false;
  bool _isDisposed = false;

  SyncManager._internal();

  factory SyncManager() {
    return _instance;
  }

  /// Initialize sync manager and start listening to connectivity changes
  Future<void> initialize() async {
    if (_isDisposed) return;
    if (_isInitialized) return;
    
    try {
      await _connectivityManager.initialize();
      
      // Listen for connectivity changes
      _connectivitySubscription = _connectivityManager.statusChanges.listen((_) {
        if (_isDisposed) return;
        if (_connectivityManager.isOnline && !_isSyncing) {
          debugPrint('[SyncManager] Device came online, triggering sync');
          syncOfflineExams();
        }
      });
      
      _isInitialized = true;
    } catch (e) {
      debugPrint('[SyncManager] Initialization error: $e');
      rethrow;
    }
  }

  SyncStatus get syncStatus => _syncStatus;
  String? get syncError => _syncError;
  int get syncedCount => _syncedCount;
  Stream<SyncStatus> get statusStream => _syncStatusController.stream;
  bool get isOnline => _connectivityManager.isOnline;

  /// Sync all unsynced offline exams
  Future<void> syncOfflineExams() async {
    if (_isDisposed) return;
    if (_isSyncing) {
      debugPrint('[SyncManager] Sync already in progress');
      return;
    }

    if (!_connectivityManager.isOnline) {
      debugPrint('[SyncManager] Device offline, cannot sync');
      return;
    }

    _isSyncing = true;
    _syncStatus = SyncStatus.syncing;
    _syncError = null;
    _syncedCount = 0;
    if (!_isDisposed) _syncStatusController.add(SyncStatus.syncing);

    try {
      // Get all unsynced exams
      final unsyncedExams = await _offlineService.getUnsyncedExams();
      
      if (unsyncedExams.isEmpty) {
        debugPrint('[SyncManager] No exams to sync');
        _syncStatus = SyncStatus.idle;
        if (!_isDisposed) _syncStatusController.add(SyncStatus.idle);
        _isSyncing = false;
        return;
      }

      debugPrint('[SyncManager] Starting sync of ${unsyncedExams.length} exams');

      // Sync each exam
      for (final exam in unsyncedExams) {
        try {
          // Get responses for this exam
          final responses = await _offlineService.getOfflineResponses(exam.examId);
          
          // Prepare answers in format expected by backend
          final answers = responses.map((r) => {
            'questionId': r.questionId,
            'selectedAnswer': r.selectedAnswer,
            'timeSpent': r.timeSpent,
          }).toList();

          // Submit to backend
          debugPrint('[SyncManager] Syncing exam: ${exam.examId} with ${responses.length} responses');
          await _apiService.syncOfflineAttemptWithRetry(
            examId: exam.examId,
            responses: answers,
          );
          
          // Mark as synced
          await _offlineService.markExamAsSynced(exam.examId);
          _syncedCount++;
          
        } catch (e) {
          debugPrint('[SyncManager] Error syncing exam ${exam.examId}: $e');
          _syncError = 'Error syncing ${exam.examId}';
          // Continue with next exam
        }
      }

      _syncStatus = SyncStatus.success;
      if (!_isDisposed) _syncStatusController.add(SyncStatus.success);
      debugPrint('[SyncManager] Sync completed: $_syncedCount exams synced');
      
    } catch (e) {
      debugPrint('[SyncManager] Sync error: $e');
      _syncStatus = SyncStatus.error;
      _syncError = e.toString();
      if (!_isDisposed) _syncStatusController.add(SyncStatus.error);
    } finally {
      _isSyncing = false;
      // Reset to idle after delay
      await Future.delayed(const Duration(seconds: 2));
      if (_isDisposed) return;
      _syncStatus = SyncStatus.idle;
      _syncStatusController.add(SyncStatus.idle);
    }
  }

  /// Check if specific exam is synced
  Future<bool> isExamSynced(String examId) async {
    try {
      final exam = await _offlineService.getOfflineExam(examId);
      return exam?.status == 'synced';
    } catch (e) {
      debugPrint('[SyncManager] Error checking sync status: $e');
      return false;
    }
  }

  /// Get pending sync count
  Future<int> getPendingSyncCount() async {
    try {
      final exams = await _offlineService.getUnsyncedExams();
      return exams.length;
    } catch (e) {
      debugPrint('[SyncManager] Error getting pending count: $e');
      return 0;
    }
  }

  /// Clear all offline data (use with caution)
  Future<void> clearAllOfflineData() async {
    try {
      await _offlineService.clearAllOfflineData();
      debugPrint('[SyncManager] All offline data cleared');
    } catch (e) {
      debugPrint('[SyncManager] Error clearing offline data: $e');
      rethrow;
    }
  }

  /// Dispose resources
  void dispose() {
    _isDisposed = true;
    _connectivitySubscription?.cancel();
    _syncStatusController.close();
    _isInitialized = false;
  }
}
