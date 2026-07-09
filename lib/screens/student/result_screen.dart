import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../models/exam_model.dart';
import '../shared/latex_widget.dart';
import '../../widgets/glass_card.dart';

class ResultScreen extends StatefulWidget {
  final int score;
  final int totalQuestions;
  final int timeTaken;
  final List<Question> questions;
  final Map<String, String> userAnswers;
  final bool isOffline;
  final Map<String, dynamic>? evaluationSummary;

  const ResultScreen({
    super.key,
    required this.score,
    required this.totalQuestions,
    required this.timeTaken,
    required this.questions,
    required this.userAnswers,
    this.isOffline = false,
    this.evaluationSummary,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  int totalQuestions = 0;
  int totalAttempted = 0;
  int totalCorrect = 0;
  int totalIncorrect = 0;
  int totalUnattempted = 0;
  double accuracy = 0.0;

  bool isAttempted(String? answer) {
    if (answer == null) return false;
    final clean = answer.trim();
    return clean.isNotEmpty && clean.toLowerCase() != 'null';
  }

  bool isAnswersMatch(String? qAns, String? uAns) {
    if (qAns == null || uAns == null) return false;
    return qAns.trim().toLowerCase() == uAns.trim().toLowerCase();
  }

  void _calculateMetrics() {
    if (widget.evaluationSummary != null) {
      final summary = widget.evaluationSummary!;
      totalQuestions = (summary['totalQuestions'] as num?)?.toInt() ?? widget.totalQuestions;
      totalAttempted = (summary['attemptedQuestions'] as num?)?.toInt() ?? 0;
      totalCorrect = (summary['correctQuestions'] as num?)?.toInt() ?? 0;
      totalIncorrect = (summary['incorrectQuestions'] as num?)?.toInt() ?? 0;
      totalUnattempted = (summary['unattemptedQuestions'] as num?)?.toInt() ?? 0;
      accuracy = (summary['accuracyPercent'] as num?)?.toDouble() ?? 0.0;
      return;
    }

    totalQuestions = widget.questions.length;
    totalAttempted = 0;
    totalCorrect = 0;
    totalIncorrect = 0;
    totalUnattempted = 0;

    for (var q in widget.questions) {
      final userAns = widget.userAnswers[q.id];
      if (isAttempted(userAns)) {
        totalAttempted++;
        if (isAnswersMatch(q.correctAnswer, userAns)) {
          totalCorrect++;
        } else {
          totalIncorrect++;
        }
      } else {
        totalUnattempted++;
      }
    }

    accuracy = totalQuestions > 0
        ? (totalCorrect / totalQuestions) * 100
        : 0.0;
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 25),
    )..repeat();
    _calculateMetrics();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double percentage = accuracy;
    final double scorePercentage = totalQuestions > 0
        ? (totalCorrect / totalQuestions) * 100
        : 0;
    final bool passed = scorePercentage >= 40;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final secondaryTextColor = isDark ? Colors.white60 : Colors.black54;
    final themePrimary = isDark
        ? const Color(0xFF5D9BFF)
        : const Color(0xFF0051D5);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: textColor,
          title: Text(
            'Assessment Result',
            style: TextStyle(color: textColor, fontWeight: FontWeight.w900),
          ),
          elevation: 0,
          automaticallyImplyLeading: false,
          bottom: TabBar(
            tabs: const [
              Tab(text: 'SUMMARY', icon: Icon(Icons.analytics_outlined)),
              Tab(text: 'REVIEW', icon: Icon(Icons.fact_check_outlined)),
            ],
            labelColor: textColor,
            unselectedLabelColor: secondaryTextColor,
            indicatorColor: themePrimary,
            indicatorWeight: 3,
          ),
        ),
        body: Stack(
          children: [
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
                              ? const Color(0xFF0051D5).withValues(alpha: 0.16)
                              : const Color(0xFF0051D5).withValues(alpha: 0.08),
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
                              ? const Color(0xFFF97316).withValues(alpha: 0.12)
                              : const Color(0xFFF97316).withValues(alpha: 0.06),
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
                            color: const Color(0xFFD946EF).withValues(alpha: 0.09),
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
            TabBarView(
              children: [
                _buildSummary(context, percentage, passed),
                _buildReviewList(
                  textColor,
                  secondaryTextColor,
                  themePrimary,
                  isDark,
                ),
              ],
            ),
          ],
        ),
        bottomNavigationBar: _buildBottomBar(context, themePrimary, isDark),
      ),
    );
  }

  Widget _buildSummary(BuildContext context, double percentage, bool passed) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final secondaryTextColor = isDark ? Colors.white60 : Colors.black54;
    final themePrimary = isDark
        ? const Color(0xFF5D9BFF)
        : const Color(0xFF0051D5);
    final double attemptedAccuracy = widget.evaluationSummary != null
        ? (widget.evaluationSummary!['attemptedAccuracyPercent'] as num?)?.toDouble() ?? 0.0
        : (totalAttempted > 0 ? (totalCorrect / totalAttempted) * 100 : 0.0);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          GlassCard(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                Icon(
                  passed ? Icons.emoji_events : Icons.sentiment_dissatisfied,
                  size: 80,
                  color: passed
                      ? const Color(0xFFFFC107)
                      : const Color(0xFFE53935),
                ),
                const SizedBox(height: 16),
                Text(
                  passed ? 'Congratulations!' : 'Keep Practicing!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: passed
                        ? const Color(0xFF10B981)
                        : const Color(0xFFE53935),
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: _StatColumn(
                        label: 'Score',
                        value: '$totalCorrect / $totalQuestions',
                        textColor: textColor,
                        secondaryTextColor: secondaryTextColor,
                      ),
                    ),
                    Container(
                      height: 36,
                      width: 1,
                      color: textColor.withValues(alpha: 0.12),
                    ),
                    Expanded(
                      child: _StatColumn(
                        label: 'Accuracy',
                        value: '${percentage.toStringAsFixed(1)}%',
                        textColor: textColor,
                        secondaryTextColor: secondaryTextColor,
                      ),
                    ),
                    Container(
                      height: 36,
                      width: 1,
                      color: textColor.withValues(alpha: 0.12),
                    ),
                    Expanded(
                      child: _StatColumn(
                        label: 'Attempted Accuracy',
                        value: '${attemptedAccuracy.toStringAsFixed(1)}%',
                        textColor: textColor,
                        secondaryTextColor: secondaryTextColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      color: themePrimary.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: themePrimary.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.timer_outlined,
                          size: 16,
                          color: themePrimary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Time: ${(widget.timeTaken / 60).floor()}m ${widget.timeTaken % 60}s',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Divider(color: textColor.withValues(alpha: 0.1)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _StatColumn(
                      label: 'Attempted',
                      value: '$totalAttempted',
                      textColor: textColor,
                      secondaryTextColor: secondaryTextColor,
                    ),
                    _StatColumn(
                      label: 'Correct',
                      value: '$totalCorrect',
                      textColor: Colors.green,
                      secondaryTextColor: secondaryTextColor,
                    ),
                    _StatColumn(
                      label: 'Incorrect',
                      value: '$totalIncorrect',
                      textColor: Colors.red,
                      secondaryTextColor: secondaryTextColor,
                    ),
                    _StatColumn(
                      label: 'Unattempted',
                      value: '$totalUnattempted',
                      textColor: Colors.orange,
                      secondaryTextColor: secondaryTextColor,
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (widget.isOffline) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: themePrimary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: themePrimary.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.offline_pin_rounded,
                    color: themePrimary,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Exam completed offline! Your answers are saved locally and will automatically sync when you reconnect.',
                      style: TextStyle(
                        color: themePrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 32),
          _buildInsightCard(textColor, isDark),
        ],
      ),
    );
  }

  Widget _buildInsightCard(Color textColor, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF080C14)
            : const Color(0xFFECEEF0).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFFECEEF0),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.lightbulb_outline, color: textColor),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'Switch to the Review tab to see correct solutions and explanations for all questions.',
              style: TextStyle(color: textColor, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewList(
    Color textColor,
    Color secondaryTextColor,
    Color themePrimary,
    bool isDark,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: widget.questions.length,
      itemBuilder: (context, index) {
        final q = widget.questions[index];
        final userAns = widget.userAnswers[q.id];
        final attempted = isAttempted(userAns);
        
        bool isCorrect = false;
        bool isUnanswered = true;
        String statusStr = 'UNATTEMPTED';

        if (widget.evaluationSummary != null && widget.evaluationSummary!['questions'] != null) {
          final evalQs = widget.evaluationSummary!['questions'] as List;
          Map<String, dynamic>? evalQ;
          for (var item in evalQs) {
            if (item is Map && item['questionId'] == q.id) {
              evalQ = Map<String, dynamic>.from(item);
              break;
            }
          }
          if (evalQ != null) {
            statusStr = evalQ['status'] ?? 'UNATTEMPTED';
            isCorrect = statusStr == 'CORRECT';
            isUnanswered = statusStr == 'UNATTEMPTED';
          } else {
            isCorrect = attempted && isAnswersMatch(q.correctAnswer, userAns);
            isUnanswered = !attempted;
            statusStr = isUnanswered ? 'UNATTEMPTED' : (isCorrect ? 'CORRECT' : 'INCORRECT');
          }
        } else {
          isCorrect = attempted && isAnswersMatch(q.correctAnswer, userAns);
          isUnanswered = !attempted;
          statusStr = isUnanswered ? 'UNATTEMPTED' : (isCorrect ? 'CORRECT' : 'INCORRECT');
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          child: GlassCard(
            padding: const EdgeInsets.all(0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: themePrimary.withValues(alpha: 0.08),
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
                        statusStr,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: isUnanswered
                              ? Colors.orange
                              : (isCorrect ? Colors.green : Colors.red),
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        isUnanswered
                            ? Icons.help_outline
                            : (isCorrect ? Icons.check_circle : Icons.cancel),
                        color: isUnanswered
                            ? Colors.orange
                            : (isCorrect ? Colors.green : Colors.red),
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
                      LaTeXWidget(text: q.questionText, color: textColor),
                      const SizedBox(height: 16),
                      _ReviewOption(
                        label: 'Your Answer',
                        value: attempted ? (userAns ?? '—') : '—',
                        isCorrect: isCorrect,
                        color: isUnanswered
                            ? Colors.orange
                            : (isCorrect ? Colors.green : Colors.red),
                        textColor: textColor,
                      ),
                      if (!isCorrect) const SizedBox(height: 8),
                      if (!isCorrect)
                        _ReviewOption(
                          label: 'Correct Answer',
                          value: q.correctAnswer ?? '—',
                          isCorrect: true,
                          color: Colors.green,
                          textColor: textColor,
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

  Widget _buildBottomBar(
    BuildContext context,
    Color themePrimary,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF020205) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : const Color(0xFFECEEF0),
            width: 1,
          ),
        ),
      ),
      child: ElevatedButton(
        onPressed: () => Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/student', (_) => false),
        style: ElevatedButton.styleFrom(
          backgroundColor: themePrimary,
          foregroundColor: isDark ? Colors.black : Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: Text(
          'Back to Home',
          style: TextStyle(
            color: isDark ? Colors.black : Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}

class _ReviewOption extends StatelessWidget {
  final String label;
  final String value;
  final bool isCorrect;
  final Color color;
  final Color textColor;

  const _ReviewOption({
    required this.label,
    required this.value,
    required this.isCorrect,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
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
}

class _StatColumn extends StatelessWidget {
  final String label;
  final String value;
  final Color textColor;
  final Color secondaryTextColor;

  const _StatColumn({
    required this.label,
    required this.value,
    required this.textColor,
    required this.secondaryTextColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: textColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: secondaryTextColor,
          ),
        ),
      ],
    );
  }
}
