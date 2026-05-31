import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/exam_provider.dart';
import '../../models/exam_model.dart';
import '../../models/test_model.dart';
import '../shared/announcements_screen.dart';
import '../shared/settings_screen.dart';
import '../../widgets/animations.dart';
import '../../widgets/difficulty_badge.dart';
import '../../widgets/glass_card.dart';
import '../student/performance_screen.dart';
import 'profile_screen.dart';
import 'exam_attempt_screen.dart';
import '../../services/offline_exam_service.dart';
import '../../services/kiosk_service.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const _HomeTab(),
    const ProfileScreen(),
    const SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final examProvider = Provider.of<ExamProvider>(context, listen: false);
      final cached = await examProvider.checkForResumableExam();
      if (cached != null) {
        final examId = cached['examId'];
        await examProvider.loadTests();
        final matchedExam = examProvider.scheduledTests.firstWhere(
          (e) => e.id == examId,
          orElse: () => Exam(
            id: examId,
            title: 'Active Test',
            duration: (cached['remainingSeconds'] as int) ~/ 60,
            questions: [],
            date: '',
            time: '',
            classNo: 0,
            language: 'English',
          ),
        );
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ExamAttemptScreen(exam: matchedExam),
            ),
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        if (_currentIndex != 0) {
          setState(() {
            _currentIndex = 0;
          });
        }
      },
      child: Scaffold(
        body: Container(
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0A0F1D), Color(0xFF1E1B4B)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: IndexedStack(
            index: _currentIndex,
            children: _pages,
          ),
        ),
        bottomNavigationBar: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0A0F1D).withOpacity(0.85),
              border: Border(
                top: BorderSide(
                  color: Colors.white.withOpacity(0.08),
                  width: 1,
                ),
              ),
            ),
            child: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: (index) => setState(() => _currentIndex = index),
              selectedItemColor: const Color(0xFFD3BBFF),
              unselectedItemColor: const Color(0xFFA8A5B8),
              selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
              backgroundColor: Colors.transparent,
              elevation: 0,
              showUnselectedLabels: true,
              type: BottomNavigationBarType.fixed,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home_outlined),
                  activeIcon: Icon(Icons.home_rounded),
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person_outline),
                  activeIcon: Icon(Icons.person_rounded),
                  label: 'Profile',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.settings_outlined),
                  activeIcon: Icon(Icons.settings_rounded),
                  label: 'Settings',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab();

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final name = auth.user?.firstName ?? 'Student';

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Row(
          children: [
            const Icon(Icons.school_rounded, color: Color(0xFFD3BBFF), size: 28),
            const SizedBox(width: 10),
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFFD3BBFF), Colors.white],
              ).createShader(bounds),
              child: const Text(
                'MathsWithSD',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ],
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app_rounded, color: Colors.redAccent),
            tooltip: 'Exit App',
            onPressed: () => KioskService.showExitDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded, color: Color(0xFFD3BBFF)),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FadeInSlide(
              duration: const Duration(milliseconds: 700),
              child: GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Welcome back,\n$name! 👋',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              height: 1.25,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8B5CF6).withOpacity(0.15),
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.3)),
                          ),
                          child: const Icon(Icons.auto_awesome_rounded, color: Colors.amberAccent, size: 28),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Keep practicing to sharpen your mathematical instincts and ace your tests!',
                      style: TextStyle(
                        color: Color(0xFFCCC3D4),
                        fontSize: 14,
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (auth.user?.classNo != null) ...[
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(50),
                          border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.3), width: 1),
                        ),
                        child: Text(
                          'Class ${auth.user!.classNo} cohort',
                          style: const TextStyle(
                            color: Color(0xFFD3BBFF),
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            FutureBuilder<Map<String, dynamic>?>(
              future: Provider.of<ExamProvider>(context, listen: false).checkForResumableExam(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done && snapshot.hasData && snapshot.data != null) {
                  final data = snapshot.data!;
                  final examId = data['examId'];
                  final remaining = data['remainingSeconds'] as int;
                  final m = remaining ~/ 60;
                  final s = remaining % 60;
                  final timeStr = '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
                  
                  final provider = Provider.of<ExamProvider>(context, listen: false);
                  final matchedExam = provider.scheduledTests.firstWhere(
                    (e) => e.id == examId,
                    orElse: () => Exam(
                      id: examId,
                      title: 'Active Test',
                      duration: remaining ~/ 60,
                      questions: [],
                      date: '',
                      time: '',
                      classNo: 0,
                      language: 'English',
                    ),
                  );

                  return FadeInSlide(
                    duration: const Duration(milliseconds: 650),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 24),
                      child: GlassCard(
                        color: const Color(0xFF881337).withOpacity(0.3), // Deep crimson alert glass
                        border: Border.all(color: const Color(0xFFF43F5E).withOpacity(0.25), width: 1.2),
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF43F5E).withOpacity(0.15),
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFFF43F5E).withOpacity(0.3)),
                              ),
                              child: const Icon(Icons.alarm_on_rounded, color: Color(0xFFF43F5E), size: 28),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Ongoing Exam Detected!',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${matchedExam.title} • $timeStr left',
                                    style: TextStyle(
                                      color: const Color(0xFFCCC3D4),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ExamAttemptScreen(exam: matchedExam),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFF881337),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                elevation: 0,
                              ),
                              child: const Text(
                                'Resume',
                                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),

            FadeInSlide(
              duration: const Duration(milliseconds: 700),
              delay: const Duration(milliseconds: 100),
              child: const Text(
                'Academic Hub',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: FadeInSlide(
                    duration: const Duration(milliseconds: 600),
                    delay: const Duration(milliseconds: 200),
                    child: BounceOnTap(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AnnouncementsScreen(
                            isAdmin: false,
                            studentClass: auth.user?.classNo?.toString(),
                          ),
                        ),
                      ),
                      child: const _ActionCard(
                        title: 'Notices',
                        subtitle: 'Teacher announcements',
                        icon: Icons.campaign_rounded,
                        color: Color(0xFFF97316), // Orange
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FadeInSlide(
                    duration: const Duration(milliseconds: 600),
                    delay: const Duration(milliseconds: 250),
                    child: BounceOnTap(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ScheduledExamsScreen(isStartTest: false)),
                      ),
                      child: const _ActionCard(
                        title: 'Exams',
                        subtitle: 'Scheduled tests',
                        icon: Icons.event_note_rounded,
                        color: Color(0xFF3B82F6), // Blue
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: FadeInSlide(
                    duration: const Duration(milliseconds: 600),
                    delay: const Duration(milliseconds: 300),
                    child: BounceOnTap(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ScheduledExamsScreen(isStartTest: true)),
                        );
                      },
                      child: const _ActionCard(
                        title: 'Start Test',
                        subtitle: 'Attempt now',
                        icon: Icons.play_circle_outline_rounded,
                        color: Color(0xFF10B981), // Emerald
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FadeInSlide(
                    duration: const Duration(milliseconds: 600),
                    delay: const Duration(milliseconds: 350),
                    child: BounceOnTap(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const PerformanceScreen()),
                        );
                      },
                      child: const _ActionCard(
                        title: 'Results',
                        subtitle: 'Your performance',
                        icon: Icons.analytics_outlined,
                        color: Color(0xFFFBBF24), // Amber
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  final Color color;

  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withOpacity(0.25), width: 1.2),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 15,
              color: Colors.white,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFFA8A5B8),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class ScheduledExamsScreen extends StatefulWidget {
  final bool isStartTest;
  const ScheduledExamsScreen({super.key, this.isStartTest = false});

  @override
  State<ScheduledExamsScreen> createState() => _ScheduledExamsScreenState();
}

class _ScheduledExamsScreenState extends State<ScheduledExamsScreen> {
  Set<String> _localCompletedExamIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      Provider.of<ExamProvider>(context, listen: false).loadTests();
      try {
        final offlineExams = await OfflineExamService().getAllOfflineExams();
        if (mounted) {
          setState(() {
            _localCompletedExamIds = offlineExams
                .where((e) => e.isCompleted || e.status == 'completed' || e.status == 'synced')
                .map((e) => e.examId)
                .toSet();
          });
        }
      } catch (e) {
        debugPrint('Error loading local completed exams: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final titleText = widget.isStartTest ? 'Start Test' : 'Scheduled Exams';
    
    return Scaffold(
      body: Container(
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0A0F1D), Color(0xFF1E1B4B)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Custom Glass AppBar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFFD3BBFF), size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      titleText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Consumer<ExamProvider>(
                  builder: (context, provider, _) {
                    if (provider.testsState == LoadState.loading) {
                      return const Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6)));
                    }

                    final now = DateTime.now();
                    final filteredTests = provider.scheduledTests.where((test) {
                      final testTime = test.getExamDateTime();
                      final isCompleted = provider.completedExamIds.contains(test.id) ||
                          _localCompletedExamIds.contains(test.id);
                          
                      if (testTime == null) return !widget.isStartTest;

                      final diff = testTime.difference(now);
                      final isUpcoming = diff.inSeconds > 0;
                      final isOngoing = diff.inMinutes <= 0 && now.isBefore(testTime.add(Duration(minutes: test.duration)));
                      final isMissed = !isCompleted && diff.inMinutes < 0 && now.isAfter(testTime.add(Duration(minutes: test.duration)));

                      if (widget.isStartTest) {
                        final isUpcomingWithin1Hour = diff.inMinutes > 0 && diff.inMinutes <= 60;
                        return !isCompleted && (isUpcomingWithin1Hour || isOngoing);
                      } else {
                        return isUpcoming || isCompleted || isMissed;
                      }
                    }).toList();

                    if (filteredTests.isEmpty) {
                      return Center(
                        child: FadeInSlide(
                          duration: const Duration(milliseconds: 550),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.04),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                                ),
                                child: Icon(
                                  widget.isStartTest ? Icons.play_disabled_rounded : Icons.event_busy_rounded,
                                  size: 64,
                                  color: const Color(0xFFA8A5B8),
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                widget.isStartTest
                                    ? 'No tests startable right now.'
                                    : 'No exams scheduled.',
                                style: const TextStyle(color: Color(0xFFCCC3D4), fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      itemCount: filteredTests.length,
                      physics: const BouncingScrollPhysics(),
                      itemBuilder: (context, i) {
                        final test = filteredTests[i];
                        final testTime = test.getExamDateTime();
                        final isCompleted = provider.completedExamIds.contains(test.id) ||
                            _localCompletedExamIds.contains(test.id);
                        
                        bool isUpcoming = false;
                        bool isOngoing = false;
                        bool isMissed = false;
                        Duration? timeToStart;

                        if (testTime != null) {
                          final diff = testTime.difference(now);
                          if (diff.inSeconds > 0) {
                            isUpcoming = true;
                            timeToStart = diff;
                          } else if (now.isBefore(testTime.add(Duration(minutes: test.duration)))) {
                            isOngoing = true;
                          } else {
                            isMissed = !isCompleted;
                          }
                        }

                        return FadeInSlide(
                          duration: const Duration(milliseconds: 500),
                          delay: Duration(milliseconds: i * 100),
                          child: _ExamCard(
                            test: test,
                            isCompleted: isCompleted,
                            isUpcoming: isUpcoming,
                            isOngoing: isOngoing,
                            isMissed: isMissed,
                            timeToStart: timeToStart,
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExamCard extends StatelessWidget {
  final Exam test;
  final bool isCompleted;
  final bool isUpcoming;
  final bool isOngoing;
  final bool isMissed;
  final Duration? timeToStart;

  const _ExamCard({
    required this.test,
    required this.isCompleted,
    required this.isUpcoming,
    required this.isOngoing,
    required this.isMissed,
    this.timeToStart,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: GlassCard(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.25), width: 1.2),
              ),
              child: const Icon(Icons.assignment_rounded, color: Color(0xFFD3BBFF), size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          test.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            color: Colors.white,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                      _buildStatusBadge(),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded, size: 12, color: Color(0xFFCCC3D4)),
                      const SizedBox(width: 6),
                      Text(
                        '${test.date} @ ${test.time}',
                        style: const TextStyle(color: Color(0xFFCCC3D4), fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Duration: ${test.duration} Mins',
                        style: const TextStyle(color: Color(0xFFCCC3D4), fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      if (!isCompleted && !isMissed)
                        TextButton.icon(
                          onPressed: () async {
                            try {
                              final offlineExam = OfflineExam(
                                examId: test.id,
                                title: test.title,
                                duration: test.duration,
                                questions: test.questions.map((q) => q.toJson()).toList(),
                                startedAt: DateTime.now(),
                                isCompleted: false,
                                status: 'downloaded',
                              );
                              await OfflineExamService().saveExamOffline(offlineExam);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('"${test.title}" downloaded for offline use.'),
                                    backgroundColor: const Color(0xFF8B5CF6),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Failed to download: ${e.toString()}'),
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.download_for_offline_rounded, size: 16),
                          label: const Text('Download Offline', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFFD3BBFF),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFF10B981).withOpacity(0.2)),
                            ),
                            child: Text(
                              '${test.questions.length} Questions',
                              style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w800, fontSize: 11),
                            ),
                          ),
                          const SizedBox(width: 8),
                          DifficultyIndicator(
                            difficulty: Provider.of<ExamProvider>(context, listen: false).examDifficulties[test.id] ?? 3.0,
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          ),
                        ],
                      ),
                      _buildActionButton(context),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    String text = '';
    Color color = Colors.grey;
    if (isCompleted) {
      text = 'Completed';
      color = const Color(0xFF10B981);
    } else if (isMissed) {
      text = 'Missed';
      color = const Color(0xFFEF4444);
    } else if (isOngoing) {
      text = 'Live';
      color = const Color(0xFFF43F5E);
    } else if (isUpcoming) {
      text = 'Upcoming';
      color = const Color(0xFF3B82F6);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.25), width: 1),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 10),
      ),
    );
  }

  Widget _buildActionButton(BuildContext context) {
    if (isCompleted || isMissed) {
      return const SizedBox.shrink();
    }

    String buttonText = 'Start Now';
    bool enabled = true;

    if (isUpcoming && timeToStart != null) {
      enabled = false;
      if (timeToStart!.inHours > 0) {
        buttonText = 'Starts in ${timeToStart!.inHours}h ${timeToStart!.inMinutes % 60}m';
      } else {
        buttonText = 'Starts in ${timeToStart!.inMinutes}m';
      }
    }

    return ElevatedButton(
      onPressed: enabled
          ? () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ExamAttemptScreen(exam: test),
                ),
              );
            }
          : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF8B5CF6),
        disabledBackgroundColor: Colors.white.withOpacity(0.04),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        minimumSize: const Size(0, 32),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(
        buttonText,
        style: TextStyle(
          color: enabled ? Colors.white : Colors.white.withOpacity(0.25),
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
