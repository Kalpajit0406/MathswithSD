import 'package:flutter/material.dart';
import '../../models/exam_model.dart';
import '../shared/latex_widget.dart';
import '../../widgets/glass_card.dart';

class ResultScreen extends StatelessWidget {
  final int score;
  final int totalQuestions;
  final int timeTaken;
  final List<Question> questions;
  final Map<String, String> userAnswers;
  final bool isOffline;

  const ResultScreen({
    super.key,
    required this.score,
    required this.totalQuestions,
    required this.timeTaken,
    required this.questions,
    required this.userAnswers,
    this.isOffline = false,
  });

  @override
  Widget build(BuildContext context) {
    final double percentage = totalQuestions > 0
        ? (score / totalQuestions) * 100
        : 0;
    final bool passed = percentage >= 40;
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
        body: TabBarView(
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
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _StatColumn(
                      label: 'Score',
                      value: '$score / $totalQuestions',
                      textColor: textColor,
                      secondaryTextColor: secondaryTextColor,
                    ),
                    _StatColumn(
                      label: 'Accuracy',
                      value: '${percentage.toStringAsFixed(1)}%',
                      textColor: textColor,
                      secondaryTextColor: secondaryTextColor,
                    ),
                    _StatColumn(
                      label: 'Time',
                      value: '${(timeTaken / 60).floor()}m ${timeTaken % 60}s',
                      textColor: textColor,
                      secondaryTextColor: secondaryTextColor,
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (isOffline) ...[
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
      itemCount: questions.length,
      itemBuilder: (context, index) {
        final q = questions[index];
        final userAns = userAnswers[q.id];
        final isCorrect = userAns == q.correctAnswer;
        final isUnanswered = userAns == null;

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
                        isUnanswered
                            ? 'UNANSWERED'
                            : (isCorrect ? 'CORRECT' : 'INCORRECT'),
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
                        value: userAns ?? 'Not Answered',
                        isCorrect: isCorrect,
                        color: isCorrect ? Colors.green : Colors.red,
                        textColor: textColor,
                      ),
                      if (!isCorrect) const SizedBox(height: 8),
                      if (!isCorrect)
                        _ReviewOption(
                          label: 'Correct Answer',
                          value: q.correctAnswer ?? 'N/A',
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
