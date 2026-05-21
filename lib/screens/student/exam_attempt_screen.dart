import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../providers/auth_provider.dart';
import '../../providers/exam_provider.dart';
import '../../models/exam_model.dart';
import '../shared/latex_widget.dart';
import 'result_screen.dart';
import '../../services/connectivity_manager.dart';
import '../../services/offline_exam_service.dart';

class ExamAttemptScreen extends StatefulWidget {
  final Exam exam;

  const ExamAttemptScreen({super.key, required this.exam});

  @override
  State<ExamAttemptScreen> createState() => _ExamAttemptScreenState();
}

class _ExamAttemptScreenState extends State<ExamAttemptScreen> with WidgetsBindingObserver {
  int _violations = 0;
  bool _isSubmitted = false;
  bool _isInitializing = true;
  String? _initError;

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
        final offlineExam = await OfflineExamService().getOfflineExam(widget.exam.id);
        if (offlineExam != null) {
          if (offlineExam.isCompleted) {
            throw Exception('This exam has already been completed offline.');
          }
          final elapsed = DateTime.now().difference(offlineExam.startedAt).inSeconds;
          final remaining = (offlineExam.duration * 60) - elapsed;
          if (remaining <= 0) {
            await OfflineExamService().completeOfflineExam(widget.exam.id);
            throw Exception('Time limit for this exam has expired.');
          }
          await provider.startExamOffline(widget.exam.id, remaining);
        } else {
          final newOfflineExam = OfflineExam(
            examId: widget.exam.id,
            title: widget.exam.title,
            duration: widget.exam.duration,
            questions: widget.exam.questions.map((q) => q.toJson()).toList(),
            startedAt: DateTime.now(),
            isCompleted: false,
            status: 'started',
          );
          await OfflineExamService().saveExamOffline(newOfflineExam);
          await provider.startExamOffline(widget.exam.id, widget.exam.duration * 60);
        }
      } else {
        final cached = await provider.checkForResumableExam();
        if (cached != null && cached['examId'] == widget.exam.id) {
          await provider.resumeExam(cached);
        } else {
          await provider.startExam(widget.exam.id);
        }
      }
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _initError = e.toString();
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isSubmitted || _isInitializing || _initError != null) return;
    
    // Security check: if app goes to background (user switched apps or opened split screen)
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _violations++;
      if (_violations >= 2) {
        // Auto submit
        _autoSubmitExam('Multiple security violations detected. Exam auto-submitted.');
      } else {
        _showViolationWarning();
      }
    }
  }

  void _showViolationWarning() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('Security Warning'),
          ],
        ),
        content: const Text('Please do not switch apps during the exam. One more violation will result in automatic submission.'),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('I Understand', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _autoSubmitExam(String reason) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(reason), backgroundColor: Colors.red));
    await _submit();
  }

  Future<void> _submit() async {
    final examProvider = Provider.of<ExamProvider>(context, listen: false);
    if (_isSubmitted || examProvider.isLoading) return;
    _isSubmitted = true;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // Build answer array
    List<Map<String, dynamic>> finalAnswers = [];
    int score = 0;

    for (var q in widget.exam.questions) {
      String? userAns = examProvider.userAnswers[q.id];
      if (userAns != null && userAns == q.correctAnswer) {
        score++;
      }
      finalAnswers.add({
        'questionId': q.id,
        'answer': userAns,
      });
    }

    final isOffline = !ConnectivityManager().isOnline || (examProvider.currentAttemptId?.startsWith('offline_') ?? false);

    try {
      await examProvider.submitExam(finalAnswers, isOffline: isOffline);
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ResultScreen(
              score: score,
              totalQuestions: widget.exam.questions.length,
              timeTaken: (widget.exam.duration * 60) - examProvider.remainingSeconds,
              questions: widget.exam.questions,
              userAnswers: examProvider.userAnswers,
              isOffline: isOffline,
            ),
          ),
        );
      }
    } catch (e) {
      _isSubmitted = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _formatTime(int seconds) {
    int m = seconds ~/ 60;
    int s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return Scaffold(
        backgroundColor: const Color(0xFFF7F9FB),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Color(0xFF4A148C)),
              const SizedBox(height: 20),
              Text(
                'Securing examination environment...',
                style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    if (_initError != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF7F9FB),
        appBar: AppBar(
          backgroundColor: const Color(0xFF4A148C),
          title: const Text('Exam Initialization Error'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded, size: 64, color: Colors.red),
                const SizedBox(height: 20),
                Text(
                  'Initialization Failed',
                  style: TextStyle(color: Colors.grey.shade900, fontWeight: FontWeight.bold, fontSize: 20),
                ),
                const SizedBox(height: 12),
                Text(
                  _initError!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A148C),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Go Back', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final examProvider = Provider.of<ExamProvider>(context);
    if (examProvider.isLoading || _isSubmitted) {
      return Scaffold(
        backgroundColor: const Color(0xFFF7F9FB),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Color(0xFF4A148C)),
              const SizedBox(height: 20),
              const Text(
                'Submitting your answers securely...',
                style: TextStyle(color: Color(0xFF4A148C), fontWeight: FontWeight.w600, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }
    final totalQ = widget.exam.questions.length;
    final currentQIndex = examProvider.currentQuestionIndex;
    final currentQ = widget.exam.questions[currentQIndex];

    // Check if time is up
    if (examProvider.remainingSeconds == 0 && !_isSubmitted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _autoSubmitExam('Time is up! Exam auto-submitted.');
      });
    }

    return PopScope(
      canPop: false, // Disable back button
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: const Color(0xFF4A148C),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Q ${currentQIndex + 1}/$totalQ', style: const TextStyle(color: Colors.white, fontSize: 18)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: examProvider.remainingSeconds < 60 ? Colors.red : Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.timer, color: Colors.white, size: 18),
                    const SizedBox(width: 4),
                    Text(
                      _formatTime(examProvider.remainingSeconds),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Submit Exam?'),
                    content: const Text('Are you sure you want to submit your answers? You cannot change them later.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _submit();
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4A148C)),
                        child: const Text('Submit', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                );
              },
              child: const Text('FINISH', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        body: Column(
          children: [
            if (!ConnectivityManager().isOnline)
              Container(
                width: double.infinity,
                color: Colors.orange.shade800,
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.wifi_off_rounded, color: Colors.white, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'OFFLINE MODE — Attempt is being saved locally',
                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    ),
                  ],
                ),
              ),
            // Question Palette (Horizontal list of question numbers)
            Container(
              height: 60,
              color: Colors.white,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                itemCount: totalQ,
                itemBuilder: (context, i) {
                  bool isAnswered = examProvider.userAnswers.containsKey(widget.exam.questions[i].id);
                  bool isCurrent = i == currentQIndex;
                  return GestureDetector(
                    onTap: () {
                      // We don't have a direct jump method in provider, so we'll just ignore for now,
                      // or we could add a jumpToQuestion method. But navigation via next/prev is fine.
                    },
                    child: Container(
                      width: 40,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? const Color(0xFF4A148C)
                            : isAnswered
                                ? const Color(0xFF4CAF50)
                                : Colors.grey.shade300,
                        shape: BoxShape.circle,
                        border: isCurrent ? Border.all(color: const Color(0xFF9C27B0), width: 2) : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(
                          color: (isCurrent || isAnswered) ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const Divider(height: 1),

            // Question Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Question text
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: LaTeXWidget(text: currentQ.questionText),
                    ),
                    const SizedBox(height: 24),

                    // Options
                    if (currentQ.options != null)
                      ...currentQ.options!.map((opt) {
                        bool isSelected = examProvider.userAnswers[currentQ.id] == opt;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: InkWell(
                            onTap: () => examProvider.setAnswer(currentQ.id, opt),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFFF3E5F5) : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected ? const Color(0xFF9C27B0) : Colors.grey.shade300,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                                    color: isSelected ? const Color(0xFF9C27B0) : Colors.grey,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(child: InlineMathText(text: opt, fontSize: 16)),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),

            // Navigation Buttons
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -4)),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: currentQIndex > 0 ? () => examProvider.previousQuestion() : null,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('PREVIOUS'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: currentQIndex < totalQ - 1 ? () => examProvider.nextQuestion(totalQ) : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4A148C),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('NEXT', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
