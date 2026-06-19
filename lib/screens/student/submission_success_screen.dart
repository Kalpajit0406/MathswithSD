import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/exam_model.dart';
import '../../providers/exam_provider.dart';
import '../../services/network_time_service.dart';
import '../../widgets/glass_card.dart';
import 'result_screen.dart';

class SubmissionSuccessScreen extends StatefulWidget {
  final Exam exam;
  final String attemptId;
  final String endTimeStr;
  final int? initialRemainingSeconds;

  const SubmissionSuccessScreen({
    super.key,
    required this.exam,
    required this.attemptId,
    required this.endTimeStr,
    this.initialRemainingSeconds,
  });

  @override
  State<SubmissionSuccessScreen> createState() => _SubmissionSuccessScreenState();
}

class _SubmissionSuccessScreenState extends State<SubmissionSuccessScreen> {
  Timer? _timer;
  int _remainingSeconds = 0;
  bool _fetchingResult = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialRemainingSeconds != null) {
      _remainingSeconds = widget.initialRemainingSeconds!;
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            if (_remainingSeconds > 0) {
              _remainingSeconds--;
            } else {
              _timer?.cancel();
            }
          });
        }
      });
    } else {
      _calculateRemainingTime();
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          _calculateRemainingTime();
        }
      });
    }
  }

  void _calculateRemainingTime() {
    final now = NetworkTimeService().istNow;
    final examStart = widget.exam.getExamDateTime();
    if (examStart != null) {
      final examEnd = examStart.add(Duration(minutes: widget.exam.duration));
      final diff = examEnd.difference(now);
      if (diff.isNegative) {
        setState(() {
          _remainingSeconds = 0;
        });
        _timer?.cancel();
      } else {
        setState(() {
          _remainingSeconds = diff.inSeconds;
        });
      }
    } else {
      setState(() {
        _remainingSeconds = 0;
      });
      _timer?.cancel();
    }
  }

  String _formatDuration(int totalSeconds) {
    if (totalSeconds <= 0) return '';
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _handleViewResult() async {
    if (widget.attemptId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid attempt ID. Cannot fetch result.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _fetchingResult = true;
    });

    try {
      final examProvider = Provider.of<ExamProvider>(context, listen: false);
      final resultData = await examProvider.getResult(widget.attemptId);

      final userAnswers = <String, String>{};
      if (resultData['responses'] != null) {
        for (var resp in resultData['responses']) {
          final qId = resp['questionId']?.toString();
          final uAns = resp['userAnswer']?.toString() ?? resp['selectedAnswer']?.toString() ?? '';
          if (qId != null) {
            userAnswers[qId] = uAns;
          }
        }
      }

      final score = resultData['score'] is num ? (resultData['score'] as num).toInt() : 0;
      int timeTaken = 0;
      if (resultData['startTime'] != null && resultData['endTime'] != null) {
        try {
          final start = DateTime.parse(resultData['startTime']);
          final end = DateTime.parse(resultData['endTime']);
          timeTaken = end.difference(start).inSeconds;
        } catch (_) {}
      }
      if (timeTaken <= 0) {
        timeTaken = widget.exam.duration * 60;
      }

      final List<Question> resolvedQuestions = [];
      if (resultData['examId'] != null && resultData['examId']['questions'] != null) {
        final List qList = resultData['examId']['questions'] as List;
        for (var qJson in qList) {
          resolvedQuestions.add(Question.fromJson(Map<String, dynamic>.from(qJson)));
        }
      }
      final questionsToUse = resolvedQuestions.isNotEmpty ? resolvedQuestions : widget.exam.questions;

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ResultScreen(
              score: score,
              totalQuestions: questionsToUse.length,
              timeTaken: timeTaken,
              questions: questionsToUse,
              userAnswers: userAnswers,
              isOffline: false,
              evaluationSummary: resultData['evaluationSummary'],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load result: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _fetchingResult = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final secondaryTextColor = isDark ? Colors.white60 : Colors.black54;
    final themePrimary = isDark
        ? const Color(0xFF5D9BFF)
        : const Color(0xFF0051D5);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              GlassCard(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF10B981).withValues(alpha: 0.2),
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.check_circle_rounded,
                        size: 72,
                        color: Color(0xFF10B981),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Submission Successful!',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: textColor,
                        letterSpacing: -0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Your responses for "${widget.exam.title}" have been successfully submitted.',
                      style: TextStyle(
                        fontSize: 14,
                        color: secondaryTextColor,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: themePrimary.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: themePrimary.withValues(alpha: 0.15),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.schedule_rounded,
                            color: themePrimary,
                            size: 24,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Evaluation Deferred',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Since the exam is still in progress, answers cannot be viewed yet. You can check your marks and results after the exam ends at:',
                            style: TextStyle(
                              fontSize: 12,
                              color: secondaryTextColor,
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            widget.endTimeStr,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: themePrimary,
                            ),
                          ),
                          if (_remainingSeconds > 0) ...[
                            const SizedBox(height: 16),
                            Text(
                              'Remaining Time:',
                              style: TextStyle(
                                fontSize: 12,
                                color: secondaryTextColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatDuration(_remainingSeconds),
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: themePrimary,
                              ),
                            ),
                          ] else ...[
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.check_circle_outline,
                                  color: Colors.green,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Exam period has ended',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: _remainingSeconds > 0 || _fetchingResult ? null : _handleViewResult,
                style: ElevatedButton.styleFrom(
                  backgroundColor: themePrimary,
                  foregroundColor: isDark ? Colors.black : Colors.white,
                  disabledBackgroundColor: isDark ? Colors.grey[800] : Colors.grey[300],
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: _fetchingResult
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isDark ? Colors.black : Colors.white,
                          ),
                        ),
                      )
                    : Text(
                        _remainingSeconds > 0
                            ? 'Assessment Result (Available in ${_formatDuration(_remainingSeconds)})'
                            : 'View Assessment Result',
                        style: TextStyle(
                          color: _remainingSeconds > 0
                              ? (isDark ? Colors.white38 : Colors.black38)
                              : (isDark ? Colors.black : Colors.white),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => Navigator.of(context)
                    .pushNamedAndRemoveUntil('/student', (_) => false),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: themePrimary.withValues(alpha: 0.5), width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'Go to Dashboard',
                  style: TextStyle(
                    color: themePrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
