import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/exam_provider.dart';
import '../../models/exam_model.dart';
import '../shared/latex_widget.dart';
import '../../widgets/glass_card.dart';
import 'result_screen.dart';
import '../../services/connectivity_manager.dart';
import '../../services/exam_security_service.dart';
import '../../services/network_time_service.dart';
import '../../services/websocket_service.dart';
import 'package:intl/intl.dart';
import 'submission_success_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Colour constants (matches app theme)
// ─────────────────────────────────────────────────────────────────────────────
const _kPrimary = Color(0xFF0051D5);
const _kSelectedBg = Color(0xFFE6EFFF);
const _kAmber = Color(0xFFFFB300);

// ─────────────────────────────────────────────────────────────────────────────
// ExamAttemptScreen
// ─────────────────────────────────────────────────────────────────────────────

class ExamAttemptScreen extends StatefulWidget {
  final Exam exam;

  const ExamAttemptScreen({super.key, required this.exam});

  @override
  State<ExamAttemptScreen> createState() => _ExamAttemptScreenState();
}

class _ExamAttemptScreenState extends State<ExamAttemptScreen>
    with WidgetsBindingObserver {
  // ── State ────────────────────────────────────────────────────────────────
  bool _isSubmitted = false;
  bool _isInitializing = true;
  String? _initError;

  // Security
  final ExamSecurityService _security = ExamSecurityService();
  StreamSubscription<ViolationEvent>? _violationSub;
  bool _showViolationBanner = false;
  String _violationBannerMessage = '';
  Timer? _bannerTimer;

  // Reconnection and online tracking (Part 1)
  bool _showReconnectCountdown = false;
  bool _freezeExamInteractions = false;
  int _reconnectCountdownSeconds = 15;
  Timer? _reconnectTimerUI;

  void _startReconnectTimer() {
    _reconnectTimerUI?.cancel();
    _reconnectCountdownSeconds = 15;
    _reconnectTimerUI = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_reconnectCountdownSeconds > 0) {
          _reconnectCountdownSeconds--;
        } else {
          timer.cancel();
          _autoSubmitExam(
            '🔌 Disconnected from server. Reconnect timeout exceeded.',
          );
        }
      });
    });
  }

  void _cancelReconnectTimer() {
    _reconnectTimerUI?.cancel();
    _reconnectTimerUI = null;
    setState(() {
      _showReconnectCountdown = false;
      _freezeExamInteractions = false;
    });
  }

  // ── Init ─────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeExam();
  }

  Future<void> _initializeExam() async {
    final provider = Provider.of<ExamProvider>(context, listen: false);
    try {
      final isOffline = !ConnectivityManager().isOnline;
      if (isOffline) {
        throw Exception(
          'Offline examinations are disabled. Active server session is required.',
        );
      }

      // ── Try to recover autosaved answers (crash recovery) ──
      final recovered = await _security.recoverAutosavedAnswers(widget.exam.id);

      final cached = await provider.checkForResumableExam();
      if (cached != null && cached['examId'] == widget.exam.id) {
        await provider.resumeExam(cached);
      } else {
        await provider.startExam(widget.exam.id);
      }

      // Setup WebSocket connection event listener hook (Part 1)
      final wsService = ExamWebSocketService();
      wsService.statusStream.listen((connected) {
        if (!mounted) return;
        if (!connected) {
          setState(() {
            _showReconnectCountdown = true;
            _freezeExamInteractions = true;
          });
          _startReconnectTimer();
        } else {
          _cancelReconnectTimer();
        }
      });

      wsService.terminateStream.listen((reason) {
        if (!mounted) return;
        _autoSubmitExam(reason);
      });

      // Restore autosaved answers if available
      if (recovered != null && recovered.isNotEmpty) {
        for (final entry in recovered.entries) {
          provider.setAnswer(entry.key, entry.value);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                '✅ Previous session recovered — your answers have been restored.',
              ),
              backgroundColor: Color(0xFF2E7D32),
              duration: Duration(seconds: 4),
            ),
          );
        }
      }

      // Listen to violation events and stream them to WS backend (Part 9)
      _violationSub = _security.violationStream.listen((event) {
        _onViolation(event);
        try {
          ExamWebSocketService().sendTelemetry(event.toJson());
        } catch (e) {
          debugPrint('Failed to send telemetry over WS: $e');
        }
      });

      // ── Activate security AFTER exam is successfully initialized ──
      await _security.startSecureExam(
        examId: widget.exam.id,
        answersProvider: () => Map<String, String>.from(provider.userAnswers),
      );

      if (mounted) {
        setState(() => _isInitializing = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _initError = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  // ── Dispose ──────────────────────────────────────────────────────────────

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _violationSub?.cancel();
    _bannerTimer?.cancel();
    _security.dispose();
    super.dispose();
  }

  // ── Lifecycle Observer ───────────────────────────────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isSubmitted || _isInitializing || _initError != null) return;
    _security.onAppLifecycleChanged(state);
  }

  // ── Violation Handler ────────────────────────────────────────────────────

  void _onViolation(ViolationEvent event) {
    if (_isSubmitted) return;

    switch (event.severity) {
      case ViolationSeverity.low:
        _showTemporaryBanner(event.message, color: _kAmber);
        break;

      case ViolationSeverity.medium:
        _showViolationDialog(event);
        break;

      case ViolationSeverity.critical:
        _autoSubmitExam(event.message);
        break;
    }
  }

  void _showTemporaryBanner(String message, {Color color = _kAmber}) {
    setState(() {
      _showViolationBanner = true;
      _violationBannerMessage = message;
    });
    _bannerTimer?.cancel();
    _bannerTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _showViolationBanner = false);
    });
  }

  void _showViolationDialog(ViolationEvent event) {
    if (!mounted) return;

    final count = _security.backgroundViolationCount;
    final max = _security.maxViolationsAllowed;
    final remaining = max - count;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.security, color: Colors.deepOrange),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                count >= max - 1 ? '⚠️ Final Warning' : '🔒 Security Warning',
                style: const TextStyle(fontSize: 18),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(event.message, style: const TextStyle(fontSize: 15)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: remaining <= 1
                    ? Colors.red.shade50
                    : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: remaining <= 1 ? Colors.red : Colors.orange,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    remaining <= 1
                        ? Icons.error_outline
                        : Icons.warning_amber_rounded,
                    color: remaining <= 1 ? Colors.red : Colors.orange,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      remaining <= 1
                          ? 'Next violation will AUTO-SUBMIT your exam!'
                          : '$remaining violation(s) remaining before auto-submit.',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: remaining <= 1
                            ? Colors.red
                            : Colors.orange.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: remaining <= 1 ? Colors.red : _kPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: const Icon(Icons.check, color: Colors.white, size: 16),
            label: const Text(
              'I Understand',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // ── Submit ───────────────────────────────────────────────────────────────

  Future<void> _autoSubmitExam(String reason) async {
    if (!mounted || _isSubmitted) return;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🔴 $reason'),
          backgroundColor: Colors.red.shade800,
          duration: const Duration(seconds: 5),
        ),
      );
    }
    await Future.delayed(const Duration(milliseconds: 800));
    await _submit(autoSubmitReason: reason);
  }

  Future<void> _submit({String? autoSubmitReason}) async {
    final examProvider = Provider.of<ExamProvider>(context, listen: false);
    if (_isSubmitted || examProvider.isLoading) return;
    setState(() => _isSubmitted = true);

    // Extract security metadata prior to ending secure exam session
    final List<Map<String, dynamic>> violationsJson = _security.violationLog
        .map((v) => v.toJson())
        .toList();
    final bool isAutoSubmitted = autoSubmitReason != null;
    final bool emulator = _security.emulatorDetected;
    final bool rooted = _security.rootDetected;

    // End secure session first
    await _security.endSecureExam();

    // Build answer array
    List<Map<String, dynamic>> finalAnswers = [];
    int score = 0;
    for (var q in widget.exam.questions) {
      String? userAns = examProvider.userAnswers[q.id];
      if (userAns != null && userAns == q.correctAnswer) score++;
      finalAnswers.add({'questionId': q.id, 'answer': userAns});
    }

    final attemptId = examProvider.currentAttemptId;
    final isOffline =
        !ConnectivityManager().isOnline ||
        (examProvider.currentAttemptId?.startsWith('offline_') ?? false);

    try {
      await examProvider.submitExam(
        finalAnswers,
        isOffline: isOffline,
        violations: violationsJson,
        isAutoSubmitted: isAutoSubmitted,
        autoSubmitReason: autoSubmitReason,
        emulatorDetected: emulator,
        rootDetected: rooted,
      );
      // Clear autosave after successful submit
      await _security.clearAutosavedAnswers(widget.exam.id);

      if (mounted) {
        final examStart = widget.exam.getExamDateTime();
        final remainingSeconds = examProvider.remainingSeconds;
        final bool examEnded = remainingSeconds <= 0;
        
        String endTimeStr = '';
        if (examStart != null) {
          final examEnd = examStart.add(
            Duration(minutes: widget.exam.duration),
          );
          endTimeStr =
              '${widget.exam.date} @ ${DateFormat('hh:mm a').format(examEnd)}';
        } else {
          final now = DateTime.now();
          final examEnd = now.add(Duration(seconds: remainingSeconds));
          endTimeStr = DateFormat('hh:mm a').format(examEnd);
        }

        if (examEnded) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => ResultScreen(
                score: score,
                totalQuestions: widget.exam.questions.length,
                timeTaken:
                    (widget.exam.duration * 60) - examProvider.remainingSeconds,
                questions: widget.exam.questions,
                userAnswers: examProvider.userAnswers,
                isOffline: isOffline,
              ),
            ),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => SubmissionSuccessScreen(
                exam: widget.exam,
                attemptId: attemptId ?? '',
                endTimeStr: endTimeStr,
                initialRemainingSeconds: remainingSeconds,
              ),
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isSubmitted = false);
      // Re-engage security since submit failed
      await _security.startSecureExam(
        examId: widget.exam.id,
        answersProvider: () =>
            Map<String, String>.from(examProvider.userAnswers),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // ── Initializing ────────────────────────────────────────────────────────
    if (_isInitializing) {
      return Scaffold(
        backgroundColor: const Color(0xFF0A0F1D),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 64,
                height: 64,
                child: CircularProgressIndicator(
                  color: Color(0xFF8B5CF6),
                  strokeWidth: 3,
                ),
              ),
              const SizedBox(height: 28),
              const Icon(
                Icons.shield_outlined,
                color: Color(0xFF8B5CF6),
                size: 36,
              ),
              const SizedBox(height: 16),
              const Text(
                'Securing Examination Environment',
                style: TextStyle(
                  color: Color(0xFFEDE9FE),
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Setting up secure mode — please wait',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ── Init Error ───────────────────────────────────────────────────────────
    if (_initError != null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0A0F1D),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text(
            'Initialization Error',
            style: TextStyle(color: Colors.white),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.red.withValues(alpha: 0.15),
                  ),
                  child: const Icon(
                    Icons.error_outline_rounded,
                    size: 48,
                    color: Colors.redAccent,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Failed to Initialize Exam',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _initError!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kPrimary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  label: const Text(
                    'Go Back',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // ── Submitting ───────────────────────────────────────────────────────────
    final examProvider = Provider.of<ExamProvider>(context);
    if (examProvider.isLoading || _isSubmitted) {
      return Scaffold(
        backgroundColor: const Color(0xFF0A0F1D),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                color: Color(0xFF8B5CF6),
                strokeWidth: 3,
              ),
              const SizedBox(height: 24),
              const Text(
                'Submitting your answers securely...',
                style: TextStyle(
                  color: Color(0xFFEDE9FE),
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${_security.violationLog.length} violation(s) logged',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ── Time Expired ─────────────────────────────────────────────────────────
    if (examProvider.remainingSeconds == 0 && !_isSubmitted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _autoSubmitExam('⏰ Time is up! Exam auto-submitted.');
      });
    }

    final totalQ = widget.exam.questions.length;
    final currentQIndex = examProvider.currentQuestionIndex;
    final currentQ = widget.exam.questions[currentQIndex];
    final answeredCount = examProvider.userAnswers.length;

    // ── Main Exam UI ──────────────────────────────────────────────────────────
    return PopScope(
      canPop: false,
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            // ── AppBar ──────────────────────────────────────────────────────────
            appBar: AppBar(
              automaticallyImplyLeading: false,
              backgroundColor: const Color(0xFF0F172A),
              elevation: 0,
              title: Row(
                children: [
                  // Shield icon (security active)
                  Tooltip(
                    message: 'Secure Mode Active',
                    child: Icon(
                      Icons.shield,
                      color: Colors.greenAccent.shade400,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Q ${currentQIndex + 1}/$totalQ',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              actions: [
                // Timer
                Container(
                  margin: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 4,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: examProvider.remainingSeconds < 60
                        ? Colors.red.shade700
                        : Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        color: examProvider.remainingSeconds < 60
                            ? Colors.white
                            : Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatTime(examProvider.remainingSeconds),
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
                // Submit button
                TextButton(
                  onPressed: () => _showSubmitConfirmDialog(),
                  child: const Text(
                    'FINISH',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            body: Column(
              children: [
                // ── Violation Banner ──────────────────────────────────────────
                AnimatedSlide(
                  offset: _showViolationBanner
                      ? Offset.zero
                      : const Offset(0, -1),
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                  child: AnimatedOpacity(
                    opacity: _showViolationBanner ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 250),
                    child: Container(
                      width: double.infinity,
                      color: Colors.deepOrange.shade700,
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 16,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.warning_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _violationBannerMessage,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // ── Offline Banner ────────────────────────────────────────────
                if (!ConnectivityManager().isOnline)
                  Container(
                    width: double.infinity,
                    color: Colors.orange.shade800,
                    padding: const EdgeInsets.symmetric(
                      vertical: 6,
                      horizontal: 16,
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.wifi_off_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                        SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'OFFLINE MODE — Attempt saved locally',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),

                // ── Question Palette ─────────────────────────────────────────
                Container(
                  height: 60,
                  color: Colors.transparent,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 10,
                    ),
                    itemCount: totalQ,
                    itemBuilder: (context, i) {
                      final qId = widget.exam.questions[i].id;
                      final isAnswered = examProvider.userAnswers.containsKey(
                        qId,
                      );
                      final isVisited = examProvider.visitedQuestionIds
                          .contains(qId);
                      final isMarkedForReview = examProvider.markedForReview
                          .contains(qId);
                      final isCurrent = i == currentQIndex;

                      Color bgColor;
                      Color textColor = Colors.white;
                      bool showTick = false;

                      if (isMarkedForReview) {
                        bgColor = const Color(0xFF8B5CF6); // Purple
                        if (isAnswered) {
                          showTick = true;
                        }
                      } else if (isAnswered) {
                        bgColor = const Color(0xFF10B981); // Green
                      } else if (isVisited) {
                        bgColor = Colors.red.shade600; // Red
                      } else {
                        bgColor = const Color(0xFFECEEF0); // Gray/White
                        textColor = const Color(0xFF0F172A);
                      }

                      final isDark =
                          Theme.of(context).brightness == Brightness.dark;
                      final currentBorderColor = isDark
                          ? const Color(0xFF5D9BFF)
                          : const Color(0xFF0051D5);

                      return GestureDetector(
                        onTap: () => examProvider.jumpToQuestion(i),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                color: bgColor,
                                shape: BoxShape.circle,
                                border: isCurrent
                                    ? Border.all(
                                        color: currentBorderColor,
                                        width: 2.5,
                                      )
                                    : Border.all(
                                        color: Colors.transparent,
                                        width: 2.5,
                                      ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '${i + 1}',
                                style: TextStyle(
                                  color: textColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            if (showTick)
                              Positioned(
                                right: 0,
                                top: -2,
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF10B981),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 8,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // ── Progress Bar ──────────────────────────────────────────────
                LinearProgressIndicator(
                  value: totalQ > 0 ? answeredCount / totalQ : 0,
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  color: const Color(0xFF10B981),
                  minHeight: 3,
                ),

                // ── Legend Row ──────────────────────────────────────────────
                Container(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.black.withValues(alpha: 0.2)
                      : const Color(0xFFF8FAFC),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        _buildLegendItem(
                          context,
                          'Not Visited',
                          const Color(0xFFECEEF0),
                          const Color(0xFF0F172A),
                          hasTick: false,
                        ),
                        const SizedBox(width: 14),
                        _buildLegendItem(
                          context,
                          'Visited',
                          Colors.red.shade600,
                          Colors.white,
                          hasTick: false,
                        ),
                        const SizedBox(width: 14),
                        _buildLegendItem(
                          context,
                          'Answered',
                          const Color(0xFF10B981),
                          Colors.white,
                          hasTick: false,
                        ),
                        const SizedBox(width: 14),
                        _buildLegendItem(
                          context,
                          'Review (Unanswered)',
                          const Color(0xFF8B5CF6),
                          Colors.white,
                          hasTick: false,
                        ),
                        const SizedBox(width: 14),
                        _buildLegendItem(
                          context,
                          'Review (Answered)',
                          const Color(0xFF8B5CF6),
                          Colors.white,
                          hasTick: true,
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Question Content ──────────────────────────────────────────
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Question card
                        Builder(
                          builder: (context) {
                            final isMarkedForReview = examProvider
                                .markedForReview
                                .contains(currentQ.id);
                            return GlassCard(
                              padding: const EdgeInsets.all(18),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            width: 28,
                                            height: 28,
                                            decoration: const BoxDecoration(
                                              color: _kPrimary,
                                              shape: BoxShape.circle,
                                            ),
                                            alignment: Alignment.center,
                                            child: Text(
                                              '${currentQIndex + 1}',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          const Text(
                                            'Question',
                                            style: TextStyle(
                                              color: _kPrimary,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          isMarkedForReview
                                              ? Icons.bookmark
                                              : Icons.bookmark_border,
                                          color: isMarkedForReview
                                              ? const Color(0xFF8B5CF6)
                                              : Colors.grey.shade500,
                                          size: 24,
                                        ),
                                        tooltip: isMarkedForReview
                                            ? 'Remove Bookmark'
                                            : 'Mark for Review',
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: () => examProvider
                                            .toggleMarkForReview(currentQ.id),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  LaTeXWidget(
                                    text: currentQ.questionText,
                                    color: const Color(0xFF0F172A),
                                  ),
                                  if (currentQ.diagram != null &&
                                      currentQ.diagram!.isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        currentQ.diagram!.startsWith('http')
                                            ? currentQ.diagram!
                                            : '${Provider.of<ExamProvider>(context, listen: false).baseUrl}${currentQ.diagram}',
                                        height: 160,
                                        width: double.infinity,
                                        fit: BoxFit.contain,
                                        errorBuilder: (_, _, _) =>
                                            const SizedBox.shrink(),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 20),

                        // Options
                        if (currentQ.options != null)
                          ...currentQ.options!.asMap().entries.map((entry) {
                            final optIndex = entry.key;
                            final opt = entry.value;
                            final optLabels = ['A', 'B', 'C', 'D', 'E'];
                            final label = optIndex < optLabels.length
                                ? optLabels[optIndex]
                                : '${optIndex + 1}';
                            final isSelected =
                                examProvider.userAnswers[currentQ.id] == opt;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: InkWell(
                                onTap: () =>
                                    examProvider.setAnswer(currentQ.id, opt),
                                borderRadius: BorderRadius.circular(14),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? _kSelectedBg
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: isSelected
                                          ? _kPrimary
                                          : const Color(0xFFECEEF0),
                                      width: isSelected ? 1.5 : 1,
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: _kPrimary.withValues(
                                                alpha: 0.15,
                                              ),
                                              blurRadius: 10,
                                              offset: const Offset(0, 2),
                                            ),
                                          ]
                                        : [],
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? _kPrimary
                                              : const Color(0xFFECEEF0),
                                          shape: BoxShape.circle,
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          label,
                                          style: TextStyle(
                                            color: isSelected
                                                ? Colors.white
                                                : const Color(0xFF0F172A),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: InlineMathText(
                                          text: opt,
                                          fontSize: 15,
                                          color: const Color(0xFF0F172A),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),

                        // Unanswered note
                        if (examProvider.userAnswers[currentQ.id] == null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4, left: 4),
                            child: Text(
                              'No answer selected',
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // ── Stats Bar ─────────────────────────────────────────────────
                Container(
                  color: const Color(0xFFF8FAFC),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '$answeredCount/$totalQ answered',
                          style: const TextStyle(
                            color: Color(0xFF75859D),
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (_security.backgroundViolationCount > 0)
                        Flexible(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.warning_amber,
                                size: 14,
                                color: Colors.orange.shade700,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  '${_security.backgroundViolationCount}/${_security.maxViolationsAllowed} violations',
                                  style: TextStyle(
                                    color: Colors.orange.shade700,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),

                // ── Navigation Buttons ────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      top: BorderSide(color: const Color(0xFFECEEF0), width: 1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: currentQIndex > 0
                              ? () => examProvider.previousQuestion()
                              : null,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            foregroundColor: const Color(0xFF0F172A),
                            side: const BorderSide(color: Color(0xFFECEEF0)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.chevron_left, size: 20),
                          label: const Text('PREV'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: currentQIndex < totalQ - 1
                              ? () => examProvider.nextQuestion(totalQ)
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _kPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(
                            Icons.chevron_right,
                            color: Colors.white,
                            size: 20,
                          ),
                          label: const Text(
                            'NEXT',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_freezeExamInteractions)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.85),
                child: Center(
                  child: Card(
                    color: const Color(0xFF1E293B),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: Colors.redAccent, width: 2),
                    ),
                    margin: const EdgeInsets.all(24),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 50,
                            height: 50,
                            child: CircularProgressIndicator(
                              color: Colors.redAccent,
                              strokeWidth: 3,
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            '⚠️ CONNECTION INTERRUPTED',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.none,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Your connection to the secure exam server has been lost. Freeze mode active to preserve exam integrity.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 14,
                              fontWeight: FontWeight.normal,
                              decoration: TextDecoration.none,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'Auto-submitting in: $_reconnectCountdownSeconds seconds',
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Submit Confirmation Dialog ────────────────────────────────────────────

  void _showSubmitConfirmDialog() {
    final examProvider = Provider.of<ExamProvider>(context, listen: false);
    final answered = examProvider.userAnswers.length;
    final total = widget.exam.questions.length;
    final unanswered = total - answered;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.assignment_turned_in_outlined, color: _kPrimary),
            SizedBox(width: 8),
            Text('Submit Exam?', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You have answered $answered out of $total questions.',
              style: const TextStyle(fontSize: 14),
            ),
            if (unanswered > 0) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade300),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.orange.shade700,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$unanswered question(s) are unanswered and will be marked incorrect.',
                        style: TextStyle(
                          color: Colors.orange.shade800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            const Text(
              'This action cannot be undone.',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _submit();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _kPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: const Icon(Icons.send, color: Colors.white, size: 16),
            label: const Text('Submit', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(
    BuildContext context,
    String label,
    Color bgColor,
    Color textColor, {
    required bool hasTick,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: bgColor,
                shape: BoxShape.circle,
                border: bgColor == const Color(0xFFECEEF0)
                    ? Border.all(color: Colors.grey.shade400, width: 0.5)
                    : null,
              ),
            ),
            if (hasTick)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  padding: const EdgeInsets.all(0.5),
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 6),
                ),
              ),
          ],
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white70 : const Color(0xFF475569),
          ),
        ),
      ],
    );
  }
}
