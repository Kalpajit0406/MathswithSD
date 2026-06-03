import 'package:flutter/material.dart';
import '../../widgets/glass_card.dart';

class SubmissionSuccessScreen extends StatelessWidget {
  final String examTitle;
  final String endTimeStr;

  const SubmissionSuccessScreen({
    super.key,
    required this.examTitle,
    required this.endTimeStr,
  });

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
                      'Your responses for "$examTitle" have been successfully submitted.',
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
                            endTimeStr,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: themePrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: () => Navigator.of(context)
                    .pushNamedAndRemoveUntil('/student', (_) => false),
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
            ],
          ),
        ),
      ),
    );
  }
}
