import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../services/api_service.dart';
import '../../services/connectivity_manager.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/animations.dart';
import '../shared/latex_widget.dart';

class SelfAssessmentScreen extends StatefulWidget {
  const SelfAssessmentScreen({super.key});

  @override
  State<SelfAssessmentScreen> createState() => _SelfAssessmentScreenState();
}

class _SelfAssessmentScreenState extends State<SelfAssessmentScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final TextEditingController _customLimitController = TextEditingController();

  // State variables
  bool _isLoading = true;
  String? _errorMessage;
  bool _isConfiguring = true;
  List<String> _availableChapters = [];
  final List<String> _selectedChapters = [];
  int _selectedLimit = 10;
  int _selectedTime = 30; // in minutes

  // Session details
  String? _sessionToken;
  int _totalQuestions = 10;
  DateTime? _expiresAt;

  // Question tracking list (loaded batch by batch)
  final List<Map<String, dynamic>> _questionsList = [];
  bool _fetchingNextBatch = false;
  int _currentQuestionIndex = 0;
  final Map<String, String> _userAnswers = {}; // questionId -> selectedOption
  final Set<String> _markedForReview = {}; // questionId
  final Set<String> _visitedQuestionIds = {}; // questionId

  // Current question details
  bool _isCompleted = false;
  bool _isSubmitting = false;

  // Results details (populated when completed)
  Map<String, dynamic>? _results;
  int _resultsActiveTab = 0; // 0 for Summary, 1 for Review Solutions

  // Timers
  Timer? _heartbeatTimer;
  Timer? _countdownTimer;
  int _remainingSeconds = 1800; // default 30 mins
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  bool _isOnline = true;

  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _isOnline = ConnectivityManager().isOnline;
    _animationController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat(reverse: true);
    _setupConnectivityListener();
    _loadChapters();
  }

  @override
  void dispose() {
    _customLimitController.dispose();
    _animationController.dispose();
    _heartbeatTimer?.cancel();
    _countdownTimer?.cancel();
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  void _setupConnectivityListener() {
    _connectivitySubscription = ConnectivityManager().statusChanges.listen((
      result,
    ) {
      final online = result != ConnectivityResult.none;
      if (online != _isOnline) {
        setState(() {
          _isOnline = online;
        });
        if (online && _sessionToken != null && !_isCompleted) {
          // Trigger a heartbeat immediately on reconnection
          _sendHeartbeat();
        }
      }
    });
  }

  Future<void> _loadChapters() async {
    if (!_isOnline) {
      setState(() {
        _isLoading = false;
        _errorMessage =
            'An active internet connection is required to start a self-assessment.';
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final chapters = await _apiService.getSelfAssessmentChapters();
      setState(() {
        _availableChapters = chapters;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.message;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load available chapters. Please try again.';
      });
    }
  }

  Future<void> _startAssessmentSession() async {
    if (!_isOnline) {
      setState(() {
        _isLoading = false;
        _errorMessage =
            'An active internet connection is required to start a self-assessment.';
      });
      return;
    }

    if (_selectedChapters.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one chapter.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (_selectedLimit < 10 || _selectedLimit > 80) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select or enter a number of questions between 10 and 80.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await _apiService.generateSelfAssessment(
        chapters: _selectedChapters,
        limit: _selectedLimit,
        time: _selectedTime,
      );

      _sessionToken = data['token'];
      _totalQuestions = data['totalQuestions'] ?? _selectedLimit;
      if (data['expiresAt'] != null) {
        _expiresAt = DateTime.parse(data['expiresAt']);
      }

      _questionsList.clear();
      _userAnswers.clear();
      _markedForReview.clear();
      _visitedQuestionIds.clear();
      _currentQuestionIndex = 0;
      _isCompleted = false;
      _resultsActiveTab = 0;

      // Start 15s heartbeats
      _startHeartbeats();
      _startCountdownTimer();

      // Fetch all questions of the assessment session in one go (offset 0, limit = _totalQuestions)
      await _loadNextQuestionsBatch(0, limit: _totalQuestions);

      setState(() {
        _isConfiguring = false;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.message;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to generate assessment. Please try again.';
      });
    }
  }

  void _startHeartbeats() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (_sessionToken != null && !_isCompleted && _isOnline) {
        _sendHeartbeat();
      }
    });
  }

  Future<void> _sendHeartbeat() async {
    try {
      await _apiService.sendSelfAssessmentHeartbeat(_sessionToken!);
    } catch (e) {
      debugPrint('[SelfAssessment] Heartbeat failed: $e');
      // If unauthorized or session invalid (403), terminate
      if (e is ApiException && (e.statusCode == 403 || e.statusCode == 401)) {
        _handleSessionTerminated(e.message);
      }
    }
  }

  void _handleSessionTerminated(String reason) {
    _heartbeatTimer?.cancel();
    if (mounted) {
      setState(() {
        _errorMessage = 'Session Terminated: $reason';
        _sessionToken = null;
      });
    }
  }

  void _startCountdownTimer() {
    _countdownTimer?.cancel();
    if (_expiresAt == null) return;

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final remaining = _expiresAt!.difference(DateTime.now()).inSeconds;
      if (remaining <= 0) {
        timer.cancel();
        _autoSubmitAllAnswers();
      } else {
        setState(() {
          _remainingSeconds = remaining;
        });
      }
    });
  }

  Future<void> _loadNextQuestionsBatch(int offset, {int limit = 5}) async {
    if (_sessionToken == null || _fetchingNextBatch) return;
    if (_questionsList.length > offset) {
      return; // Batch already loaded or loading
    }

    _fetchingNextBatch = true;
    try {
      final data = await _apiService.getSelfAssessmentQuestionsBatch(
        _sessionToken!,
        offset: offset,
        limit: limit,
      );

      final List<dynamic> questionsData = data['questions'] ?? [];
      final List<Map<String, dynamic>> parsedBatch = questionsData
          .map((q) => Map<String, dynamic>.from(q as Map))
          .toList();

      setState(() {
        _questionsList.addAll(parsedBatch);
        _fetchingNextBatch = false;

        // Mark the first loaded question as visited if just starting
        if (_questionsList.isNotEmpty && _visitedQuestionIds.isEmpty) {
          _visitedQuestionIds.add(_questionsList[0]['id']);
        }
      });
      debugPrint(
        '[SelfAssessment] Loaded questions batch at offset $offset. Total: ${_questionsList.length}',
      );
    } catch (e) {
      _fetchingNextBatch = false;
      debugPrint('[SelfAssessment] Failed to load batch at offset $offset: $e');
    }
  }

  String? _getCurrentQuestionId() {
    if (_questionsList.length > _currentQuestionIndex) {
      return _questionsList[_currentQuestionIndex]['id'];
    }
    return null;
  }

  void _jumpToQuestion(int index) {
    if (index < 0 || index >= _totalQuestions) return;

    setState(() {
      _currentQuestionIndex = index;
    });

    final currentId = _getCurrentQuestionId();
    if (currentId != null) {
      setState(() {
        _visitedQuestionIds.add(currentId);
      });
    }
  }

  Future<void> _autoSubmitAllAnswers() async {
    _countdownTimer?.cancel();
    _heartbeatTimer?.cancel();
    if (_sessionToken == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final data = await _apiService.submitAllSelfAssessmentAnswers(
        _sessionToken!,
        _userAnswers,
      );
      setState(() {
        _isCompleted = true;
        _results = Map<String, dynamic>.from(data['results'] ?? {});
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Test timed out. Auto-submission failed: $e';
      });
    }
  }

  Future<void> _submitAllAnswers() async {
    if (_sessionToken == null) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? const Color(0xFFDAE2FD) : const Color(0xFF0F172A);
    final secondaryTextColor = isDark
        ? const Color(0xFFCBC3D7)
        : const Color(0xFF75859D);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: GlassCard(
          padding: const EdgeInsets.all(24),
          borderRadius: 24,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.assignment_turned_in_outlined,
                color: Color(0xFF8B5CF6),
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                'Finish Practice Test?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Are you sure you want to submit the test? You have answered ${_userAnswers.length} out of $_totalQuestions questions.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: secondaryTextColor,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: isDark ? Colors.white12 : const Color(0xFFECEEF0),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(color: textColor),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B5CF6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Finish',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirm != true) return;

    _countdownTimer?.cancel();
    _heartbeatTimer?.cancel();

    setState(() {
      _isSubmitting = true;
    });

    try {
      final data = await _apiService.submitAllSelfAssessmentAnswers(
        _sessionToken!,
        _userAnswers,
      );

      setState(() {
        _isCompleted = true;
        _results = Map<String, dynamic>.from(data['results'] ?? {});
        _isSubmitting = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _isSubmitting = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Submission failed: ${e.message}'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } catch (e) {
      setState(() {
        _isSubmitting = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('An error occurred. Please try again.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  String _formatTime(int totalSeconds) {
    final int hours = totalSeconds ~/ 3600;
    final int minutes = (totalSeconds % 3600) ~/ 60;
    final int seconds = totalSeconds % 60;

    final String mStr = minutes.toString().padLeft(2, '0');
    final String sStr = seconds.toString().padLeft(2, '0');

    if (hours > 0) {
      final String hStr = hours.toString().padLeft(2, '0');
      return '$hStr:$mStr:$sStr';
    }
    return '$mStr:$sStr';
  }

  Widget _buildLegendItem(
    String label,
    Color color,
    Color textColor, {
    required bool hasTick,
  }) {
    return Row(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: color == const Color(0xFFECEEF0)
                    ? Border.all(color: const Color(0xFFCBD5E1))
                    : null,
              ),
            ),
            if (hasTick)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  padding: const EdgeInsets.all(1),
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
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white70
                : const Color(0xFF334155),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themePrimary = isDark
        ? const Color(0xFF8B5CF6) // Nocturnal violet accent
        : const Color(0xFF0051D5);
    final textColor = isDark ? const Color(0xFFDAE2FD) : const Color(0xFF0F172A);
    final secondaryTextColor = isDark
        ? const Color(0xFFCBC3D7)
        : const Color(0xFF75859D);

    final navigator = Navigator.of(context);
    return PopScope(
      canPop: _isConfiguring || _isCompleted || _errorMessage != null,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => Dialog(
            backgroundColor: Colors.transparent,
            child: GlassCard(
              padding: const EdgeInsets.all(24),
              borderRadius: 24,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.redAccent,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Exit Self Assessment?',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Your progress will be lost and this attempt will count towards your daily limit of 5 assessments.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: secondaryTextColor,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context, false),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: isDark ? Colors.white12 : const Color(0xFFECEEF0),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Cancel',
                            style: TextStyle(color: textColor),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Exit',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
        if (confirm == true && mounted) {
          navigator.pop();
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            // Premium background gradient decoration
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: isDark
                        ? [const Color(0xFF0B1326), const Color(0xFF060D20)]
                        : [const Color(0xFFF8FAFC), const Color(0xFFF1F5F9)],
                  ),
                ),
              ),
            ),

            // Animated ambient glowing circles for glassmorphism
            AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                final progress = _animationController.value;
                final angle = progress * 2 * math.pi;

                // Sinusoidal drift offsets to simulate fluid flow
                final dx1 = math.sin(angle) * 45;
                final dy1 = math.cos(angle) * 45;

                final dx2 = math.cos(angle + math.pi / 2) * 55;
                final dy2 = math.sin(angle + math.pi / 2) * 55;

                final dx3 = math.sin(angle + math.pi) * 40;
                final dy3 = math.cos(angle + math.pi) * 40;

                return Stack(
                  children: [
                    Positioned(
                      top: -100 + dy1,
                      right: -100 + dx1,
                      child: Container(
                        width: 340,
                        height: 340,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark
                              ? const Color(0xFF8B5CF6).withValues(alpha: 0.12)
                              : const Color(0xFF8B5CF6).withValues(alpha: 0.05),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 80 + dy2,
                      left: -100 + dx2,
                      child: Container(
                        width: 360,
                        height: 360,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark
                              ? const Color(0xFF0051D5).withValues(alpha: 0.10)
                              : const Color(0xFF0051D5).withValues(alpha: 0.04),
                        ),
                      ),
                    ),
                    if (isDark)
                      Positioned(
                        top: 260 + dy3,
                        right: -120 + dx3,
                        child: Container(
                          width: 300,
                          height: 300,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFD946EF).withValues(alpha: 0.08),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),

            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                child: const SizedBox.shrink(),
              ),
            ),

            SafeArea(
              child: Column(
                children: [
                  // App Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (_isConfiguring || _isCompleted) ...[
                          IconButton(
                            icon: Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: textColor,
                            ),
                            onPressed: () => Navigator.maybePop(context),
                          ),
                          Text(
                            _isCompleted
                                ? 'Assessment Results'
                                : 'Self Assessment',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: textColor,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(
                            width: 48,
                          ), // Spacer to balance back button
                        ] else ...[
                          Row(
                            children: [
                              Tooltip(
                                message: 'Practice Mode Active',
                                child: Icon(
                                  Icons.shield,
                                  color: Colors.greenAccent.shade400,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Q ${_currentQuestionIndex + 1}/$_totalQuestions',
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _remainingSeconds < 60
                                  ? Colors.red.shade700
                                  : themePrimary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.timer_outlined,
                                  color: _remainingSeconds < 60
                                      ? Colors.white
                                      : themePrimary,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _formatTime(_remainingSeconds),
                                  style: TextStyle(
                                    color: _remainingSeconds < 60
                                        ? Colors.white
                                        : textColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () => _submitAllAnswers(),
                            child: Text(
                              'FINISH',
                              style: TextStyle(
                                color: themePrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Main Body
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        if (_isLoading || _isSubmitting) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircularProgressIndicator(
                                  color: themePrimary,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _isSubmitting
                                      ? 'Grading answers securely...'
                                      : 'Preparing questions...',
                                  style: TextStyle(
                                    color: secondaryTextColor,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        if (_errorMessage != null) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32.0),
                              child: GlassCard(
                                padding: const EdgeInsets.all(28),
                                color: isDark
                                    ? const Color(0xFF1E1B4B).withValues(alpha: 0.3)
                                    : Colors.white.withValues(alpha: 0.8),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.error_outline_rounded,
                                      color: Colors.redAccent,
                                      size: 54,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Attention Required',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                        color: textColor,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      _errorMessage!,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: secondaryTextColor,
                                        height: 1.4,
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        onPressed: () => Navigator.pop(context),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: themePrimary,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 14,
                                          ),
                                        ),
                                        child: const Text(
                                          'Go Back',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }

                        if (_isConfiguring) {
                          return _buildConfigurationView(
                            textColor,
                            secondaryTextColor,
                            themePrimary,
                            isDark,
                          );
                        }

                        if (_isCompleted) {
                          return _buildResultsView(
                            textColor,
                            secondaryTextColor,
                            themePrimary,
                            isDark,
                          );
                        }

                        return _buildQuestionView(
                          textColor,
                          secondaryTextColor,
                          themePrimary,
                          isDark,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            // Full screen offline barrier
            if (!_isOnline)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.75),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: GlassCard(
                        padding: const EdgeInsets.all(28),
                        color: isDark
                            ? const Color(0xFF1E1B4B).withValues(alpha: 0.4)
                            : Colors.white.withValues(alpha: 0.8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.wifi_off_rounded,
                              color: Colors.amberAccent,
                              size: 54,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Connection Disconnected',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Self-assessments require an active server authority connection. Reconnect to resume.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: secondaryTextColor,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  themePrimary,
                                ),
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
      ),
    );
  }

  void _previousQuestion() {
    if (_currentQuestionIndex > 0) {
      _jumpToQuestion(_currentQuestionIndex - 1);
    }
  }

  void _nextQuestion() {
    if (_currentQuestionIndex < _totalQuestions - 1) {
      _jumpToQuestion(_currentQuestionIndex + 1);
    }
  }

  void _toggleMarkForReview(String questionId) {
    setState(() {
      if (_markedForReview.contains(questionId)) {
        _markedForReview.remove(questionId);
      } else {
        _markedForReview.add(questionId);
      }
    });
  }

  Widget _buildQuestionView(
    Color textColor,
    Color secondaryTextColor,
    Color themePrimary,
    bool isDark,
  ) {
    if (_questionsList.length <= _currentQuestionIndex) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: themePrimary),
            const SizedBox(height: 16),
            Text(
              'Loading questions batch...',
              style: TextStyle(color: secondaryTextColor, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    final currentQ = _questionsList[_currentQuestionIndex];
    final currentQId = currentQ['id'] as String;
    final qText = currentQ['questionText'] as String? ?? '';
    final qDiagram = currentQ['diagram'] as String?;
    final qOptions = List<String>.from(currentQ['options'] ?? []);

    final totalQ = _totalQuestions;
    final answeredCount = _userAnswers.length;
    final isMarkedForReview = _markedForReview.contains(currentQId);

    return Column(
      children: [
        // ── Question Palette ─────────────────────────────────────────
        Container(
          height: 60,
          color: Colors.transparent,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            itemCount: totalQ,
            itemBuilder: (context, i) {
              final bool isLoaded = i < _questionsList.length;
              final String? qId = isLoaded ? _questionsList[i]['id'] : null;

              final isAnswered = qId != null && _userAnswers.containsKey(qId);
              final isVisited =
                  qId != null && _visitedQuestionIds.contains(qId);
              final isMarked = qId != null && _markedForReview.contains(qId);
              final isCurrent = i == _currentQuestionIndex;

              Color bgColor;
              Color itemTextColor = Colors.white;
              bool showTick = false;

              if (isMarked) {
                bgColor = const Color(0xFF8B5CF6); // Purple
                if (isAnswered) {
                  showTick = true;
                }
              } else if (isAnswered) {
                bgColor = const Color(0xFF10B981); // Green
              } else if (isVisited) {
                bgColor = Colors.red.shade600; // Red
              } else {
                bgColor = isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : const Color(0xFFECEEF0); // Gray/White
                itemTextColor = isDark ? const Color(0xFFDAE2FD) : const Color(0xFF0F172A);
              }

              final currentBorderColor = themePrimary;

              return GestureDetector(
                onTap: () => _jumpToQuestion(i),
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
                            ? Border.all(color: currentBorderColor, width: 2.5)
                            : Border.all(
                                color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.transparent,
                                width: 1.5,
                              ),
                        boxShadow: isCurrent
                            ? [
                                BoxShadow(
                                  color: themePrimary.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                )
                              ]
                            : [],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(
                          color: itemTextColor,
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
          backgroundColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
          color: const Color(0xFF10B981),
          minHeight: 4,
        ),

        // ── Legend Row ──────────────────────────────────────────────
        Container(
          color: isDark
              ? const Color(0xFF0B1326).withValues(alpha: 0.5)
              : const Color(0xFFF8FAFC),
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildLegendItem(
                  'Not Visited',
                  isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFECEEF0),
                  isDark ? const Color(0xFFDAE2FD) : const Color(0xFF0F172A),
                  hasTick: false,
                ),
                const SizedBox(width: 14),
                _buildLegendItem(
                  'Visited',
                  Colors.red.shade600,
                  Colors.white,
                  hasTick: false,
                ),
                const SizedBox(width: 14),
                _buildLegendItem(
                  'Answered',
                  const Color(0xFF10B981),
                  Colors.white,
                  hasTick: false,
                ),
                const SizedBox(width: 14),
                _buildLegendItem(
                  'Review (Unanswered)',
                  const Color(0xFF8B5CF6),
                  Colors.white,
                  hasTick: false,
                ),
                const SizedBox(width: 14),
                _buildLegendItem(
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
                GlassCard(
                  padding: const EdgeInsets.all(18),
                  color: isDark
                      ? const Color(0xFF1E1B4B).withValues(alpha: 0.3)
                      : Colors.white.withValues(alpha: 0.65),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: themePrimary,
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '${_currentQuestionIndex + 1}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Question',
                                style: TextStyle(
                                  color: themePrimary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
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
                            onPressed: () => _toggleMarkForReview(currentQId),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      InlineMathText(
                        text: qText,
                        fontSize: 16,
                        color: textColor,
                      ),
                      if (qDiagram != null && qDiagram.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            qDiagram.startsWith('http')
                                ? qDiagram
                                : '${_apiService.baseUrl}$qDiagram',
                            height: 160,
                            width: double.infinity,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => const SizedBox.shrink(),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Options
                ...qOptions.asMap().entries.map((entry) {
                  final optIndex = entry.key;
                  final opt = entry.value;
                  final optLabels = ['A', 'B', 'C', 'D', 'E'];
                  final label = optIndex < optLabels.length
                      ? optLabels[optIndex]
                      : '${optIndex + 1}';

                  final isSelected = _userAnswers[currentQId] == opt;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          if (_userAnswers[currentQId] == opt) {
                            _userAnswers.remove(currentQId);
                          } else {
                            _userAnswers[currentQId] = opt;
                          }
                        });
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? (isDark
                                    ? const Color(0xFF1E1B4B).withValues(alpha: 0.65)
                                    : const Color(0xFFE6EFFF))
                              : (isDark
                                    ? Colors.white.withValues(alpha: 0.05)
                                    : Colors.white),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? themePrimary
                                : (isDark
                                      ? Colors.white.withValues(alpha: 0.1)
                                      : const Color(0xFFECEEF0)),
                            width: isSelected ? 2.0 : 1.5,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: themePrimary.withValues(alpha: 0.25),
                                    blurRadius: 15,
                                    spreadRadius: 1,
                                    offset: const Offset(0, 0),
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
                                    ? themePrimary
                                    : (isDark
                                          ? Colors.white.withValues(alpha: 0.1)
                                          : const Color(0xFFECEEF0)),
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                label,
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : textColor,
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
                                color: textColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),

                // Unanswered note
                if (_userAnswers[currentQId] == null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 4),
                    child: Text(
                      'No answer selected',
                      style: TextStyle(
                        color: secondaryTextColor,
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
          color: isDark
              ? Colors.black.withValues(alpha: 0.15)
              : const Color(0xFFF8FAFC),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '$answeredCount/$totalQ answered',
                  style: TextStyle(
                    color: secondaryTextColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),

        // ── Navigation Buttons ────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            border: Border(
              top: BorderSide(
                color: isDark ? Colors.white12 : const Color(0xFFECEEF0),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _currentQuestionIndex > 0
                      ? _previousQuestion
                      : null,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    foregroundColor: textColor,
                    side: BorderSide(
                      color: isDark ? Colors.white12 : const Color(0xFFECEEF0),
                    ),
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
                  onPressed: _currentQuestionIndex < totalQ - 1
                      ? _nextQuestion
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: themePrimary,
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
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResultsView(
    Color textColor,
    Color secondaryTextColor,
    Color themePrimary,
    bool isDark,
  ) {
    final score = (_results?['score'] as num?)?.toInt() ?? 0;
    final total = (_results?['total'] as num?)?.toInt() ?? _totalQuestions;
    final percentage = (_results?['percentage'] as num?)?.toDouble() ?? 0.0;
    final analytics = _results?['analytics'] ?? {};
    final weakTopics = List<String>.from(analytics['weakTopics'] ?? []);
    final List<dynamic> gradedQuestions = _results?['questions'] ?? [];

    return Column(
      children: [
        // Premium Sliding Tab Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1E1B4B).withValues(alpha: 0.2)
                  : Colors.black.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.05),
              ),
            ),
            child: Stack(
              children: [
                AnimatedAlign(
                  alignment: _resultsActiveTab == 0
                      ? Alignment.centerLeft
                      : Alignment.centerRight,
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  child: FractionallySizedBox(
                    widthFactor: 0.5,
                    child: Container(
                      margin: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: themePrimary,
                        borderRadius: BorderRadius.circular(21),
                        boxShadow: [
                          BoxShadow(
                            color: themePrimary.withValues(alpha: 0.25),
                            blurRadius: 8,
                            spreadRadius: 1,
                          )
                        ],
                      ),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _resultsActiveTab = 0),
                        behavior: HitTestBehavior.opaque,
                        child: Center(
                          child: Text(
                            'SUMMARY',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                              color: _resultsActiveTab == 0
                                  ? Colors.white
                                  : (isDark
                                      ? const Color(0xFFDAE2FD)
                                      : const Color(0xFF475569)),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _resultsActiveTab = 1),
                        behavior: HitTestBehavior.opaque,
                        child: Center(
                          child: Text(
                            'REVIEW SOLUTIONS',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                              color: _resultsActiveTab == 1
                                  ? Colors.white
                                  : (isDark
                                      ? const Color(0xFFDAE2FD)
                                      : const Color(0xFF475569)),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Tab Content
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _resultsActiveTab == 0
                ? _buildResultsSummary(
                    score,
                    total,
                    percentage,
                    weakTopics,
                    themePrimary,
                    isDark,
                    textColor,
                    secondaryTextColor,
                  )
                : _buildResultsReviewList(
                    gradedQuestions,
                    themePrimary,
                    isDark,
                    textColor,
                    secondaryTextColor,
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildResultsSummary(
    int score,
    int total,
    double percentage,
    List<String> weakTopics,
    Color themePrimary,
    bool isDark,
    Color textColor,
    Color secondaryTextColor,
  ) {
    final bool passed = percentage >= 40.0;
    return SingleChildScrollView(
      key: const ValueKey<int>(0),
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        children: [
          FadeInSlide(
            duration: const Duration(milliseconds: 600),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: passed
                    ? Colors.green.withValues(alpha: 0.1)
                    : Colors.redAccent.withValues(alpha: 0.1),
                boxShadow: [
                  BoxShadow(
                    color: (passed ? Colors.green : Colors.redAccent)
                        .withValues(alpha: 0.15),
                    blurRadius: 24,
                    spreadRadius: 2,
                  )
                ],
              ),
              child: Icon(
                passed
                    ? Icons.check_circle_outline_rounded
                    : Icons.error_outline_rounded,
                color: passed ? Colors.green : Colors.redAccent,
                size: 72,
              ),
            ),
          ),
          const SizedBox(height: 20),
          FadeInSlide(
            duration: const Duration(milliseconds: 600),
            delay: const Duration(milliseconds: 100),
            child: Text(
              passed ? 'Assessment Complete!' : 'Practice Mode Finished',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: textColor,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 8),
          FadeInSlide(
            duration: const Duration(milliseconds: 600),
            delay: const Duration(milliseconds: 150),
            child: Text(
              'Your results have been processed securely',
              style: TextStyle(fontSize: 14, color: secondaryTextColor),
            ),
          ),
          const SizedBox(height: 28),

          // Scorecard Card
          FadeInSlide(
            duration: const Duration(milliseconds: 600),
            delay: const Duration(milliseconds: 200),
            child: GlassCard(
              padding: const EdgeInsets.all(24),
              color: isDark
                  ? const Color(0xFF1E1B4B).withValues(alpha: 0.3)
                  : Colors.white.withValues(alpha: 0.75),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text(
                        '$score / $total',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Score Obtained',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: secondaryTextColor,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: textColor.withValues(alpha: 0.1),
                  ),
                  Column(
                    children: [
                      Text(
                        '${percentage.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: percentage >= 50.0
                              ? Colors.green
                              : Colors.orangeAccent,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Accuracy',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: secondaryTextColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),

          // Focus areas
          if (weakTopics.isNotEmpty) ...[
            FadeInSlide(
              duration: const Duration(milliseconds: 600),
              delay: const Duration(milliseconds: 250),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Recommended Focus Areas',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: textColor,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            ...List.generate(weakTopics.length, (idx) {
              final topic = weakTopics[idx];
              return FadeInSlide(
                duration: const Duration(milliseconds: 600),
                delay: Duration(milliseconds: 300 + (idx * 50)),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orangeAccent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.orangeAccent.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.lightbulb_outline_rounded,
                        color: Colors.orangeAccent,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          topic,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ] else ...[
            FadeInSlide(
              duration: const Duration(milliseconds: 600),
              delay: const Duration(milliseconds: 250),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.green.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      color: Colors.green,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Perfect Score! You demonstrated complete mastery across all topics.',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 36),

          // Return to dashboard
          FadeInSlide(
            duration: const Duration(milliseconds: 600),
            delay: const Duration(milliseconds: 400),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: themePrimary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                  shadowColor: themePrimary.withValues(alpha: 0.3),
                ),
                child: const Text(
                  'Back to Dashboard',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsReviewList(
    List<dynamic> gradedQuestions,
    Color themePrimary,
    bool isDark,
    Color textColor,
    Color secondaryTextColor,
  ) {
    if (gradedQuestions.isEmpty) {
      return const Center(
        child: Text(
          'No solutions review data returned by server.',
          style: TextStyle(fontStyle: FontStyle.italic),
        ),
      );
    }

    return ListView.builder(
      key: const ValueKey<int>(1),
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      itemCount: gradedQuestions.length,
      itemBuilder: (context, index) {
        final q = gradedQuestions[index];
        final qText = q['questionText'] as String? ?? '';
        final diagram = q['diagram'] as String?;
        final userAns = q['userAnswer'] as String?;
        final correctAns = q['correctAnswer'] as String?;
        final isCorrect = q['isCorrect'] as bool? ?? false;
        final bool isUnanswered = userAns == null;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          child: GlassCard(
            padding: EdgeInsets.zero,
            color: isDark
                ? const Color(0xFF1E1B4B).withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.75),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: themePrimary.withValues(alpha: 0.1),
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: themePrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        isUnanswered
                            ? 'UNANSWERED'
                            : (isCorrect ? 'CORRECT' : 'INCORRECT'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: isUnanswered
                              ? Colors.orangeAccent
                              : (isCorrect ? Colors.green : Colors.redAccent),
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        isUnanswered
                            ? Icons.help_outline_rounded
                            : (isCorrect
                                ? Icons.check_circle_outline_rounded
                                : Icons.cancel_outlined),
                        color: isUnanswered
                            ? Colors.orangeAccent
                            : (isCorrect ? Colors.green : Colors.redAccent),
                        size: 20,
                      ),
                    ],
                  ),
                ),
                Divider(
                  height: 1,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : const Color(0xFFECEEF0),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InlineMathText(
                        text: qText,
                        color: textColor,
                      ),
                      if (diagram != null && diagram.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            diagram.startsWith('http')
                                ? diagram
                                : '${_apiService.baseUrl}$diagram',
                            height: 140,
                            width: double.infinity,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => const SizedBox.shrink(),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      _buildReviewOptionRow(
                        label: 'Your Answer',
                        value: userAns ?? 'Not Answered',
                        isCorrect: isCorrect,
                        color: isCorrect ? Colors.green : Colors.redAccent,
                        textColor: textColor,
                        isDark: isDark,
                      ),
                      if (!isCorrect) const SizedBox(height: 8),
                      if (!isCorrect)
                        _buildReviewOptionRow(
                          label: 'Correct Answer',
                          value: correctAns ?? 'N/A',
                          isCorrect: true,
                          color: Colors.green,
                          textColor: textColor,
                          isDark: isDark,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildReviewOptionRow({
    required String label,
    required String value,
    required bool isCorrect,
    required Color color,
    required Color textColor,
    required bool isDark,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          InlineMathText(text: value, fontSize: 14, color: textColor),
        ],
      ),
    );
  }

  Widget _buildConfigurationView(
    Color textColor,
    Color secondaryTextColor,
    Color themePrimary,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Customize Your Practice',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: textColor,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select chapters, question limit, and time to generate a randomized test.',
            style: TextStyle(fontSize: 14, color: secondaryTextColor),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Chapter Selection
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Select Chapter(s)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: textColor,
                        ),
                      ),
                      if (_availableChapters.isNotEmpty)
                        TextButton(
                          onPressed: () {
                            setState(() {
                              if (_selectedChapters.length ==
                                  _availableChapters.length) {
                                _selectedChapters.clear();
                              } else {
                                _selectedChapters.clear();
                                _selectedChapters.addAll(_availableChapters);
                              }
                            });
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: themePrimary,
                          ),
                          child: Text(
                            _selectedChapters.length ==
                                    _availableChapters.length
                                ? 'Deselect All'
                                : 'Select All',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (_availableChapters.isEmpty)
                    Text(
                      'No chapters available for your class.',
                      style: TextStyle(
                        color: secondaryTextColor,
                        fontStyle: FontStyle.italic,
                      ),
                    )
                  else
                    GlassCard(
                      borderRadius: 16,
                      padding: EdgeInsets.zero,
                      color: isDark
                          ? const Color(0xFF1E1B4B).withValues(alpha: 0.2)
                          : Colors.white.withValues(alpha: 0.6),
                      child: Container(
                        constraints: const BoxConstraints(maxHeight: 220),
                        child: ListView.builder(
                          shrinkWrap: true,
                          physics: const ClampingScrollPhysics(),
                          itemCount: _availableChapters.length,
                          itemBuilder: (context, index) {
                            final chapterName = _availableChapters[index];
                            final isSelected = _selectedChapters.contains(
                              chapterName,
                            );
                            return CheckboxListTile(
                              title: Text(
                                chapterName,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: textColor,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                              value: isSelected,
                              activeColor: themePrimary,
                              onChanged: (val) {
                                setState(() {
                                  if (val == true) {
                                    _selectedChapters.add(chapterName);
                                  } else {
                                    _selectedChapters.remove(chapterName);
                                  }
                                });
                              },
                              controlAffinity: ListTileControlAffinity.leading,
                            );
                          },
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),

                  // Question Limit Selection
                  Text(
                    'Number of Questions',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ...[10, 20, 40].map((count) {
                        final isSelected = _selectedLimit == count;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedLimit = count;
                              _customLimitController.clear();
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? themePrimary
                                  : (isDark
                                      ? Colors.white.withValues(alpha: 0.05)
                                      : Colors.white),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? themePrimary
                                    : (isDark
                                        ? Colors.white.withValues(alpha: 0.1)
                                        : const Color(0xFFECEEF0)),
                                width: 1.5,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: themePrimary.withValues(alpha: 0.25),
                                        blurRadius: 10,
                                        spreadRadius: 1,
                                      )
                                    ]
                                  : [],
                            ),
                            child: Text(
                              '$count Qs',
                              style: TextStyle(
                                color: isSelected ? Colors.white : textColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        );
                      }),
                      // Custom question count text field
                      SizedBox(
                        width: 100,
                        height: 40,
                        child: TextField(
                          controller: _customLimitController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(2),
                          ],
                          style: TextStyle(
                            color: textColor,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                          onChanged: (val) {
                            setState(() {
                              if (val.trim().isEmpty) {
                                _selectedLimit = 10;
                              } else {
                                final parsed = int.tryParse(val);
                                if (parsed != null) {
                                  _selectedLimit = parsed;
                                }
                              }
                            });
                          },
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            hintText: 'Custom',
                            hintStyle: TextStyle(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.35)
                                  : Colors.black.withValues(alpha: 0.4),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            filled: true,
                            fillColor: _customLimitController.text.isNotEmpty
                                ? themePrimary.withValues(alpha: 0.1)
                                : (isDark
                                    ? Colors.white.withValues(alpha: 0.05)
                                    : Colors.white),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: _customLimitController.text.isNotEmpty
                                    ? themePrimary
                                    : (isDark
                                        ? Colors.white.withValues(alpha: 0.1)
                                        : const Color(0xFFECEEF0)),
                                width: 1.5,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: _customLimitController.text.isNotEmpty
                                    ? themePrimary
                                    : (isDark
                                        ? Colors.white.withValues(alpha: 0.1)
                                        : const Color(0xFFECEEF0)),
                                width: 1.5,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: themePrimary,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Duration Selection
                  Text(
                    'Time Limit',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: [10, 15, 20, 30, 45, 60].map((mins) {
                      final isSelected = _selectedTime == mins;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedTime = mins;
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? themePrimary
                                : (isDark
                                    ? Colors.white.withValues(alpha: 0.05)
                                    : Colors.white),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? themePrimary
                                  : (isDark
                                      ? Colors.white.withValues(alpha: 0.1)
                                      : const Color(0xFFECEEF0)),
                              width: 1.5,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: themePrimary.withValues(alpha: 0.25),
                                      blurRadius: 10,
                                      spreadRadius: 1,
                                    )
                                  ]
                                : [],
                          ),
                          child: Text(
                            '$mins mins',
                            style: TextStyle(
                              color: isSelected ? Colors.white : textColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),

          // Action Button
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _selectedChapters.isEmpty
                    ? null
                    : _startAssessmentSession,
                style: ElevatedButton.styleFrom(
                  backgroundColor: themePrimary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: themePrimary.withValues(alpha: 0.25),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: _selectedChapters.isEmpty ? 0 : 8,
                  shadowColor: themePrimary.withValues(alpha: 0.4),
                ),
                child: const Text(
                  'Start Practice Test',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
