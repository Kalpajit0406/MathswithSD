import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/constants.dart';
import 'api_service.dart';

class AppVersionInfo {
  final String currentVersion;
  final int currentBuildNumber;
  final String latestVersion;
  final int latestBuildNumber;
  final String minRequiredVersion;
  final int minRequiredBuildNumber;
  final bool isForceUpdate;
  final bool isUpdateAvailable;
  final String updateUrl;
  final String releaseNotes;

  AppVersionInfo({
    required this.currentVersion,
    required this.currentBuildNumber,
    required this.latestVersion,
    required this.latestBuildNumber,
    required this.minRequiredVersion,
    required this.minRequiredBuildNumber,
    required this.isForceUpdate,
    required this.isUpdateAvailable,
    required this.updateUrl,
    required this.releaseNotes,
  });
}

class InAppUpdateService {
  static bool _isForceUpdateShowing = false;

  /// Retrieves local package version info along with remote version status from backend
  static Future<AppVersionInfo> getAppVersionInfo() async {
    String currentVersion = AppConstants.appVersion;
    int currentBuildNumber = AppConstants.appBuildNumber;

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (packageInfo.version.isNotEmpty) {
        currentVersion = packageInfo.version;
      }
      final parsedBuild = int.tryParse(packageInfo.buildNumber);
      if (parsedBuild != null && parsedBuild > 0) {
        currentBuildNumber = parsedBuild;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[InAppUpdateService] Error reading PackageInfo: $e');
    }

    String latestVersion = currentVersion;
    int latestBuildNumber = currentBuildNumber;
    String minRequiredVersion = currentVersion;
    int minRequiredBuildNumber = currentBuildNumber;
    bool forceUpdateFlag = false;
    String updateUrl = AppConstants.playStoreUrl;
    String releaseNotes = 'Important performance and stability improvements.';

    try {
      final baseUrl = ApiService().baseUrl;
      final response = await http
          .get(Uri.parse('$baseUrl${AppConstants.appVersionEndpoint}'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          latestVersion = data['latestVersion']?.toString() ?? currentVersion;
          latestBuildNumber = (data['latestBuildNumber'] as num?)?.toInt() ?? currentBuildNumber;
          minRequiredVersion = data['minRequiredVersion']?.toString() ?? currentVersion;
          minRequiredBuildNumber = (data['minRequiredBuildNumber'] as num?)?.toInt() ?? currentBuildNumber;
          forceUpdateFlag = data['forceUpdate'] == true;
          if (data['updateUrl'] != null && data['updateUrl'].toString().isNotEmpty) {
            updateUrl = data['updateUrl'].toString();
          }
          if (data['releaseNotes'] != null && data['releaseNotes'].toString().isNotEmpty) {
            releaseNotes = data['releaseNotes'].toString();
          }
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[InAppUpdateService] Backend version check error: $e');
    }

    final bool isForceUpdateRequired = forceUpdateFlag || (currentBuildNumber < minRequiredBuildNumber);
    final bool isUpdateAvailable = isForceUpdateRequired || (currentBuildNumber < latestBuildNumber);

    return AppVersionInfo(
      currentVersion: currentVersion,
      currentBuildNumber: currentBuildNumber,
      latestVersion: latestVersion,
      latestBuildNumber: latestBuildNumber,
      minRequiredVersion: minRequiredVersion,
      minRequiredBuildNumber: minRequiredBuildNumber,
      isForceUpdate: isForceUpdateRequired,
      isUpdateAvailable: isUpdateAvailable,
      updateUrl: updateUrl,
      releaseNotes: releaseNotes,
    );
  }

  /// Main method called at app launch and from Settings screen to check for updates.
  /// If a force update is required, it activates Play Store Immediate Update and shows an un-dismissible UI.
  static Future<void> checkForUpdates(BuildContext context, {bool manualCheck = false}) async {
    try {
      if (kDebugMode) debugPrint('[InAppUpdateService] Checking for app updates...');

      final versionInfo = await getAppVersionInfo();

      // 1. Google Play Store Native Update Check
      AppUpdateInfo? playUpdateInfo;
      try {
        playUpdateInfo = await InAppUpdate.checkForUpdate();
      } catch (e) {
        if (kDebugMode) debugPrint('[InAppUpdateService] Play Store in-app update check unavailable: $e');
      }

      final bool playUpdateAvailable = playUpdateInfo?.updateAvailability == UpdateAvailability.updateAvailable;
      final bool requiresForceUpdate = versionInfo.isForceUpdate || (playUpdateAvailable && playUpdateInfo?.immediateUpdateAllowed == true);
      final bool hasNewVersion = versionInfo.isUpdateAvailable || playUpdateAvailable;

      if (requiresForceUpdate) {
        if (kDebugMode) debugPrint('[InAppUpdateService] Force update required! Displaying forced update dialog...');

        // Attempt Google Play Store immediate update if supported
        if (playUpdateInfo != null && playUpdateInfo.immediateUpdateAllowed) {
          try {
            await InAppUpdate.performImmediateUpdate();
            return;
          } catch (e) {
            if (kDebugMode) debugPrint('[InAppUpdateService] Play Store immediate update failed: $e');
          }
        }

        // Display non-dismissible Force Update Dialog
        if (context.mounted) {
          showForceUpdateDialog(context, versionInfo);
        }
        return;
      }

      if (hasNewVersion) {
        if (playUpdateInfo != null && playUpdateInfo.flexibleUpdateAllowed) {
          try {
            await InAppUpdate.startFlexibleUpdate();
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('New update downloaded and ready to install.'),
                action: SnackBarAction(
                  label: 'RESTART',
                  textColor: const Color(0xFF3B82F6),
                  onPressed: () => InAppUpdate.completeFlexibleUpdate(),
                ),
              ),
            );
            return;
          } catch (e) {
            if (kDebugMode) debugPrint('[InAppUpdateService] Flexible update failed: $e');
          }
        }

        if (context.mounted) {
          showForceUpdateDialog(context, versionInfo, isMandatory: false);
        }
      } else if (manualCheck) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Your app is up to date (v${versionInfo.currentVersion}).',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[InAppUpdateService] Error checking for updates: $e');
      if (manualCheck && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to check for updates: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  /// Launches the Play Store or external APK update URL
  static Future<void> launchUpdateUrl(String urlStr) async {
    try {
      final uri = Uri.parse(urlStr.isNotEmpty ? urlStr : AppConstants.playStoreUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (kDebugMode) debugPrint('[InAppUpdateService] Cannot launch URL: $uri');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[InAppUpdateService] Error launching update URL: $e');
    }
  }

  /// Displays the Force Update modal dialog. If [isMandatory] is true, the dialog is non-dismissible.
  static void showForceUpdateDialog(BuildContext context, AppVersionInfo info, {bool isMandatory = true}) {
    if (_isForceUpdateShowing) return;
    _isForceUpdateShowing = true;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final secondaryTextColor = isDark ? Colors.white70 : const Color(0xFF475569);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;

    showDialog(
      context: context,
      barrierDismissible: !isMandatory,
      builder: (BuildContext dialogContext) {
        return PopScope(
          canPop: !isMandatory,
          child: Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            backgroundColor: cardBg,
            elevation: 16,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0051D5).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF0051D5).withValues(alpha: 0.25),
                        width: 1.5,
                      ),
                    ),
                    child: const Icon(
                      Icons.system_update_rounded,
                      color: Color(0xFF0051D5),
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    isMandatory ? 'Update Required' : 'New Version Available!',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: textColor,
                      letterSpacing: -0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isMandatory
                        ? 'A mandatory new version of MathsWithSD is available. Please update to continue using the app.'
                        : 'A new version of MathsWithSD is available with improved features and stability.',
                    style: TextStyle(
                      fontSize: 13,
                      color: secondaryTextColor,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            Text(
                              'Installed',
                              style: TextStyle(fontSize: 11, color: secondaryTextColor),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'v${info.currentVersion}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: textColor,
                              ),
                            ),
                          ],
                        ),
                        Icon(Icons.arrow_forward_rounded, size: 16, color: secondaryTextColor),
                        Column(
                          children: [
                            Text(
                              'Latest',
                              style: TextStyle(fontSize: 11, color: secondaryTextColor),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'v${info.latestVersion}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF10B981),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (info.releaseNotes.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'What\'s New:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: textColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        info.releaseNotes,
                        style: TextStyle(
                          fontSize: 12,
                          color: secondaryTextColor,
                          height: 1.3,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () async {
                        try {
                          await InAppUpdate.performImmediateUpdate();
                        } catch (_) {
                          await launchUpdateUrl(info.updateUrl);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0051D5),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.download_rounded, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Update Now',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (!isMandatory) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () {
                        _isForceUpdateShowing = false;
                        Navigator.of(dialogContext).pop();
                      },
                      child: Text(
                        'Later',
                        style: TextStyle(
                          color: secondaryTextColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    ).then((_) {
      _isForceUpdateShowing = false;
    });
  }
}
