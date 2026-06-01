import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:device_info_plus/device_info_plus.dart';

import 'providers/auth_provider.dart';
import 'providers/exam_provider.dart';
import 'services/kiosk_service.dart';

import 'utils/app_theme.dart';
import 'widgets/offline_indicator.dart';
import 'utils/error_boundary.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/student/student_dashboard.dart';
import 'providers/theme_provider.dart';

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
  
  // Start global Kiosk mode
  await KioskService.startKioskMode();
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()..tryAutoLogin()),
        ChangeNotifierProvider(create: (_) => ExamProvider()),
      ],
      child: const MathsWithSDApp(),
    ),
  );
}

Future<bool> _isEmulator() async {
  const channel = MethodChannel('com.mathswithsd.exam_security');
  try {
    if (Platform.isAndroid) {
      final Map<dynamic, dynamic>? result = 
          await channel.invokeMethod<Map<dynamic, dynamic>>('evaluateEmulatorRisk');
      if (result != null) {
        final double risk = (result['cumulativeRisk'] ?? 0.0) as double;
        debugPrint('[Security] Startup emulator risk evaluation: ${risk * 100}%');
        return risk >= 0.70;
      }
    }
  } catch (e) {
    debugPrint('Error detecting emulator via native channel: $e');
  }

  // Fallback to DeviceInfoPlugin if native channel is unavailable or on other platforms
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
    debugPrint('Fallback error detecting emulator: $e');
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

class MathsWithSDApp extends StatefulWidget {
  const MathsWithSDApp({super.key});

  @override
  State<MathsWithSDApp> createState() => _MathsWithSDAppState();
}

class _MathsWithSDAppState extends State<MathsWithSDApp> with WidgetsBindingObserver {
  bool _isMultiWindowPhase = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    setState(() {
      if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
        _isMultiWindowPhase = true;
      } else if (state == AppLifecycleState.resumed) {
        _isMultiWindowPhase = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ErrorBoundary(
      child: MaterialApp(
        title: 'MathsWithSD',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: Provider.of<ThemeProvider>(context).themeMode,
        debugShowCheckedModeBanner: false,
        builder: (context, child) {
          return Stack(
            children: [
              OfflineIndicator(child: child!),
              if (_isMultiWindowPhase)
                Positioned.fill(
                  child: ClipRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        color: Colors.black.withOpacity(0.65),
                        child: const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.security_rounded,
                                color: Colors.amberAccent,
                                size: 80,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Security Protection Active',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'App content obscured for privacy',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
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
