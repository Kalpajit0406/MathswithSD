import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';

class InAppUpdateService {
  /// Checks if a newer version of the app is available on the Google Play Store.
  /// If an update exists, it initiates a Flexible update in the background.
  /// Once the download completes, it prompts the user with a SnackBar to restart and install the update.
  static Future<void> checkForUpdates(BuildContext context) async {
    try {
      debugPrint('[InAppUpdateService] Initiating update check...');
      final AppUpdateInfo info = await InAppUpdate.checkForUpdate();

      if (info.updateAvailability == UpdateAvailability.updateAvailable) {
        debugPrint('[InAppUpdateService] A new version is available. Starting Flexible update...');
        
        // Start downloading the update in the background
        await InAppUpdate.startFlexibleUpdate();
        
        debugPrint('[InAppUpdateService] Background download complete. Displaying notification SnackBar.');

        if (!context.mounted) return;

        // Notify the user that the download is complete and ready to install
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Update downloaded and ready to install.',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            duration: const Duration(days: 365), // Keep the SnackBar visible until restart is pressed
            backgroundColor: const Color(0xFF0F172A),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            action: SnackBarAction(
              label: 'RESTART',
              textColor: const Color(0xFF3B82F6),
              onPressed: () async {
                try {
                  debugPrint('[InAppUpdateService] Installing update and restarting app...');
                  await InAppUpdate.completeFlexibleUpdate();
                } catch (e) {
                  debugPrint('[InAppUpdateService] Failed to complete flexible update installation: $e');
                }
              },
            ),
          ),
        );
      } else {
        debugPrint('[InAppUpdateService] App is up to date.');
      }
    } catch (e) {
      debugPrint('[InAppUpdateService] Error checking or downloading in-app updates: $e');
    }
  }
}
