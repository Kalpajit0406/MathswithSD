import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'connectivity_manager.dart';
import 'storage_service.dart';
import 'api_service.dart';

class ExamWebSocketService {
  static final ExamWebSocketService _instance = ExamWebSocketService._internal();
  factory ExamWebSocketService() => _instance;

  ExamWebSocketService._internal() {
    // Listen to connectivity changes to instantly trigger reconnection when online
    _connectivitySubscription = ConnectivityManager().statusChanges.listen((status) {
      if (status != ConnectivityResult.none && !_isConnected && _currentAttemptId != null) {
        if (kDebugMode) debugPrint('[WebSocket] Device back online. Triggering reconnection.');
        _reconnectTimer?.cancel();
        _reconnectTimer = null;
        _establishConnection();
      }
    });
  }

  WebSocket? _socket;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  StreamSubscription? _connectivitySubscription;
  bool _isConnected = false;
  String? _currentAttemptId;
  String? _currentExamId;

  // Stashed answers for offline state reconciliation
  final Map<String, String> _pendingAnswers = {};

  // Stream controller to notify UI of status changes
  final _statusController = StreamController<bool>.broadcast();
  Stream<bool> get statusStream => _statusController.stream;
  bool get isConnected => _isConnected;

  // Question stream controller to receive dynamic question content
  final _questionController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get questionStream => _questionController.stream;

  // Terminate controller for security violations
  final _terminateController = StreamController<String>.broadcast();
  Stream<String> get terminateStream => _terminateController.stream;

  // Callback to sync remaining time on the client with the server-side authority
  Function(int)? onTimeUpdated;

  Future<void> connect(String attemptId, String examId) async {
    if (_isConnected) return;
    _currentAttemptId = attemptId;
    _currentExamId = examId;

    await _establishConnection();
  }

  Future<void> _establishConnection() async {
    if (_currentAttemptId == null) return;
    
    try {
      final token = await AuthStorageService.getToken();
      if (token == null) throw Exception('No authentication token found');

      final baseRestUrl = ApiService().baseUrl;
      // Convert http/https to ws/wss
      final wsBase = baseRestUrl.replaceFirst('http://', 'ws://').replaceFirst('https://', 'wss://');
      final wsUrl = '$wsBase/api/v1/exam-ws?token=$token&attemptId=$_currentAttemptId';

      if (kDebugMode) debugPrint('[WebSocket] Connecting to WebSocket endpoint.');
      _socket = await WebSocket.connect(wsUrl).timeout(const Duration(seconds: 8));
      _isConnected = true;
      _statusController.add(true);
      if (kDebugMode) debugPrint('[WebSocket] Connected successfully.');

      // Clear reconnect timers
      _reconnectTimer?.cancel();
      _reconnectTimer = null;

      // Reconcile stashed answers
      _reconcileAnswers();

      // Listen to incoming messages
      _socket!.listen(
        _onMessageReceived,
        onDone: _onConnectionClosed,
        onError: (err) {
          if (kDebugMode) debugPrint('[WebSocket] Socket error: $err');
          _onConnectionClosed();
        },
        cancelOnError: true,
      );

      // Start periodic heartbeats (every 5 seconds)
      _startHeartbeats();
    } catch (e) {
      if (kDebugMode) debugPrint('[WebSocket] Connection failed: $e');
      _onConnectionClosed();
    }
  }

  void _startHeartbeats() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!_isConnected || _socket == null) return;
      sendEvent('heartbeat', {});
    });
  }

  void _onMessageReceived(dynamic message) {
    try {
      final payload = jsonDecode(message.toString());
      final String event = payload['event'] ?? '';
      final Map<String, dynamic> data = payload['data'] ?? {};

      switch (event) {
        case 'init_ack':
          final remaining = data['remainingSeconds'] as int?;
          if (remaining != null && onTimeUpdated != null) {
            onTimeUpdated!(remaining);
          }
          break;

        case 'heartbeat_ack':
          final remaining = data['remainingSeconds'] as int?;
          if (remaining != null && onTimeUpdated != null) {
            onTimeUpdated!(remaining);
          }
          break;

        case 'question_data':
          _questionController.add(data);
          break;

        case 'terminate':
          final reason = payload['reason'] ?? 'Security violation';
          _terminateController.add(reason);
          break;

        case 'error':
          if (kDebugMode) debugPrint('[WebSocket] Server error: ${payload['message']}');
          break;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[WebSocket] Error parsing frame: $e');
    }
  }

  void _onConnectionClosed() {
    if (!_isConnected) return;
    _isConnected = false;
    _statusController.add(false);
    _heartbeatTimer?.cancel();
    _socket = null;
    if (kDebugMode) debugPrint('[WebSocket] Connection lost.');

    // Trigger exponential backoff reconnect
    if (_currentAttemptId != null) {
      _triggerReconnectCountdown();
    }
  }

  void _triggerReconnectCountdown() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    
    int attempt = 0;
    const maxAttempts = 6;

    void scheduleReconnect() {
      if (_isConnected || _currentAttemptId == null) return;

      attempt++;
      if (attempt > maxAttempts) {
        if (kDebugMode) debugPrint('[WebSocket] Reconnection timeout. Auto-submitting.');
        _terminateController.add('🔌 Network connection lost. Exam auto-submitted.');
        return;
      }

      // Exponential backoff: 2s, 4s, 8s, 16s...
      final delaySeconds = (1 << attempt);
      if (kDebugMode) debugPrint('[WebSocket] Scheduled reconnect in ${delaySeconds}s (attempt $attempt)...');

      _reconnectTimer = Timer(Duration(seconds: delaySeconds), () async {
        if (ConnectivityManager().isOnline) {
          if (kDebugMode) debugPrint('[WebSocket] Retrying connection now...');
          await _establishConnection();
        }
        if (!_isConnected) {
          scheduleReconnect();
        }
      });
    }

    scheduleReconnect();
  }

  void sendEvent(String event, Map<String, dynamic> data) {
    if (!_isConnected || _socket == null) {
      if (kDebugMode) debugPrint('[WebSocket] Cannot send event $event: socket offline.');
      return;
    }
    try {
      _socket!.add(jsonEncode({
        'event': event,
        'data': data
      }));
    } catch (e) {
      if (kDebugMode) debugPrint('[WebSocket] Failed to send event $event: $e');
    }
  }

  // API to submit selected answer (continuous syncing)
  void syncAnswer(String questionId, String answer) {
    if (!_isConnected || _socket == null) {
      _pendingAnswers[questionId] = answer;
      return;
    }
    sendEvent('submit_answer', {
      'questionId': questionId,
      'answer': answer
    });
  }

  void _reconcileAnswers() {
    if (_pendingAnswers.isNotEmpty) {
      if (kDebugMode) debugPrint('[WebSocket] Reconnected. Reconciling pending answers.');
      _pendingAnswers.forEach((qId, ans) {
        sendEvent('submit_answer', {
          'questionId': qId,
          'answer': ans
        });
      });
      _pendingAnswers.clear();
    }
  }

  // API to fetch question dynamically
  void requestQuestion(String questionId) {
    sendEvent('get_question', {
      'questionId': questionId
    });
  }

  // API to stream telemetry
  void sendTelemetry(Map<String, dynamic> violation) {
    sendEvent('telemetry', {
      'violation': violation
    });
  }

  void disconnect() {
    _currentAttemptId = null;
    _currentExamId = null;
    _isConnected = false;
    _statusController.add(false);
    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();
    try {
      _socket?.close();
    } catch (_) {}
    _socket = null;
  }
}
