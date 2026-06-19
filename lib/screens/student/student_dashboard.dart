import 'dart:ui';
import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/exam_provider.dart';
import '../../models/exam_model.dart';
import '../shared/announcements_screen.dart';
import '../shared/settings_screen.dart';
import '../../widgets/animations.dart';
import '../../widgets/difficulty_badge.dart';
import '../../widgets/glass_card.dart';
import '../student/performance_screen.dart';
import 'profile_screen.dart';
import 'exam_attempt_screen.dart';
import 'self_assessment_screen.dart';
import 'submission_success_screen.dart';
import 'result_screen.dart';
import 'package:intl/intl.dart';
import '../../services/offline_exam_service.dart';
import '../../services/kiosk_service.dart';
import '../../services/network_time_service.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _animationController;

  final List<Widget> _pages = [
    const _HomeTab(),
    const ProfileScreen(),
    const SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat(reverse: true);

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
            classNo: 10,
            language: 'English',
          ),
        );
        if (mounted) {
          KioskService.checkPinAndNavigate(
            context,
            ExamAttemptScreen(exam: matchedExam),
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final auth = Provider.of<AuthProvider>(context);

    if (auth.status == AuthStatus.unauthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushNamedAndRemoveUntil('/welcome', (route) => false);
      });
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

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
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                            color: const Color(
                              0xFFD946EF,
                            ).withValues(alpha: 0.09),
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
            // Core Tab Contents
            Positioned.fill(
              child: IndexedStack(index: _currentIndex, children: _pages),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.4)
                        : Colors.white.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : const Color(0x1F000000),
                      width: 1.0,
                    ),
                  ),
                  child: _CustomBottomNavBar(
                    currentIndex: _currentIndex,
                    onTap: (index) => setState(() => _currentIndex = index),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CustomBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const _CustomBottomNavBar({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themePrimary = isDark
        ? const Color(0xFF5D9BFF)
        : const Color(0xFF0051D5);
    final items = [
      {
        'icon': Icons.home_outlined,
        'activeIcon': Icons.home_rounded,
        'label': 'Home',
      },
      {
        'icon': Icons.person_outline,
        'activeIcon': Icons.person_rounded,
        'label': 'Profile',
      },
      {
        'icon': Icons.settings_outlined,
        'activeIcon': Icons.settings_rounded,
        'label': 'Settings',
      },
    ];

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.noScaling,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(items.length, (index) {
          final item = items[index];
          final isSelected = currentIndex == index;
          final iconData =
              (isSelected ? item['activeIcon'] : item['icon']) as IconData;
          final label = item['label'] as String;

          return Expanded(
            child: GestureDetector(
              onTap: () => onTap(index),
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? themePrimary.withValues(alpha: 0.12)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        iconData,
                        color: isSelected
                            ? themePrimary
                            : (isDark ? Colors.white38 : const Color(0xFF75859D)),
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isSelected
                            ? FontWeight.w900
                            : FontWeight.w700,
                        color: isSelected
                            ? themePrimary
                            : (isDark ? Colors.white38 : const Color(0xFF75859D)),
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _HomeTab extends StatefulWidget {
  const _HomeTab();

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  late Timer _timer;
  String _currentQuote = "";

  static const List<String> _motivationalQuotes = [
    "Be the wolf they didn't see coming.",
    "The graveyard is full of unfulfilled potential; don't add to the body count.",
    "They want you to fail so they feel better about quitting—don’t give them the satisfaction.",
    "Pain is just a reminder that you haven’t broken yet.",
    "Build your empire with the stones they threw at you.",
    "They didn’t believe in you? Good. Now go make them watch you win.",
    "If you want to take the island, you have to burn the boats.",
    "Comfort is the slow death of greatness; choose the chaos.",
    "Stop waiting for the storm to pass and learn how to dismantle it.",
    "You didn't survive everything you've been through just to be average.",
    "Lions don't lose sleep over the opinions of sheep.",
    "Excuses are the nails used to build a house of failure.",
    "Nobody is coming to save you; get up and save yourself.",
    "You can have results or excuses, but you can’t have both.",
    "The only thing standing between you and your goal is the bullshit story you keep telling yourself.",
    "Work until your idols become your rivals.",
    "Don't talk about it; be about it.",
    "If it was easy, everyone would do it.",
    "Stop telling people your plans; show them your results.",
    "Starve your distractions, feed your focus.",
    "Pain is temporary; regret lasts forever.",
    "Sweat is just fat crying.",
    "If you're going through hell, keep going.",
    "The harder the battle, the sweeter the victory.",
    "Fall seven times, stand up eight.",
    "Suffering is a choice, but so is strength.",
    "You have to get comfortable with being uncomfortable.",
    "Diamonds are made under pressure.",
    "No pain, no gain.",
    "Muscle grows when it’s torn; so do you.",
    "Mind over matter.",
    "Your mind is a weapon; keep it loaded.",
    "Control your mind or it will control you.",
    "Doubt kills more dreams than failure ever will.",
    "Be a warrior, not a worrier.",
    "Think like a champion, act like a king.",
    "Your only limit is you.",
    "Fear is a liar.",
    "Master your mind, master your life.",
    "The greatest prison people live in is the fear of what other people think.",
    "Go after what you want like your life depends on it.",
    "Don't watch the clock; do what it does. Keep going.",
    "Dream big, hustle harder.",
    "Chase the dream, not the competition.",
    "The best way to predict the future is to create it.",
    "Don't wait for opportunity; create it.",
    "Success is a journey, not a destination.",
    "Make your dreams reality.",
    "Live the life you imagined.",
    "Hunt or be hunted.",
    "Against all odds, I will rise.",
    "Prove them wrong.",
    "They said I couldn't, so I did.",
    "The odds are just numbers; I am a force.",
    "Defy expectations.",
    "Break the mold.",
    "Shock the world.",
    "Be the exception to the rule.",
    "Nothing is impossible to a willing mind.",
    "I am the storm.",
    "Let your success be your noise.",
    "Don't argue with fools; just win.",
    "Critics don't build monuments.",
    "Their doubt is my fuel.",
    "Keep grinding in the dark; let them see the light.",
    "Actions speak louder than words.",
    "Kill them with success, bury them with a smile.",
    "Your success is the best revenge.",
    "Don't listen to the haters.",
    "Focus on your lane.",
    "I am the master of my fate, the captain of my soul.",
    "You are stronger than you think.",
    "Own your greatness.",
    "Step into your power.",
    "Be unapologetically you.",
    "You hold the key to your success.",
    "Believe in yourself.",
    "You are a force of nature.",
    "Unstoppable.",
    "Fearless.",
    "Rise and grind.",
    "Sleep is for the weak.",
    "Hustle until your haters ask if you're hiring.",
    "No days off.",
    "The hustle never sleeps.",
    "Work hard, play harder.",
    "Put in the work.",
    "Hustle hard.",
    "Earned, not given.",
    "Grind now, shine later.",
    "Build a legacy, not just a life.",
    "Be remembered.",
    "Leave a mark on the world.",
    "Greatness is within you.",
    "Strive for excellence.",
    "Make history.",
    "Live for something bigger than yourself.",
    "Your legacy starts now.",
    "Leave the world better than you found it.",
    "Die with memories, not dreams.",
  ];

  bool _isPinned = false;

  @override
  void initState() {
    super.initState();
    _currentQuote = _getRandomQuote();
    _timer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (mounted) {
        setState(() {
          _currentQuote = _getRandomQuote();
        });
      }
    });
    _checkPinStatus();
  }

  String _getRandomQuote() {
    final random = math.Random();
    String nextQuote;
    do {
      nextQuote =
          _motivationalQuotes[random.nextInt(_motivationalQuotes.length)];
    } while (nextQuote == _currentQuote && _motivationalQuotes.length > 1);
    return nextQuote;
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  Future<void> _checkPinStatus() async {
    final pinned = await KioskService.isAppPinned();
    if (mounted) {
      setState(() {
        _isPinned = pinned;
      });
    }
  }

  Future<void> _handlePinUnpin() async {
    final currentlyPinned = await KioskService.isAppPinned();
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) {
        final textColor = const Color(0xFF0F172A);
        final subTextColor = const Color(0xFF475569);

        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: GlassCard(
            color: Colors.white.withValues(alpha: 0.85),
            padding: const EdgeInsets.all(24),
            borderRadius: 24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      currentlyPinned ? Icons.pin_drop_rounded : Icons.push_pin_rounded,
                      color: const Color(0xFF8B5CF6),
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      currentlyPinned ? 'Unpin App' : 'Pin App',
                      style: TextStyle(color: textColor, fontWeight: FontWeight.w900, fontSize: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  currentlyPinned ? 'The app will be unpinned.' : 'The app will be pinned.',
                  style: TextStyle(color: subTextColor, fontWeight: FontWeight.w500, fontSize: 15, height: 1.5),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(
                        'Cancel',
                        style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        if (currentlyPinned) {
                          await KioskService.stopKioskMode();
                        } else {
                          await KioskService.startKioskMode();
                        }
                        // Wait a bit for OS to react and update
                        Future.delayed(const Duration(milliseconds: 1000), () {
                          _checkPinStatus();
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B5CF6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('OK', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showUpgradeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: const Row(
          children: [
            Icon(Icons.lock_rounded, color: Colors.amber, size: 24),
            SizedBox(width: 8),
            Text(
              'Premium Feature',
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const Text(
          'Contact Soumen Sir if you would like to upgrade. Charges may apply.',
          style: TextStyle(color: Color(0xFF334155), fontSize: 16, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey,
            ),
            child: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0051D5),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final name = auth.user?.firstName ?? 'Student';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final secondaryTextColor = isDark
        ? Colors.white70
        : const Color(0xFF75859D);
    final themePrimary = isDark
        ? const Color(0xFF5D9BFF)
        : const Color(0xFF0051D5);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.asset(
                'assets/images/app_icon.jpg',
                width: 28,
                height: 28,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'MathswithSD',
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w900,
                fontSize: 22,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.exit_to_app_rounded,
              color: Colors.redAccent,
            ),
            tooltip: 'Exit App',
            onPressed: () => KioskService.showExitDialog(context),
          ),
          IconButton(
            icon: Icon(
              _isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
              color: _isPinned ? const Color(0xFF38BDF8) : textColor,
            ),
            tooltip: _isPinned ? 'Unpin App' : 'Pin App',
            onPressed: _handlePinUnpin,
          ),
          IconButton(
            icon: Icon(Icons.notifications_none_rounded, color: textColor),
            onPressed: auth.user?.accountType == 'TRIAL'
                ? () => _showUpgradeDialog(context)
                : () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AnnouncementsScreen(
                          isAdmin: false,
                          studentClass: auth.user?.classNo?.toString(),
                        ),
                      ),
                    ),
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
                            style: TextStyle(
                              color: textColor,
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              height: 1.25,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: themePrimary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: themePrimary.withValues(alpha: 0.2),
                            ),
                          ),
                          child: const Icon(
                            Icons.auto_awesome_rounded,
                            color: Colors.amberAccent,
                            size: 28,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight: 44,
                        minWidth: double.infinity,
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 400),
                        transitionBuilder:
                            (Widget child, Animation<double> animation) {
                              return FadeTransition(
                                opacity: animation,
                                child: child,
                              );
                            },
                        child: Text(
                          _currentQuote,
                          key: ValueKey<String>(_currentQuote),
                          style: TextStyle(
                            color: secondaryTextColor,
                            fontSize: 14,
                            height: 1.4,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    if (auth.user?.classNo != null) ...[
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: themePrimary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(50),
                              border: Border.all(
                                color: themePrimary.withValues(alpha: 0.2),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              'Class ${auth.user!.classNo}${auth.user!.isJoint == true ? ' Joint' : ''}',
                              style: TextStyle(
                                color: themePrimary,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const _LiveClockWidget(),
                        ],
                      ),
                    ] else ...[
                      const SizedBox(height: 20),
                      const Align(
                        alignment: Alignment.centerRight,
                        child: _LiveClockWidget(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            FutureBuilder<Map<String, dynamic>?>(
              future: Provider.of<ExamProvider>(
                context,
                listen: false,
              ).checkForResumableExam(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done &&
                    snapshot.hasData &&
                    snapshot.data != null) {
                  final data = snapshot.data!;
                  final examId = data['examId'];
                  final remaining = data['remainingSeconds'] as int;
                  final m = remaining ~/ 60;
                  final s = remaining % 60;
                  final timeStr =
                      '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';

                  final provider = Provider.of<ExamProvider>(
                    context,
                    listen: false,
                  );
                  final matchedExam = provider.scheduledTests.firstWhere(
                    (e) => e.id == examId,
                    orElse: () => Exam(
                      id: examId,
                      title: 'Active Test',
                      duration: remaining ~/ 60,
                      questions: [],
                      date: '',
                      time: '',
                      classNo: 10,
                      language: 'English',
                    ),
                  );

                  return FadeInSlide(
                    duration: const Duration(milliseconds: 650),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 24),
                      child: GlassCard(
                        color: const Color(
                          0xFF881337,
                        ).withValues(alpha: 0.3), // Deep crimson alert glass
                        border: Border.all(
                          color: const Color(
                            0xFFF43F5E,
                          ).withValues(alpha: 0.25),
                          width: 1.2,
                        ),
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFFF43F5E,
                                ).withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(
                                    0xFFF43F5E,
                                  ).withValues(alpha: 0.3),
                                ),
                              ),
                              child: const Icon(
                                Icons.alarm_on_rounded,
                                color: Color(0xFFF43F5E),
                                size: 28,
                              ),
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
                                    style: const TextStyle(
                                      color: Color(0xFFCCC3D4),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () => KioskService.checkPinAndNavigate(
                                context,
                                ExamAttemptScreen(exam: matchedExam),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFF881337),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                elevation: 0,
                              ),
                              child: const Text(
                                'Resume',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13,
                                ),
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
              child: Text(
                'Academic Hub',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: textColor,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Builder(builder: (context) {
              final auth = Provider.of<AuthProvider>(context);
              final isDark = Theme.of(context).brightness == Brightness.dark;
              final themePrimary = isDark ? const Color(0xFF5D9BFF) : const Color(0xFF0051D5);
              final isTrial = auth.user?.accountType == 'TRIAL';

              return Row(
                children: [
                  Expanded(
                    child: FadeInSlide(
                      duration: const Duration(milliseconds: 600),
                      delay: const Duration(milliseconds: 200),
                      child: BounceOnTap(
                        onTap: isTrial
                            ? () => _showUpgradeDialog(context)
                            : () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AnnouncementsScreen(
                                      isAdmin: false,
                                      studentClass: auth.user?.classNo?.toString(),
                                    ),
                                  ),
                                ),
                        child: isTrial
                            ? ImageFiltered(
                                imageFilter: ImageFilter.blur(sigmaX: 3.5, sigmaY: 3.5),
                                child: const _ActionCard(
                                  title: 'Notices',
                                  subtitle: 'Teacher announcements',
                                  icon: Icons.campaign_rounded,
                                  color: Color(0xFFF97316),
                                ),
                              )
                            : const _ActionCard(
                                title: 'Notices',
                                subtitle: 'Teacher announcements',
                                icon: Icons.campaign_rounded,
                                color: Color(0xFFF97316),
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
                        onTap: isTrial
                            ? () => _showUpgradeDialog(context)
                            : () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const ScheduledExamsScreen(isStartTest: false),
                                  ),
                                ),
                        child: isTrial
                            ? ImageFiltered(
                                imageFilter: ImageFilter.blur(sigmaX: 3.5, sigmaY: 3.5),
                                child: _ActionCard(
                                  title: 'Exams',
                                  subtitle: 'Scheduled tests',
                                  icon: Icons.event_note_rounded,
                                  color: themePrimary,
                                ),
                              )
                            : _ActionCard(
                                title: 'Exams',
                                subtitle: 'Scheduled tests',
                                icon: Icons.event_note_rounded,
                                color: themePrimary,
                              ),
                      ),
                    ),
                  ),
                ],
              );
            }),
            const SizedBox(height: 16),
            Builder(builder: (context) {
              final auth = Provider.of<AuthProvider>(context);
              final isTrial = auth.user?.accountType == 'TRIAL';

              return Row(
                children: [
                  Expanded(
                    child: FadeInSlide(
                      duration: const Duration(milliseconds: 600),
                      delay: const Duration(milliseconds: 300),
                      child: BounceOnTap(
                        onTap: isTrial
                            ? () => _showUpgradeDialog(context)
                            : () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const ScheduledExamsScreen(isStartTest: true),
                                  ),
                                );
                              },
                        child: isTrial
                            ? ImageFiltered(
                                imageFilter: ImageFilter.blur(sigmaX: 3.5, sigmaY: 3.5),
                                child: const _ActionCard(
                                  title: 'Start Test',
                                  subtitle: 'Attempt now',
                                  icon: Icons.play_circle_outline_rounded,
                                  color: Color(0xFF10B981),
                                ),
                              )
                            : const _ActionCard(
                                title: 'Start Test',
                                subtitle: 'Attempt now',
                                icon: Icons.play_circle_outline_rounded,
                                color: Color(0xFF10B981),
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
                            MaterialPageRoute(
                              builder: (_) => const PerformanceScreen(),
                            ),
                          );
                        },
                        child: const _ActionCard(
                          title: 'Results',
                          subtitle: 'Your performance',
                          icon: Icons.analytics_outlined,
                          color: Color(0xFFFBBF24),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }),
            const SizedBox(height: 16),
            FadeInSlide(
              duration: const Duration(milliseconds: 600),
              delay: const Duration(milliseconds: 400),
              child: BounceOnTap(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SelfAssessmentScreen(),
                    ),
                  );
                },
                child: GlassCard(
                  padding: const EdgeInsets.all(24),
                  color: isDark
                      ? themePrimary.withValues(alpha: 0.08)
                      : themePrimary.withValues(alpha: 0.05),
                  border: Border.all(
                    color: themePrimary.withValues(alpha: 0.25),
                    width: 1.2,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: themePrimary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: themePrimary.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Icon(
                          Icons.psychology_rounded,
                          color: themePrimary,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Generate Practice Test',
                              style: TextStyle(
                                color: textColor,
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Create randomized self-assessments matching your class curriculum.',
                              style: TextStyle(
                                color: secondaryTextColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: themePrimary,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _LiveClockWidget extends StatefulWidget {
  const _LiveClockWidget();

  @override
  State<_LiveClockWidget> createState() => _LiveClockWidgetState();
}

class _LiveClockWidgetState extends State<_LiveClockWidget> {
  late Timer _timer;
  late DateTime _now;
  DateTime _lastLocalTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _now = NetworkTimeService().istNow;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final nowLocal = DateTime.now();
      final diff = nowLocal.difference(_lastLocalTime).inSeconds.abs();
      if (diff > 5) {
        debugPrint('[LiveClock] Time jump detected ($diff s). Resyncing with network time.');
        NetworkTimeService().syncTime();
      }
      _lastLocalTime = nowLocal;

      if (mounted) {
        setState(() {
          _now = NetworkTimeService().istNow;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final secondaryTextColor = isDark ? Colors.white70 : const Color(0xFF75859D);
    final themePrimary = isDark ? const Color(0xFF5D9BFF) : const Color(0xFF0051D5);
    final isSynced = NetworkTimeService().isSynced;
    
    final timeStr = DateFormat('hh:mm:ss a').format(_now);
    final dateStr = DateFormat('EEE, MMM d, yyyy').format(_now);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSynced ? const Color(0xFF10B981) : Colors.amber,
                boxShadow: [
                  BoxShadow(
                    color: (isSynced ? const Color(0xFF10B981) : Colors.amber)
                        .withValues(alpha: 0.5),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.schedule_rounded,
              color: themePrimary,
              size: 14,
            ),
            const SizedBox(width: 4),
            Text(
              timeStr,
              style: TextStyle(
                color: textColor,
                fontSize: 14,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          isSynced ? dateStr : '$dateStr (Local)',
          style: TextStyle(
            color: secondaryTextColor,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final secondaryTextColor = isDark
        ? Colors.white70
        : const Color(0xFF75859D);

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: color.withValues(alpha: 0.25),
                width: 1.2,
              ),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 15,
              color: textColor,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
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
                .where(
                  (e) =>
                      e.isCompleted ||
                      e.status == 'completed' ||
                      e.status == 'synced',
                )
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final secondaryTextColor = isDark
        ? Colors.white70
        : const Color(0xFF75859D);
    final themePrimary = isDark
        ? const Color(0xFF5D9BFF)
        : const Color(0xFF0051D5);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: textColor,
                      size: 20,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.isStartTest ? 'Start Test' : 'Scheduled Exams',
                    style: TextStyle(
                      color: textColor,
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
                    return Center(
                      child: CircularProgressIndicator(color: themePrimary),
                    );
                  }

                  final ist = NetworkTimeService().istNow;
                  final now = DateTime(
                    ist.year,
                    ist.month,
                    ist.day,
                    ist.hour,
                    ist.minute,
                    ist.second,
                    ist.millisecond,
                  );
                  final filteredTests = provider.scheduledTests.where((test) {
                    final testTime = test.getExamDateTime();
                    final isCompleted =
                        provider.completedExamIds.contains(test.id) ||
                        _localCompletedExamIds.contains(test.id);

                    if (testTime == null) return !widget.isStartTest;

                    final diff = testTime.difference(now);
                    final isUpcoming = diff.inSeconds > 0;
                    final isOngoing =
                        diff.inMinutes <= 0 &&
                        now.isBefore(
                          testTime.add(Duration(minutes: test.duration)),
                        );
                    final isMissed =
                        !isCompleted &&
                        diff.inMinutes < 0 &&
                        now.isAfter(
                          testTime.add(Duration(minutes: test.duration)),
                        );

                    if (widget.isStartTest) {
                      final isUpcomingWithin1Hour =
                          diff.inMinutes > 0 && diff.inMinutes <= 60;
                      return !isCompleted &&
                          (isUpcomingWithin1Hour || isOngoing);
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
                                color:
                                    (isDark
                                            ? Colors.white
                                            : const Color(0xFF0F172A))
                                        .withValues(alpha: 0.04),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color:
                                      (isDark
                                              ? Colors.white
                                              : const Color(0xFF0F172A))
                                          .withValues(alpha: 0.08),
                                ),
                              ),
                              child: Icon(
                                widget.isStartTest
                                    ? Icons.play_disabled_rounded
                                    : Icons.event_busy_rounded,
                                size: 64,
                                color: secondaryTextColor,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              widget.isStartTest
                                  ? 'No tests startable right now.'
                                  : 'No exams scheduled.',
                              style: TextStyle(
                                color: secondaryTextColor,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    itemCount: filteredTests.length,
                    physics: const BouncingScrollPhysics(),
                    itemBuilder: (context, i) {
                      final test = filteredTests[i];
                      final testTime = test.getExamDateTime();
                      final isCompleted =
                          provider.completedExamIds.contains(test.id) ||
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
                        } else if (now.isBefore(
                          testTime.add(Duration(minutes: test.duration)),
                        )) {
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final secondaryTextColor = isDark
        ? Colors.white70
        : const Color(0xFF75859D);
    final themePrimary = isDark
        ? const Color(0xFF5D9BFF)
        : const Color(0xFF0051D5);

    final cardWidget = GlassCard(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: themePrimary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: themePrimary.withValues(alpha: 0.2),
                  width: 1.2,
                ),
              ),
              child: Icon(
                Icons.assignment_rounded,
                color: themePrimary,
                size: 28,
              ),
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
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            color: textColor,
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
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 12,
                        color: secondaryTextColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${test.date} @ ${test.time}',
                        style: TextStyle(
                          color: secondaryTextColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Duration: ${test.duration} Mins',
                        style: TextStyle(
                          color: secondaryTextColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF10B981,
                              ).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: const Color(
                                  0xFF10B981,
                                ).withValues(alpha: 0.2),
                              ),
                            ),
                            child: Text(
                              '${test.questions.length} Questions',
                              style: const TextStyle(
                                color: Color(0xFF10B981),
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          DifficultyIndicator(
                            difficulty:
                                Provider.of<ExamProvider>(
                                  context,
                                  listen: false,
                                ).examDifficulties[test.id] ??
                                3.0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                          ),
                        ],
                      ),
                      _buildActionButton(context, isDark, themePrimary),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: isCompleted
          ? BounceOnTap(
              onTap: () async {
                final provider = Provider.of<ExamProvider>(context, listen: false);
                final attemptId = provider.completedExamAttempts[test.id] ?? '';
                final now = NetworkTimeService().istNow;
                final examStart = test.getExamDateTime();
                final examEnd = examStart != null
                    ? examStart.add(Duration(minutes: test.duration))
                    : now;
                final isExamEnded = now.isAfter(examEnd);

                if (!isExamEnded) {
                  final endTimeStr = examStart != null
                      ? DateFormat('hh:mm a').format(examEnd)
                      : '';
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SubmissionSuccessScreen(
                        exam: test,
                        attemptId: attemptId,
                        endTimeStr: endTimeStr,
                      ),
                    ),
                  );
                } else {
                  if (attemptId.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Unable to find completion record for this exam.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  // Show loading dialog
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => const Center(
                      child: CircularProgressIndicator(),
                    ),
                  );

                  try {
                    final resultData = await provider.getResult(attemptId);
                    if (context.mounted) {
                      Navigator.pop(context); // Hide loading dialog
                    }

                    final userAnswers = <String, String>{};
                    if (resultData['responses'] != null) {
                      for (var resp in resultData['responses']) {
                        final qId = resp['questionId']?.toString();
                        final uAns = resp['userAnswer']?.toString() ??
                            resp['selectedAnswer']?.toString() ??
                            '';
                        if (qId != null) {
                          userAnswers[qId] = uAns;
                        }
                      }
                    }

                    final score = resultData['score'] is num
                        ? (resultData['score'] as num).toInt()
                        : 0;
                    int timeTaken = 0;
                    if (resultData['startTime'] != null &&
                        resultData['endTime'] != null) {
                      try {
                        final start = DateTime.parse(resultData['startTime']);
                        final end = DateTime.parse(resultData['endTime']);
                        timeTaken = end.difference(start).inSeconds;
                      } catch (_) {}
                    }
                    if (timeTaken <= 0) {
                      timeTaken = test.duration * 60;
                    }

                    final List<Question> resolvedQuestions = [];
                    if (resultData['examId'] != null && resultData['examId']['questions'] != null) {
                      final List qList = resultData['examId']['questions'] as List;
                      for (var qJson in qList) {
                        resolvedQuestions.add(Question.fromJson(Map<String, dynamic>.from(qJson)));
                      }
                    }
                    final questionsToUse = resolvedQuestions.isNotEmpty ? resolvedQuestions : test.questions;

                    if (context.mounted) {
                      Navigator.push(
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
                    if (context.mounted) {
                      Navigator.pop(context); // Hide loading dialog
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to load result: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                }
              },
              child: cardWidget,
            )
          : cardWidget,
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
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 1),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 10,
        ),
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    bool isDark,
    Color themePrimary,
  ) {
    if (isCompleted || isMissed) {
      return const SizedBox.shrink();
    }

    String buttonText = 'Start Now';
    bool enabled = true;

    if (isUpcoming && timeToStart != null) {
      enabled = false;
      if (timeToStart!.inHours > 0) {
        buttonText =
            'Starts in ${timeToStart!.inHours}h ${timeToStart!.inMinutes % 60}m';
      } else {
        buttonText = 'Starts in ${timeToStart!.inMinutes}m';
      }
    }

    return ElevatedButton(
      onPressed: enabled
          ? () => KioskService.checkPinAndNavigate(
              context,
              ExamAttemptScreen(exam: test),
            )
          : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: themePrimary,
        foregroundColor: isDark ? Colors.black : Colors.white,
        disabledBackgroundColor: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.04),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        minimumSize: const Size(0, 32),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(
        buttonText,
        style: TextStyle(
          color: enabled
              ? (isDark ? Colors.black : Colors.white)
              : (isDark
                    ? Colors.white.withValues(alpha: 0.25)
                    : Colors.white.withValues(alpha: 0.25)),
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
