import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

  /// Stop Kiosk Mode and exit the application cleanly
  static Future<void> exitApp() async {
    await stopKioskMode();
    if (Platform.isAndroid) {
      await SystemNavigator.pop();
    } else {
      exit(0);
    }
  }

  /// Show a confirmation dialog to the student before exiting the application
  static void showExitDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1B4B),
        title: const Row(
          children: [
            Icon(Icons.exit_to_app_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('Exit App?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
          ],
        ),
        content: const Text(
          'Are you sure you want to exit the application?',
          style: TextStyle(color: Color(0xFFCCC3D4), fontWeight: FontWeight.w500),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFFD3BBFF), fontWeight: FontWeight.w700)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              exitApp();
            },
            child: const Text('Exit', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}
