import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/admin_provider.dart';
import '../shared/announcements_screen.dart';
import '../../models/test_model.dart';

class StudentDashboard extends StatelessWidget {
  const StudentDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final name = auth.user?.firstName ?? 'Student';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F0FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF4A148C),
        title: const Text('Student Dashboard', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.swap_horiz, color: Colors.white),
            tooltip: 'Teacher View',
            onPressed: () {
              if (auth.isAdmin) {
                Navigator.of(context).pushReplacementNamed('/admin');
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: const Text('Logout', style: TextStyle(fontWeight: FontWeight.w700)),
                  content: const Text('Are you sure you want to sign out?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      child: const Text('Logout', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              );
              if (confirm == true && context.mounted) {
                await auth.logout();
                if (context.mounted) Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
              }
            },
          ),
        ],
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF3E5F5), Color(0xFFFFFFFF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF9C27B0), Color(0xFF4A148C)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF9C27B0).withValues(alpha: 0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome, $name! 🎓',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      auth.user?.verified == true
                          ? 'Your account is verified. Ready to ace your exams?'
                          : 'Waiting for admin verification...',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 14,
                      ),
                    ),
                    if (auth.user?.classNo != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(50),
                        ),
                        child: Text(
                          'Class ${auth.user!.classNo}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 28),

              const Text(
                'My Learning',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF4A148C)),
              ),
              const SizedBox(height: 16),

              // Grid Row 1
              Row(
                children: [
                  Expanded(
                    child: _ActionCard(
                      title: 'Announcements',
                      subtitle: 'View notices',
                      icon: Icons.campaign,
                      color: const Color(0xFFFF5722),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AnnouncementsScreen(
                            isAdmin: false,
                            studentClass: auth.user?.classNo?.toString(),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _ActionCard(
                      title: 'Scheduled Exams',
                      subtitle: 'Upcoming tests',
                      icon: Icons.event_note,
                      color: const Color(0xFF03A9F4),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ScheduledExamsScreen()),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Grid Row 2
              Row(
                children: [
                  Expanded(
                    child: _ActionCard(
                      title: 'Take Exam',
                      subtitle: 'Start a test',
                      icon: Icons.play_circle_filled,
                      color: const Color(0xFF4CAF50),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Select a scheduled exam to start')),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _ActionCard(
                      title: 'My Results',
                      subtitle: 'View scores',
                      icon: Icons.score,
                      color: const Color(0xFFFFC107),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Results feature coming soon')),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      elevation: 4,
      shadowColor: color.withValues(alpha: 0.2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 12),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF1A1A2E))),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Scheduled Exams Screen ────────────────────────────────────────────────────
class ScheduledExamsScreen extends StatefulWidget {
  const ScheduledExamsScreen({super.key});

  @override
  State<ScheduledExamsScreen> createState() => _ScheduledExamsScreenState();
}

class _ScheduledExamsScreenState extends State<ScheduledExamsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AdminProvider>(context, listen: false).loadTests();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF03A9F4),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Scheduled Exams', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        elevation: 0,
      ),
      body: Consumer<AdminProvider>(
        builder: (context, provider, _) {
          if (provider.testsState == LoadState.loading) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF03A9F4)));
          }
          if (provider.tests.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_busy, size: 80, color: Colors.grey.shade200),
                  const SizedBox(height: 16),
                  const Text('No upcoming exams right now.', style: TextStyle(color: Colors.grey, fontSize: 16)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.tests.length,
            itemBuilder: (context, i) => _ExamCard(test: provider.tests[i]),
          );
        },
      ),
    );
  }
}

class _ExamCard extends StatelessWidget {
  final TestConfig test;
  const _ExamCard({required this.test});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 3,
      color: const Color(0xFFE1F5FE),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFFB3E5FC),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.event, color: Color(0xFF0288D1), size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Class ${test.classNo} • ${test.language}',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFF01579B)),
                  ),
                  const SizedBox(height: 4),
                  Text('Date: ${test.date}  |  Time: ${test.time}',
                    style: const TextStyle(color: Colors.blueGrey, fontSize: 13)),
                  Text('${test.totalQuestions} Questions  •  ${test.totalTime} Mins',
                    style: const TextStyle(color: Color(0xFF0277BD), fontWeight: FontWeight.w600, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
