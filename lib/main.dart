import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:device_info_plus/device_info_plus.dart';

import 'providers/auth_provider.dart';
import 'providers/exam_provider.dart';

import 'utils/app_theme.dart';
import 'widgets/offline_indicator.dart';
import 'utils/error_boundary.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/student/student_dashboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Check for emulator
  bool emulator = await _isEmulator();
  if (emulator) {
    runApp(const EmulatorWarningApp());
    return;
  }

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..tryAutoLogin()),
        ChangeNotifierProvider(create: (_) => ExamProvider()),
      ],
      child: const MathsWithSDApp(),
    ),
  );
}

Future<bool> _isEmulator() async {
  DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
  try {
    if (Platform.isAndroid) {
      AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      return !androidInfo.isPhysicalDevice;
    } else if (Platform.isIOS) {
      IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
      return !iosInfo.isPhysicalDevice;
    }
  } catch (e) {
    debugPrint('Error detecting emulator: $e');
  }
  return false;
}

class EmulatorWarningApp extends StatefulWidget {
  const EmulatorWarningApp({super.key});

  @override
  State<EmulatorWarningApp> createState() => _EmulatorWarningAppState();
}

class _EmulatorWarningAppState extends State<EmulatorWarningApp> {
  bool _shutdownScheduled = false;

  @override
  void initState() {
    super.initState();
    _scheduleShutdown();
  }

  void _scheduleShutdown() {
    if (_shutdownScheduled) return;
    _shutdownScheduled = true;
    Future.delayed(const Duration(seconds: 5), () {
      if (!mounted) return;
      if (Platform.isAndroid) {
        SystemNavigator.pop();
      } else {
        exit(0);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF0A1628),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 100),
                const SizedBox(height: 32),
                const Text(
                  'Security Violation',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Running this app in an emulator is not allowed',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 48),
                const Text(
                  'The app will close automatically in 5 seconds...',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 24),
                const CircularProgressIndicator(color: Colors.redAccent),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MathsWithSDApp extends StatelessWidget {
  const MathsWithSDApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ErrorBoundary(
      child: MaterialApp(
        title: 'MathsWithSD',
        theme: AppTheme.lightTheme,
        debugShowCheckedModeBanner: false,
        builder: (context, child) {
          return OfflineIndicator(child: child!);
        },
        home: const _AuthGate(),
        routes: {
          '/login': (context) => LoginScreen(
            onNavigateToRegister: () => Navigator.pushReplacementNamed(context, '/register'),
          ),
          '/register': (context) => RegisterScreen(
            onBackToLogin: () => Navigator.pushReplacementNamed(context, '/login'),
          ),
          '/student': (context) => const StudentDashboard(),
        },
      ),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (auth.status == AuthStatus.initial) {
          // Splash screen while checking auto-login
          return const Scaffold(
            backgroundColor: Color(0xFF0A1628),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.school, color: Color(0xFF00BCD4), size: 80),
                  SizedBox(height: 24),
                  CircularProgressIndicator(color: Color(0xFF00BCD4)),
                ],
              ),
            ),
          );
        }

        if (auth.isAuthenticated) {
          // Force student dashboard even if user is admin (security cleanup)
          return const StudentDashboard();
        }

        // Unauthenticated
        return LoginScreen(
          onNavigateToRegister: () {
            Navigator.pushReplacementNamed(context, '/register');
          },
        );
      },
    );
  }
}
