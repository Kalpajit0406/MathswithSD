import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'network_time_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Violation Types & Severity
// ─────────────────────────────────────────────────────────────────────────────

enum ViolationSeverity { low, medium, critical }

enum ViolationType {
  appBackgrounded,
  splitScreenDetected,
  screenRecordingAttempt,
  examExpired,
  rootDetected,
  emulatorDetected,
  unknown,
}

class ViolationEvent {
  final ViolationType type;
  final ViolationSeverity severity;
  final String message;
  final DateTime timestamp;

  ViolationEvent({
    required this.type,
    required this.severity,
    required this.message,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? NetworkTimeService().istNow;

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'severity': severity.name,
        'message': message,
        'timestamp': timestamp.toIso8601String(),
      };

  @override
  String toString() =>
      '[${severity.name.toUpperCase()}] ${type.name} @ ${timestamp.toIso8601String()}: $message';
}

// ─────────────────────────────────────────────────────────────────────────────
// ExamSecurityService
// ─────────────────────────────────────────────────────────────────────────────

class ExamSecurityService {
  static const _channel = MethodChannel('com.mathswithsd.exam_security');

  // EventChannel for window mode changes (split-screen / floating window)
  static const _windowEventChannel =
      EventChannel('com.mathswithsd.exam_window_events');
  StreamSubscription<dynamic>? _windowEventSub;

  // Violation tracking
  final List<ViolationEvent> _violationLog = [];
  int _backgroundViolationCount = 0;
  static const int _maxBackgroundViolations = 3;

  // Violation stream
  final StreamController<ViolationEvent> _violationController =
      StreamController<ViolationEvent>.broadcast();
  Stream<ViolationEvent> get violationStream => _violationController.stream;

  // Autosave
  Timer? _autosaveTimer;
  String? _currentExamId;
  Map<String, String> Function()? _answersProvider;
  bool _isAutosaving = false;

  // Kiosk state
  bool _kioskActive = false;
  bool get isKioskActive => _kioskActive;

  // Platform integrity states
  bool _emulatorDetected = false;
  bool _rootDetected = false;
  bool get emulatorDetected => _emulatorDetected;
  bool get rootDetected => _rootDetected;

  // Violation counts
  int get backgroundViolationCount => _backgroundViolationCount;
  List<ViolationEvent> get violationLog => List.unmodifiable(_violationLog);
  int get maxViolationsAllowed => _maxBackgroundViolations;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  /// Call when exam starts. Pass the exam ID and a callback that returns current answers.
  Future<void> startSecureExam({
    required String examId,
    required Map<String, String> Function() answersProvider,
  }) async {
    _currentExamId = examId;
    _answersProvider = answersProvider;
    _backgroundViolationCount = 0;
    _violationLog.clear();
    _emulatorDetected = false;
    _rootDetected = false;

    // Check device integrity
    final rooted = await isDeviceRooted();
    final emulator = await isDeviceEmulator();
    _rootDetected = rooted;
    _emulatorDetected = emulator;

    await _enterKioskMode();
    await _startForegroundMonitor();
    _startAutosave();
    _subscribeToWindowEvents();

    if (rooted) {
      _addViolation(ViolationEvent(
        type: ViolationType.rootDetected,
        severity: ViolationSeverity.critical,
        message: 'Security Violation: Rooted device detected.',
      ));
    }
    if (emulator) {
      _addViolation(ViolationEvent(
        type: ViolationType.emulatorDetected,
        severity: ViolationSeverity.critical,
        message: 'Security Violation: Emulator detected.',
      ));
    }

    debugPrint('[ExamSecurity] Secure exam session started for $examId');
  }

  Future<bool> isDeviceRooted() async {
    try {
      final bool rooted = await _channel.invokeMethod('isRooted');
      return rooted;
    } catch (e) {
      debugPrint('[ExamSecurity] Error checking root: $e');
      return false;
    }
  }

  Future<bool> isDeviceEmulator() async {
    try {
      if (Platform.isAndroid) {
        final Map<dynamic, dynamic>? result = 
            await _channel.invokeMethod<Map<dynamic, dynamic>>('evaluateEmulatorRisk');
        if (result != null) {
          final double risk = (result['cumulativeRisk'] ?? 0.0) as double;
          debugPrint('[ExamSecurity] Emulator risk evaluation: ${risk * 100}%');
          return risk >= 0.70;
        }
      }
      final bool emulator = await _channel.invokeMethod('isEmulator');
      return emulator;
    } catch (e) {
      debugPrint('[ExamSecurity] Error checking emulator: $e');
      return false;
    }
  }

  /// Call when exam ends (submitted, auto-submitted, or error).
  Future<void> endSecureExam() async {
    _unsubscribeWindowEvents();
    _stopAutosave();
    await _exitKioskMode();
    await _stopForegroundMonitor();
    _currentExamId = null;
    _answersProvider = null;
    debugPrint('[ExamSecurity] Secure exam session ended.');
  }

  void dispose() {
    _unsubscribeWindowEvents();
    _stopAutosave();
    _violationController.close();
  }

  // ── App Lifecycle Handling ────────────────────────────────────────────────

  /// Call this from WidgetsBindingObserver.didChangeAppLifecycleState
  void onAppLifecycleChanged(AppLifecycleState state) {
    if (!_kioskActive) return;

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _backgroundViolationCount++;

      ViolationSeverity severity;
      String message;

      if (_backgroundViolationCount >= _maxBackgroundViolations) {
        severity = ViolationSeverity.critical;
        message =
            'App left foreground $_backgroundViolationCount times. Exam will be auto-submitted.';
      } else if (_backgroundViolationCount == _maxBackgroundViolations - 1) {
        severity = ViolationSeverity.medium;
        message =
            'Warning: This is violation #$_backgroundViolationCount. '
            'One more will auto-submit your exam.';
      } else {
        severity = ViolationSeverity.medium;
        message =
            'You left the exam app (violation #$_backgroundViolationCount of '
            '$_maxBackgroundViolations). Please stay in the exam.';
      }

      _addViolation(ViolationEvent(
        type: ViolationType.appBackgrounded,
        severity: severity,
        message: message,
      ));
    }
  }

