import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/exam_provider.dart';
import '../../widgets/animations.dart';
import '../../widgets/glass_card.dart';

class PerformanceScreen extends StatefulWidget {
  const PerformanceScreen({super.key});

  @override
  State<PerformanceScreen> createState() => _PerformanceScreenState();
}

class _PerformanceScreenState extends State<PerformanceScreen> {
  late Future<Map<String, dynamic>?> _performanceFuture;

  @override
  void initState() {
    super.initState();
    _loadPerformance();
  }

  void _loadPerformance() {
    _performanceFuture = Provider.of<ExamProvider>(
      context,
      listen: false,
    ).fetchStudentPerformance();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final secondaryTextColor = isDark ? Colors.white60 : Colors.black54;
    final themePrimary = isDark
        ? const Color(0xFF5D9BFF)
        : const Color(0xFF0051D5);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'My Performance',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w900,
            fontSize: 22,
            letterSpacing: -0.5,
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: textColor,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: textColor,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: textColor),
            onPressed: () {
              setState(_loadPerformance);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Performance data refreshed'),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: themePrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<Map<String, dynamic>?>(
          future: _performanceFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: CircularProgressIndicator(color: themePrimary),
              );
            }

            if (snapshot.hasError || snapshot.data == null) {
              return _buildErrorState(
                () => setState(_loadPerformance),
                textColor,
                secondaryTextColor,
                themePrimary,
                isDark,
              );
            }

            final data = snapshot.data!;
            return _buildPerformanceContent(
              data,
              auth,
              textColor,
              secondaryTextColor,
              themePrimary,
              isDark,
            );
          },
        ),
      ),
    );
  }

  Widget _buildErrorState(
    VoidCallback onRetry,
    Color textColor,
    Color secondaryTextColor,
    Color themePrimary,
    bool isDark,
  ) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: themePrimary.withValues(alpha: 0.04),
              shape: BoxShape.circle,
              border: Border.all(color: themePrimary.withValues(alpha: 0.08)),
            ),
            child: Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: secondaryTextColor,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Could not load performance data',
            style: TextStyle(
              color: textColor,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please check your connection and try again',
            style: TextStyle(color: secondaryTextColor, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: themePrimary,
              foregroundColor: isDark ? Colors.black : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceContent(
    Map<String, dynamic> data,
    AuthProvider auth,
    Color textColor,
    Color secondaryTextColor,
    Color themePrimary,
    bool isDark,
  ) {
    final totalAttempts = data['totalAttempts'] ?? 0;
    final completionRate = data['completionRate'] ?? 0.0;
    final accuracyRate = data['accuracyRate'] ?? 0.0;
    final improvementTrend = data['improvementTrend'] ?? 0.0;
    final performanceByChapter = data['performanceByChapter'] ?? {};
    final recentAttempts = data['recentAttempts'] ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome card
          FadeInSlide(
            duration: const Duration(milliseconds: 700),
            child: GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hello, ${auth.user?.firstName ?? "Student"}! 👋',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Here's your learning journey so far",
                    style: TextStyle(
                      color: secondaryTextColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Key metrics grid
          FadeInSlide(
            duration: const Duration(milliseconds: 700),
            delay: const Duration(milliseconds: 100),
            child: _MetricsGrid(
              totalAttempts: totalAttempts,
              completionRate: completionRate,
              accuracyRate: accuracyRate,
              improvementTrend: improvementTrend,
              textColor: textColor,
              secondaryTextColor: secondaryTextColor,
            ),
          ),
          const SizedBox(height: 32),

          // Performance trend indicator
          if (improvementTrend != 0)
            FadeInSlide(
              duration: const Duration(milliseconds: 700),
              delay: const Duration(milliseconds: 150),
              child: _TrendIndicator(
                trend: improvementTrend,
                textColor: textColor,
                secondaryTextColor: secondaryTextColor,
              ),
            ),
          const SizedBox(height: 32),

          // Chapter-wise performance
          if (performanceByChapter.isNotEmpty) ...[
            FadeInSlide(
              duration: const Duration(milliseconds: 700),
              delay: const Duration(milliseconds: 200),
              child: Text(
                'Chapter-wise Performance',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: textColor,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const SizedBox(height: 16),
            ..._buildChapterPerformance(
              performanceByChapter,
              textColor,
              secondaryTextColor,
            ),
            const SizedBox(height: 32),
          ],

          // Recent attempts
          if (recentAttempts.isNotEmpty) ...[
            FadeInSlide(
              duration: const Duration(milliseconds: 700),
              delay: const Duration(milliseconds: 250),
              child: Text(
                'Recent Attempts',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: textColor,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const SizedBox(height: 16),
            ..._buildRecentAttempts(
              recentAttempts,
              textColor,
              secondaryTextColor,
            ),
          ] else if (totalAttempts == 0)
            FadeInSlide(
              duration: const Duration(milliseconds: 700),
              delay: const Duration(milliseconds: 250),
              child: GlassCard(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: themePrimary.withValues(alpha: 0.04),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.assignment_outlined,
                        size: 56,
                        color: secondaryTextColor.withValues(alpha: 0.4),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No attempts yet',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Start your first test to see your performance metrics',
                      style: TextStyle(fontSize: 13, color: secondaryTextColor),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildChapterPerformance(
    Map<String, dynamic> chapters,
    Color textColor,
    Color secondaryTextColor,
  ) {
    return chapters.entries.map((entry) {
      final chapterName = entry.key;
      final metrics = entry.value as Map<String, dynamic>? ?? {};
      final accuracy = (metrics['accuracy'] ?? 0.0) as num;
      final attemptCount = metrics['attempts'] ?? 0;

      return FadeInSlide(
        duration: const Duration(milliseconds: 600),
        delay: const Duration(milliseconds: 100),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        chapterName,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$attemptCount attempts',
                        style: TextStyle(
                          fontSize: 12,
                          color: secondaryTextColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildAccuracyBadge(accuracy.toDouble()),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }

  List<Widget> _buildRecentAttempts(
    List<dynamic> attempts,
    Color textColor,
    Color secondaryTextColor,
  ) {
    return attempts.take(5).map((attempt) {
      final attemptData = attempt as Map<String, dynamic>;
      final examTitle = attemptData['examTitle'] ?? 'Test';
      final score = attemptData['score'] ?? 0;
      final maxScore = attemptData['maxScore'] ?? 100;
      final percentage = maxScore > 0
          ? (score / maxScore * 100).toStringAsFixed(1)
          : '0.0';
      final date = attemptData['date'] ?? '';

      return FadeInSlide(
        duration: const Duration(milliseconds: 600),
        delay: const Duration(milliseconds: 100),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        examTitle,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        date,
                        style: TextStyle(
                          fontSize: 12,
                          color: secondaryTextColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$percentage%',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: textColor,
                      ),
                    ),
                    Text(
                      '$score/$maxScore',
                      style: TextStyle(
                        fontSize: 12,
                        color: secondaryTextColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildAccuracyBadge(double accuracy) {
    Color badgeColor;
    if (accuracy >= 80) {
      badgeColor = const Color(0xFF10B981);
    } else if (accuracy >= 60) {
      badgeColor = const Color(0xFFFBBF24);
    } else {
      badgeColor = const Color(0xFFEF4444);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: badgeColor.withValues(alpha: 0.2), width: 1),
      ),
      child: Text(
        '${accuracy.toStringAsFixed(1)}%',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 14,
          color: badgeColor,
        ),
      ),
    );
  }
}

class _MetricsGrid extends StatelessWidget {
  final int totalAttempts;
  final double completionRate;
  final double accuracyRate;
  final double improvementTrend;
  final Color textColor;
  final Color secondaryTextColor;

  const _MetricsGrid({
    required this.totalAttempts,
    required this.completionRate,
    required this.accuracyRate,
    required this.improvementTrend,
    required this.textColor,
    required this.secondaryTextColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                title: 'Total Attempts',
                value: totalAttempts.toString(),
                icon: Icons.assignment_rounded,
                color: const Color(0xFF3B82F6),
                textColor: textColor,
                secondaryTextColor: secondaryTextColor,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _MetricCard(
                title: 'Completion Rate',
                value: '${completionRate.toStringAsFixed(1)}%',
                icon: Icons.check_circle_outline_rounded,
                color: const Color(0xFF10B981),
                textColor: textColor,
                secondaryTextColor: secondaryTextColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                title: 'Accuracy Rate',
                value: '${accuracyRate.toStringAsFixed(1)}%',
                icon: Icons.trending_up_rounded,
                color: const Color(0xFF0051D5),
                textColor: textColor,
                secondaryTextColor: secondaryTextColor,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _MetricCard(
                title: 'Improvement',
                value:
                    '${improvementTrend > 0 ? '+' : ''}${improvementTrend.toStringAsFixed(1)}%',
                icon: improvementTrend >= 0
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
                color: improvementTrend >= 0
                    ? const Color(0xFF10B981)
                    : const Color(0xFFEF4444),
                textColor: textColor,
                secondaryTextColor: secondaryTextColor,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final Color textColor;
  final Color secondaryTextColor;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.textColor,
    required this.secondaryTextColor,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: color.withValues(alpha: 0.2),
                width: 1.2,
              ),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 24,
              color: textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: secondaryTextColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendIndicator extends StatelessWidget {
  final double trend;
  final Color textColor;
  final Color secondaryTextColor;

  const _TrendIndicator({
    required this.trend,
    required this.textColor,
    required this.secondaryTextColor,
  });

  @override
  Widget build(BuildContext context) {
    final isPositive = trend >= 0;
    final trendColor = isPositive
        ? const Color(0xFF10B981)
        : const Color(0xFFEF4444);
    final trendIcon = isPositive
        ? Icons.trending_up_rounded
        : Icons.trending_down_rounded;

    return GlassCard(
      color: trendColor.withValues(alpha: 0.08),
      border: Border.all(color: trendColor.withValues(alpha: 0.2), width: 1.2),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: trendColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: trendColor.withValues(alpha: 0.2),
                width: 1.2,
              ),
            ),
            child: Icon(trendIcon, color: trendColor, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isPositive ? "You're Improving! 🚀" : 'Keep Trying! 💪',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: trendColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isPositive
                      ? 'Your accuracy has improved by ${trend.toStringAsFixed(1)}% from your average'
                      : 'Your accuracy declined by ${(-trend).toStringAsFixed(1)}% - review challenging topics',
                  style: TextStyle(
                    fontSize: 13,
                    color: isPositive
                        ? trendColor.withValues(alpha: 0.9)
                        : textColor.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
