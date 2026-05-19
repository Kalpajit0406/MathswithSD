import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/exam_provider.dart';
import '../../utils/constants.dart';
import '../../widgets/animations.dart';

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
    _performanceFuture = Provider.of<ExamProvider>(context, listen: false).fetchStudentPerformance();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFF4A148C),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'My Performance',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: () {
              setState(_loadPerformance);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Performance data refreshed'),
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _performanceFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF4A148C)));
          }

          if (snapshot.hasError || snapshot.data == null) {
            return _buildErrorState(() => setState(_loadPerformance));
          }

          final data = snapshot.data!;
          return _buildPerformanceContent(data, auth);
        },
      ),
    );
  }

  Widget _buildErrorState(VoidCallback onRetry) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFBA1A1A).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.error_outline, size: 64, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 20),
          const Text(
            'Could not load performance data',
            style: TextStyle(color: Color(0xFF75859D), fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Please check your connection and try again',
            style: TextStyle(color: Color(0xFF75859D), fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A148C),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceContent(Map<String, dynamic> data, AuthProvider auth) {
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
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF9C27B0), Color(0xFF4A148C)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF9C27B0).withOpacity(0.25),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hello, ${auth.user?.phone ?? "Student"}! 👋',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Here\'s your learning journey so far',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 14,
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
            ),
          ),
          const SizedBox(height: 32),

          // Performance trend indicator
          if (improvementTrend != 0)
            FadeInSlide(
              duration: const Duration(milliseconds: 700),
              delay: const Duration(milliseconds: 150),
              child: _TrendIndicator(trend: improvementTrend),
            ),
          const SizedBox(height: 32),

          // Chapter-wise performance
          if (performanceByChapter.isNotEmpty) ...[
            FadeInSlide(
              duration: const Duration(milliseconds: 700),
              delay: const Duration(milliseconds: 200),
              child: const Text(
                'Chapter-wise Performance',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const SizedBox(height: 16),
            ..._buildChapterPerformance(performanceByChapter),
            const SizedBox(height: 32),
          ],

          // Recent attempts
          if (recentAttempts.isNotEmpty) ...[
            FadeInSlide(
              duration: const Duration(milliseconds: 700),
              delay: const Duration(milliseconds: 250),
              child: const Text(
                'Recent Attempts',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const SizedBox(height: 16),
            ..._buildRecentAttempts(recentAttempts),
          ] else if (totalAttempts == 0)
            FadeInSlide(
              duration: const Duration(milliseconds: 700),
              delay: const Duration(milliseconds: 250),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFECEEF0), width: 1),
                ),
                child: Column(
                  children: [
                    Icon(Icons.assignment_outlined, size: 56, color: Colors.grey.shade300),
                    const SizedBox(height: 12),
                    const Text(
                      'No attempts yet',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Start your first test to see your performance metrics',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF75859D),
                      ),
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

  List<Widget> _buildChapterPerformance(Map<String, dynamic> chapters) {
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
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFECEEF0), width: 1),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      chapterName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$attemptCount attempts',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF75859D),
                      ),
                    ),
                  ],
                ),
              ),
              _buildAccuracyBadge(accuracy.toDouble()),
            ],
          ),
        ),
      );
    }).toList();
  }

  List<Widget> _buildRecentAttempts(List<dynamic> attempts) {
    return attempts.take(5).map((attempt) {
      final attemptData = attempt as Map<String, dynamic>;
      final examTitle = attemptData['examTitle'] ?? 'Test';
      final score = attemptData['score'] ?? 0;
      final maxScore = attemptData['maxScore'] ?? 100;
      final percentage = maxScore > 0 ? (score / maxScore * 100).toStringAsFixed(1) : '0.0';
      final date = attemptData['date'] ?? '';

      return FadeInSlide(
        duration: const Duration(milliseconds: 600),
        delay: const Duration(milliseconds: 100),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFECEEF0), width: 1),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      examTitle,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      date,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF75859D),
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
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: Color(0xFF4A148C),
                    ),
                  ),
                  Text(
                    '$score/$maxScore',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF75859D),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  Widget _buildAccuracyBadge(double accuracy) {
    Color badgeColor;
    if (accuracy >= 80) {
      badgeColor = const Color(0xFF4CAF50);
    } else if (accuracy >= 60) {
      badgeColor = const Color(0xFFFFC107);
    } else {
      badgeColor = const Color(0xFFBA1A1A);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
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

  const _MetricsGrid({
    required this.totalAttempts,
    required this.completionRate,
    required this.accuracyRate,
    required this.improvementTrend,
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
                color: const Color(0xFF2196F3),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _MetricCard(
                title: 'Completion Rate',
                value: '${completionRate.toStringAsFixed(1)}%',
                icon: Icons.check_circle_outline,
                color: const Color(0xFF4CAF50),
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
                color: const Color(0xFF9C27B0),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _MetricCard(
                title: 'Improvement',
                value: '${improvementTrend > 0 ? '+' : ''}${improvementTrend.toStringAsFixed(1)}%',
                icon: improvementTrend >= 0 ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                color: improvementTrend >= 0 ? const Color(0xFF4CAF50) : const Color(0xFFBA1A1A),
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

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFECEEF0), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 24,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF75859D),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendIndicator extends StatelessWidget {
  final double trend;

  const _TrendIndicator({required this.trend});

  @override
  Widget build(BuildContext context) {
    final isPositive = trend >= 0;
    final trendColor = isPositive ? const Color(0xFF4CAF50) : const Color(0xFFBA1A1A);
    final trendIcon = isPositive ? Icons.trending_up_rounded : Icons.trending_down_rounded;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: trendColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: trendColor.withOpacity(0.2), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: trendColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(trendIcon, color: trendColor, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isPositive ? 'You\'re Improving! 🚀' : 'Keep Trying! 💪',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
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
                    color: trendColor.withOpacity(0.8),
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
