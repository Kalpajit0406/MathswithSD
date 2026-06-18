import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mathswithsd/widgets/glass_card.dart';

class KioskService {
  static const _channel = MethodChannel('com.mathswithsd.exam_security');
  static bool _globalKioskActive = false;

  static bool get isGlobalKioskActive => _globalKioskActive;

  /// Start Kiosk Mode on the device
  static Future<void> startKioskMode() async {
    try {
      await _channel.invokeMethod('enableKioskMode');
      _globalKioskActive = true;
      debugPrint('[KioskService] Global Kiosk Mode enabled.');
    } catch (e) {
      debugPrint('[KioskService] Error starting kiosk: $e');
    }
  }

  /// Stop Kiosk Mode on the device
  static Future<void> stopKioskMode() async {
    try {
      await _channel.invokeMethod('disableKioskMode');
      _globalKioskActive = false;
      debugPrint('[KioskService] Global Kiosk Mode disabled.');
    } catch (e) {
      debugPrint('[KioskService] Error stopping kiosk: $e');
    }
  }

  /// Check if the application is currently pinned (Lock Task Mode) on the device
  static Future<bool> isAppPinned() async {
    try {
      final bool isPinned = await _channel.invokeMethod('isAppPinned');
      return isPinned;
    } catch (e) {
      debugPrint('[KioskService] Error checking pin status: $e');
      return false;
    }
  }

  /// Stop Kiosk Mode and exit the application cleanly
  static Future<void> exitApp() async {
    await stopKioskMode();
    if (Platform.isAndroid) {
      await SystemNavigator.pop();
    } else {
      exit(0);
    }
  }

  /// Checks if the app is pinned before navigating to an exam.
  /// If not pinned, prompts the student to manually pin the app and blocks navigation.
  static Future<void> checkPinAndNavigate(BuildContext context, Widget targetScreen) async {
    final pinned = await isAppPinned();
    if (pinned) {
      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => targetScreen),
        );
      }
    } else {
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
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
                        const Icon(Icons.lock_outline_rounded, color: Colors.amber, size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Pinning Required',
                            style: TextStyle(color: textColor, fontWeight: FontWeight.w900, fontSize: 20),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'This application must be pinned (Kiosk Mode) to start or resume exams. If it was unpinned, please pin the app to continue.',
                      style: TextStyle(color: subTextColor, fontWeight: FontWeight.w500, fontSize: 15, height: 1.5),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: () async {
                            Navigator.pop(ctx);
                            await startKioskMode();
                            // Re-check after attempting to pin
                            Future.delayed(const Duration(milliseconds: 1500), () async {
                              if (context.mounted) {
                                final reChecked = await isAppPinned();
                                if (reChecked) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => targetScreen),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('⚠️ App is still not pinned. Please approve the pinning prompt.'),
                                      backgroundColor: Colors.redAccent,
                                    ),
                                  );
                                }
                              }
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF8B5CF6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Pin App Now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
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
    }
  }

  /// Show a confirmation dialog to the student before exiting the application
  static void showExitDialog(BuildContext context) {
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
                    const Icon(Icons.exit_to_app_rounded, color: Colors.redAccent, size: 28),
                    const SizedBox(width: 12),
                    Text(
                      'Exit App?',
                      style: TextStyle(color: textColor, fontWeight: FontWeight.w900, fontSize: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Are you sure you want to exit the application?',
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
                        style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 12),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        exitApp();
                      },
                      child: const Text(
                        'Exit',
                        style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w800),
                      ),
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
}
