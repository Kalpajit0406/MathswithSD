import 'package:flutter/material.dart';
import '../../models/exam_model.dart';
import '../shared/latex_widget.dart';

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
    final double percentage = totalQuestions > 0 ? (score / totalQuestions) * 100 : 0;
    final bool passed = percentage >= 40;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F9FB),
        appBar: AppBar(
          backgroundColor: const Color(0xFF4A148C),
          title: const Text('Assessment Result', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
          elevation: 0,
          automaticallyImplyLeading: false,
          bottom: const TabBar(
            tabs: [
              Tab(text: 'SUMMARY', icon: Icon(Icons.analytics_outlined)),
              Tab(text: 'REVIEW', icon: Icon(Icons.fact_check_outlined)),
            ],
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            indicatorWeight: 4,
          ),
        ),
        body: TabBarView(
          children: [
            _buildSummary(context, percentage, passed),
            _buildReviewList(),
          ],
        ),
        bottomNavigationBar: _buildBottomBar(context),
      ),
    );
  }

  Widget _buildSummary(BuildContext context, double percentage, bool passed) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))],
            ),
            child: Column(
              children: [
                Icon(
                  passed ? Icons.emoji_events : Icons.sentiment_dissatisfied,
                  size: 80,
                  color: passed ? const Color(0xFFFFC107) : const Color(0xFFE53935),
                ),
                const SizedBox(height: 16),
                Text(
                  passed ? 'Congratulations!' : 'Keep Practicing!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: passed ? const Color(0xFF4CAF50) : const Color(0xFFE53935),
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _StatColumn(label: 'Score', value: '$score / $totalQuestions'),
                    _StatColumn(label: 'Accuracy', value: '${percentage.toStringAsFixed(1)}%'),
                    _StatColumn(
                      label: 'Time',
                      value: '${(timeTaken / 60).floor()}m ${timeTaken % 60}s',
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
                color: Colors.orange.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.offline_pin_rounded, color: Colors.orange, size: 24),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Exam completed offline! Your answers are saved locally and will automatically sync when you reconnect.',
                      style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 32),
          _buildInsightCard(),
        ],
      ),
    );
  }

  Widget _buildInsightCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF3E5F5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF4A148C).withOpacity(0.1)),
      ),
      child: const Row(
        children: [
          Icon(Icons.lightbulb_outline, color: Color(0xFF4A148C)),
          SizedBox(width: 16),
          Expanded(
            child: Text(
              'Switch to the Review tab to see correct solutions and explanations for all questions.',
              style: TextStyle(color: Color(0xFF4A148C), fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewList() {
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
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: const Color(0xFF4A148C).withOpacity(0.1),
                      child: Text('${index + 1}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF4A148C))),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      isUnanswered ? 'UNANSWERED' : (isCorrect ? 'CORRECT' : 'INCORRECT'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: isUnanswered ? Colors.orange : (isCorrect ? Colors.green : Colors.red),
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      isUnanswered ? Icons.help_outline : (isCorrect ? Icons.check_circle : Icons.cancel),
                      color: isUnanswered ? Colors.orange : (isCorrect ? Colors.green : Colors.red),
                      size: 20,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LaTeXWidget(text: q.questionText),
                    const SizedBox(height: 16),
                    _ReviewOption(label: 'Your Answer', value: userAns ?? 'Not Answered', isCorrect: isCorrect, color: isCorrect ? Colors.green : Colors.red),
                    if (!isCorrect)
                      const SizedBox(height: 8),
                    if (!isCorrect)
                      _ReviewOption(label: 'Correct Answer', value: q.correctAnswer ?? 'N/A', isCorrect: true, color: Colors.green),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -4))],
      ),
      child: ElevatedButton(
        onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil('/student', (_) => false),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4A148C),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: const Text('Back to Home', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );
  }
}

class _ReviewOption extends StatelessWidget {
  final String label;
  final String value;
  final bool isCorrect;
  final Color color;

  const _ReviewOption({required this.label, required this.value, required this.isCorrect, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          InlineMathText(text: value, fontSize: 14),
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String label;
  final String value;

  const _StatColumn({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF1A1A2E)),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
        ),
      ],
    );
  }
}