  // ── Window Event Subscription (split-screen / floating window) ───────────

  void _subscribeToWindowEvents() {
    _windowEventSub?.cancel();
    _windowEventSub = _windowEventChannel
        .receiveBroadcastStream()
        .listen(_onWindowEvent, onError: (e) {
      debugPrint('[ExamSecurity] Window event error: $e');
    });
    debugPrint('[ExamSecurity] Subscribed to window mode events.');
  }

  void _unsubscribeWindowEvents() {
    _windowEventSub?.cancel();
    _windowEventSub = null;
  }

  void _onWindowEvent(dynamic event) {
    if (!_kioskActive) return;
    if (event == 'multiWindow') {
      debugPrint('[ExamSecurity] Split-screen / floating window detected — critical violation.');
      _addViolation(ViolationEvent(
        type: ViolationType.splitScreenDetected,
        severity: ViolationSeverity.critical,
        message:
            'Split-screen or floating window detected. '
            'The exam has been auto-submitted to protect integrity.',
      ));
    }
  }

  // ── Manual Violation Reporting ────────────────────────────────────────────

  /// Kept for external callers; now also wired automatically via EventChannel.
  void reportSplitScreen() => _onWindowEvent('multiWindow');

  // ── Kiosk Mode ────────────────────────────────────────────────────────────

  Future<void> _enterKioskMode() async {
    try {
      await _channel.invokeMethod('enableKioskMode');
      _kioskActive = true;
      debugPrint('[ExamSecurity] Kiosk mode enabled.');
    } catch (e) {
      // Not fatal — security is still partially active (FLAG_SECURE is set)
      debugPrint('[ExamSecurity] Kiosk mode unavailable: $e');
      _kioskActive = true; // Still track violations
    }
  }

  Future<void> _exitKioskMode() async {
    // Kiosk mode is managed globally for the Student App and should not be disabled
    // at the end of the exam transition.
    _kioskActive = false;
    debugPrint('[ExamSecurity] Global Kiosk mode remains active after exam.');
  }

  // ── Foreground Service ────────────────────────────────────────────────────

  Future<void> _startForegroundMonitor() async {
    try {
      await _channel.invokeMethod('startForegroundMonitor');
    } catch (e) {
      debugPrint('[ExamSecurity] Could not start foreground monitor: $e');
    }
  }

  Future<void> _stopForegroundMonitor() async {
    try {
      await _channel.invokeMethod('stopForegroundMonitor');
    } catch (e) {
      debugPrint('[ExamSecurity] Could not stop foreground monitor: $e');
    }
  }

  // ── Autosave Engine ───────────────────────────────────────────────────────

  void _startAutosave() {
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (_isAutosaving) return;
      _isAutosaving = true;
      try {
        await _saveAnswers();
      } finally {
        _isAutosaving = false;
      }
    });
    debugPrint('[ExamSecurity] Autosave started (every 30s).');
  }

  void _stopAutosave() {
    _autosaveTimer?.cancel();
    _autosaveTimer = null;
  }

  Future<void> _saveAnswers() async {
    if (_currentExamId == null || _answersProvider == null) return;
    try {
      final answers = _answersProvider!();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'secure_exam_autosave_${_currentExamId!}',
        answers.entries.map((e) => '${e.key}==${e.value}').join('||'),
      );
      await prefs.setInt(
        'secure_exam_autosave_ts_${_currentExamId!}',
        DateTime.now().millisecondsSinceEpoch,
      );
      debugPrint('[ExamSecurity] Autosaved ${answers.length} answers.');
    } catch (e) {
      debugPrint('[ExamSecurity] Autosave failed: $e');
    }
  }

  /// Call on exam init to restore autosaved answers after a crash
  Future<Map<String, String>?> recoverAutosavedAnswers(String examId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('secure_exam_autosave_$examId');
      final ts = prefs.getInt('secure_exam_autosave_ts_$examId');
      if (raw == null || raw.isEmpty || ts == null) return null;

      // Only recover if saved within the last 3 hours
      final age = DateTime.now().millisecondsSinceEpoch - ts;
      if (age > 3 * 60 * 60 * 1000) {
        await clearAutosavedAnswers(examId);
        return null;
      }

      final map = <String, String>{};
      for (final pair in raw.split('||')) {
        final parts = pair.split('==');
        if (parts.length == 2) map[parts[0]] = parts[1];
      }
      debugPrint('[ExamSecurity] Recovered ${map.length} autosaved answers for $examId.');
      return map.isNotEmpty ? map : null;
    } catch (e) {
      debugPrint('[ExamSecurity] Answer recovery failed: $e');
      return null;
    }
  }

  Future<void> clearAutosavedAnswers(String examId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('secure_exam_autosave_$examId');
      await prefs.remove('secure_exam_autosave_ts_$examId');
    } catch (e) {
      debugPrint('[ExamSecurity] Failed to clear autosave: $e');
    }
  }

  // ── Internal ──────────────────────────────────────────────────────────────

  void _addViolation(ViolationEvent event) {
    _violationLog.add(event);
    debugPrint('[ExamSecurity] Violation: $event');
    if (!_violationController.isClosed) {
      _violationController.add(event);
    }
  }
}
