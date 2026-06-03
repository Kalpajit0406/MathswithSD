import 'dart:async';
import 'package:flutter/material.dart';
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

class _SelfAssessmentScreenState extends State<SelfAssessmentScreen> {
  final ApiService _apiService = ApiService();
  
  // State variables
  bool _isLoading = true;
  String? _errorMessage;
  
  // Session details
  String? _sessionToken;
  String? _sessionId;
  int _totalQuestions = 10;
  DateTime? _expiresAt;
  
  // Current question details
  bool _isCompleted = false;
  String? _questionId;
  int _currentQuestionIndex = 0;
  String? _questionText;
  List<String> _options = [];
  String? _diagram;
  String? _chapter;
  
  // Selected option
  String? _selectedOption;
  bool _isSubmitting = false;
  
  // Results details (populated when completed)
  Map<String, dynamic>? _results;
  
  // Timers
  Timer? _heartbeatTimer;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  bool _isOnline = true;
  
  @override
  void initState() {
    super.initState();
    _isOnline = ConnectivityManager().isOnline;
    _setupConnectivityListener();
    _startAssessmentSession();
  }
  
  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    _connectivitySubscription?.cancel();
    super.dispose();
  }
  
  void _setupConnectivityListener() {
    _connectivitySubscription = ConnectivityManager().statusChanges.listen((result) {
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
  
  Future<void> _startAssessmentSession() async {
    if (!_isOnline) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'An active internet connection is required to start a self-assessment.';
      });
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final data = await _apiService.generateSelfAssessment();
      
      _sessionToken = data['token'];
      _sessionId = data['sessionId'];
      _totalQuestions = data['totalQuestions'] ?? 10;
      if (data['expiresAt'] != null) {
        _expiresAt = DateTime.parse(data['expiresAt']);
      }
      debugPrint('[SelfAssessment] Session started: $_sessionId, expires at: $_expiresAt');
      
      // Start 15s heartbeats
      _startHeartbeats();
      
      // Fetch first question
      await _loadCurrentQuestion();
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
  
  Future<void> _loadCurrentQuestion() async {
    if (_sessionToken == null) return;
    
    setState(() {
      _isLoading = true;
      _selectedOption = null;
      _errorMessage = null;
    });
    
    try {
      final data = await _apiService.getSelfAssessmentQuestion(_sessionToken!);
      
      if (data['isCompleted'] == true) {
        setState(() {
          _isCompleted = true;
          _isLoading = false;
        });
        return;
      }
      
      setState(() {
        _questionId = data['questionId'];
        _currentQuestionIndex = data['questionIndex'] ?? 0;
        _totalQuestions = data['totalQuestions'] ?? _totalQuestions;
        _questionText = data['questionText'];
        _options = List<String>.from(data['options'] ?? []);
        _diagram = data['diagram'];
        _chapter = data['chapter'];
        _isLoading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.message;
      });
      if (e.statusCode == 403 || e.statusCode == 401) {
        _heartbeatTimer?.cancel();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load question. Please try again.';
      });
    }
  }
  
  Future<void> _submitAnswer() async {
    if (_sessionToken == null || _questionId == null || _selectedOption == null) return;
    if (!_isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Internet connection lost. Cannot submit answer.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    
    setState(() {
      _isSubmitting = true;
    });
    
    try {
      final data = await _apiService.submitSelfAssessmentAnswer(
        _sessionToken!,
        _questionId!,
        _selectedOption!,
      );
      
      _heartbeatTimer?.cancel(); // Restart heartbeat timer to avoid collision
      _startHeartbeats();
      
      if (data['isCompleted'] == true) {
        setState(() {
          _isCompleted = true;
          _results = Map<String, dynamic>.from(data['results'] ?? {});
          _isSubmitting = false;
        });
      } else {
        setState(() {
          _isSubmitting = false;
        });
        await _loadCurrentQuestion();
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Submission failed: ${e.message}'),
          backgroundColor: Colors.redAccent,
        ),
      );
      if (e.statusCode == 403 || e.statusCode == 401) {
        _handleSessionTerminated(e.message);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('An error occurred. Please try again.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themePrimary = isDark ? const Color(0xFF5D9BFF) : const Color(0xFF0051D5);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final secondaryTextColor = isDark ? Colors.white70 : const Color(0xFF75859D);
    
    final navigator = Navigator.of(context);
    return PopScope(
      canPop: _isCompleted || _errorMessage != null,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Exit Self Assessment?'),
            content: const Text(
              'Your progress will be lost and this attempt will count towards your daily limit of 5 assessments.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                child: const Text('Exit'),
              ),
            ],
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
                        ? [
                            const Color(0xFF090D1A),
                            const Color(0xFF020408),
                          ]
                        : [
                            const Color(0xFFF8FAFC),
                            const Color(0xFFF1F5F9),
                          ],
                  ),
                ),
              ),
            ),
            
            // Background glowing bubble
            Positioned(
              top: -80,
              right: -80,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: themePrimary.withValues(alpha: isDark ? 0.08 : 0.04),
                ),
              ),
            ),
            
            SafeArea(
              child: Column(
                children: [
                  // App Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor),
                          onPressed: () => Navigator.maybePop(context),
                        ),
                        Text(
                          'Self Assessment',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: textColor,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(width: 48), // Spacer to balance back button
                      ],
                    ),
                  ),
                  
                  // Main Body
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        if (_isLoading) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        
                        if (_errorMessage != null) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32.0),
                              child: GlassCard(
                                padding: const EdgeInsets.all(28),
                                color: isDark
                                    ? Colors.black.withValues(alpha: 0.4)
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
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          padding: const EdgeInsets.symmetric(vertical: 14),
                                        ),
                                        child: const Text(
                                          'Go Back',
                                          style: TextStyle(fontWeight: FontWeight.w900),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }
                        
                        if (_isCompleted) {
                          return _buildResultsView(textColor, secondaryTextColor, themePrimary, isDark);
                        }
                        
                        return _buildQuestionView(textColor, secondaryTextColor, themePrimary, isDark);
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
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.wifi_off_rounded,
                              color: Colors.amberAccent,
                              size: 54,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Connection Disconnected',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Self-assessments require an active server authority connection. Reconnect to resume.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white70,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 20),
                            const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
  
  Widget _buildQuestionView(Color textColor, Color secondaryTextColor, Color themePrimary, bool isDark) {
    final progress = (_currentQuestionIndex) / _totalQuestions;
    final displayIndex = _currentQuestionIndex + 1;
    
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Progress section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Question $displayIndex of $_totalQuestions',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: themePrimary,
                ),
              ),
              if (_chapter != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: themePrimary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(50),
                    border: Border.all(color: themePrimary.withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    _chapter!,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: themePrimary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: isDark ? Colors.white10 : Colors.black12,
              valueColor: AlwaysStoppedAnimation<Color>(themePrimary),
            ),
          ),
          const SizedBox(height: 28),
          
          // Question card
          GlassCard(
            color: isDark
                ? Colors.black.withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InlineMathText(
                  text: _questionText ?? '',
                  fontSize: 16,
                  color: textColor,
                ),
                if (_diagram != null && _diagram!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      _diagram!.startsWith('http')
                          ? _diagram!
                          : '${_apiService.baseUrl}$_diagram',
                      width: double.infinity,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Container(
                        padding: const EdgeInsets.all(16),
                        color: Colors.red.withValues(alpha: 0.1),
                        child: const Row(
                          children: [
                            Icon(Icons.broken_image_rounded, color: Colors.redAccent),
                            SizedBox(width: 8),
                            Text('Failed to load diagram image'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 28),
          
          // Options header
          Text(
            'Select Option',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: secondaryTextColor,
            ),
          ),
          const SizedBox(height: 12),
          
          // Options List
          ...List.generate(_options.length, (index) {
            final option = _options[index];
            final isSelected = _selectedOption == option;
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: BounceOnTap(
                onTap: () {
                  setState(() {
                    _selectedOption = option;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? themePrimary.withValues(alpha: 0.12)
                        : (isDark
                            ? Colors.black.withValues(alpha: 0.25)
                            : Colors.white.withValues(alpha: 0.7)),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? themePrimary
                          : (isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : const Color(0x1F000000)),
                      width: isSelected ? 1.5 : 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected
                              ? themePrimary
                              : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                          border: Border.all(
                            color: isSelected ? themePrimary : Colors.transparent,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            String.fromCharCode(65 + index), // A, B, C, D
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: isSelected ? Colors.white : secondaryTextColor,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: InlineMathText(
                          text: option,
                          fontSize: 14,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          
          const SizedBox(height: 32),
          
          // Submit button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _selectedOption == null || _isSubmitting ? null : _submitAnswer,
              style: ElevatedButton.styleFrom(
                backgroundColor: themePrimary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: themePrimary.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      displayIndex == _totalQuestions ? 'Finish Assessment' : 'Submit & Next',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildResultsView(Color textColor, Color secondaryTextColor, Color themePrimary, bool isDark) {
    final score = _results?['score'] ?? 0;
    final total = _results?['total'] ?? _totalQuestions;
    final percentage = _results?['percentage'] ?? 0.0;
    final analytics = _results?['analytics'] ?? {};
    final weakTopics = List<String>.from(analytics['weakTopics'] ?? []);
    
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          FadeInSlide(
            duration: const Duration(milliseconds: 600),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.green.withValues(alpha: 0.1),
              ),
              child: const Icon(
                Icons.check_circle_outline_rounded,
                color: Colors.green,
                size: 72,
              ),
            ),
          ),
          const SizedBox(height: 20),
          FadeInSlide(
            duration: const Duration(milliseconds: 600),
            delay: const Duration(milliseconds: 100),
            child: Text(
              'Assessment Complete',
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
              style: TextStyle(
                fontSize: 14,
                color: secondaryTextColor,
              ),
            ),
          ),
          const SizedBox(height: 32),
          
          // Scorecard Card
          FadeInSlide(
            duration: const Duration(milliseconds: 600),
            delay: const Duration(milliseconds: 200),
            child: GlassCard(
              padding: const EdgeInsets.all(28),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text(
                            '$score / $total',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Score Obtained',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: secondaryTextColor,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        width: 1,
                        height: 50,
                        color: textColor.withValues(alpha: 0.1),
                      ),
                      Column(
                        children: [
                          Text(
                            '${percentage.toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: percentage >= 50.0 ? Colors.green : Colors.orangeAccent,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Percentage',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: secondaryTextColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          
          // Weak areas section
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.orangeAccent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.orangeAccent.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lightbulb_outline_rounded, color: Colors.orangeAccent, size: 20),
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.green.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.star_rounded, color: Colors.green, size: 24),
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
                ),
                child: const Text(
                  'Back to Dashboard',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
