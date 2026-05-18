import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/admin_provider.dart';
import '../admin/manage_students_screen.dart';
import '../admin/create_test_screen.dart';
import '../admin/your_tests_screen.dart';
import '../admin/create_question_screen.dart';
import '../shared/announcements_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF0F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF006064),
        title: Text(
          _selectedTab == 0 ? 'Teacher Dashboard' : 'Create Question',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 20),
        ),
        actions: [
          if (_selectedTab == 0) ...[
            IconButton(
              icon: const Icon(Icons.swap_horiz, color: Colors.white),
              tooltip: 'Switch to Student View',
              onPressed: () {
                final nav = Navigator.of(context);
                nav.pushReplacementNamed('/student');
              },
            ),
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.white),
              onPressed: () async {
                final confirm = await _showLogoutDialog(context);
                if (confirm == true && context.mounted) {
                  await auth.logout();
                  if (context.mounted) {
                    Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
                  }
                }
              },
            ),
          ],
        ],
        elevation: 0,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedTab,
        onDestinationSelected: (i) => setState(() => _selectedTab = i),
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFE0F7FA),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard, color: Color(0xFF006064)),
            label: 'Overview',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_circle_outline),
            selectedIcon: Icon(Icons.add_circle, color: Color(0xFF673AB7)),
            label: 'Create',
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedTab,
        children: const [
          _AdminOverviewContent(),
          CreateQuestionTab(),
        ],
      ),
    );
  }

  Future<bool?> _showLogoutDialog(BuildContext context) {
    return showDialog<bool>(
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
  }
}

class _AdminOverviewContent extends StatelessWidget {
  const _AdminOverviewContent();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFE0F7FA), Color(0xFFFFFFFF)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00BCD4), Color(0xFF006064)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00BCD4).withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Welcome, Teacher! 👋',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Manage students, create tests, and organize your questions.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            const Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF006064),
              ),
            ),
            const SizedBox(height: 16),

            // Action Grid
            _actionGrid(context),
          ],
        ),
      ),
    );
  }

  Widget _actionGrid(BuildContext context) {
    final actions = [
      _ActionItem(
        title: 'Manage Students',
        subtitle: 'Accept & reject',
        icon: Icons.people_alt,
        color: const Color(0xFF009688),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageStudentsScreen())),
      ),
      _ActionItem(
        title: 'Make Tests',
        subtitle: 'Schedule exams',
        icon: Icons.quiz,
        color: const Color(0xFF673AB7),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateTestScreen())),
      ),
      _ActionItem(
        title: 'Your Tests',
        subtitle: 'View all tests',
        icon: Icons.fact_check,
        color: const Color(0xFFE91E63),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const YourTestsScreen())),
      ),
      _ActionItem(
        title: 'Announcements',
        subtitle: 'Notify students',
        icon: Icons.campaign,
        color: const Color(0xFF1565C0),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AnnouncementsScreen(isAdmin: true))),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.1,
      ),
      itemCount: actions.length,
      itemBuilder: (context, i) => _ActionCard(action: actions[i]),
    );
  }
}

class _ActionItem {
  final String title, subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}

class _ActionCard extends StatelessWidget {
  final _ActionItem action;
  const _ActionCard({required this.action});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      elevation: 4,
      shadowColor: action.color.withValues(alpha: 0.2),
      child: InkWell(
        onTap: action.onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: action.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(action.icon, color: action.color, size: 28),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    action.title,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF1A1A2E)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    action.subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
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
