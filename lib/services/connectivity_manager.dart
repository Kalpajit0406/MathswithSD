import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

/// Manages connectivity state and provides connectivity change notifications
class ConnectivityManager {
  static final ConnectivityManager _instance = ConnectivityManager._internal();
  
  final Connectivity _connectivity = Connectivity();
  late StreamSubscription<List<ConnectivityResult>> _subscription;
  
  ConnectivityResult _currentStatus = ConnectivityResult.none;
  final _statusChangeController = StreamController<ConnectivityResult>.broadcast();
  
  bool _isInitialized = false;

  ConnectivityManager._internal();

  factory ConnectivityManager() {
    return _instance;
  }

  /// Initialize connectivity monitoring
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Get initial status
      final results = await _connectivity.checkConnectivity();
      _currentStatus = results.isNotEmpty && results.first != ConnectivityResult.none
          ? results.first
          : ConnectivityResult.none;
      
      // Listen to connectivity changes
      _subscription = _connectivity.onConnectivityChanged.listen((results) {
        final newStatus = results.isNotEmpty ? results.first : ConnectivityResult.none;
        if (newStatus != _currentStatus) {
          _currentStatus = newStatus;
          _statusChangeController.add(newStatus);
          debugPrint('[Connectivity] Status changed to: $_currentStatus');
        }
      });
      
      _isInitialized = true;
    } catch (e) {
      debugPrint('[Connectivity] Initialization error: $e');
      rethrow;
    }
  }

  /// Get current connectivity status
  ConnectivityResult get currentStatus => _currentStatus;

  /// Check if device is online
  bool get isOnline => _currentStatus != ConnectivityResult.none;

  /// Stream of connectivity status changes
  Stream<ConnectivityResult> get statusChanges => _statusChangeController.stream;

  /// Dispose resources
  void dispose() {
    _subscription.cancel();
    _statusChangeController.close();
    _isInitialized = false;
  }
}
