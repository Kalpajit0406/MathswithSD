import 'package:flutter/material.dart';
import '../services/connectivity_manager.dart';
import '../services/sync_manager.dart';

/// Widget that displays offline status and sync progress
class OfflineIndicator extends StatefulWidget {
  final Widget child;
  final bool showSyncStatus;

  const OfflineIndicator({
    required this.child,
    this.showSyncStatus = true,
    super.key,
  });

  @override
  State<OfflineIndicator> createState() => _OfflineIndicatorState();
}

class _OfflineIndicatorState extends State<OfflineIndicator> {
  late ConnectivityManager _connectivityManager;
  late SyncManager _syncManager;
  bool _isOnline = true;

  @override
  void initState() {
    super.initState();
    _connectivityManager = ConnectivityManager();
    _syncManager = SyncManager();
    _connectivityManager.initialize().then((_) {
      if (mounted) {
        setState(() {
          _isOnline = _connectivityManager.isOnline;
        });
      }
    });
    _syncManager.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<dynamic>(
      stream: _connectivityManager.statusChanges,
      builder: (context, snapshot) {
        final isOnline = _connectivityManager.isOnline;
        
        return Stack(
          children: [
            widget.child,
            // Offline banner
            if (!isOnline)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Material(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: const BoxDecoration(
                      color: Color(0xFFBA1A1A),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0xFFBA1A1A),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.cloud_off_rounded, color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'You\'re offline • Changes saved locally',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (widget.showSyncStatus)
                          StreamBuilder<dynamic>(
                            stream: _syncManager.statusStream,
                            builder: (context, syncSnapshot) {
                              final syncStatus = _syncManager.syncStatus;
                              if (syncStatus.toString().contains('syncing')) {
                                return const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Widget showing sync status with action buttons
class SyncStatusWidget extends StatefulWidget {
  final VoidCallback? onSync;
  final VoidCallback? onDismiss;

  const SyncStatusWidget({
    this.onSync,
    this.onDismiss,
    super.key,
  });

  @override
  State<SyncStatusWidget> createState() => _SyncStatusWidgetState();
}

class _SyncStatusWidgetState extends State<SyncStatusWidget> {
  late SyncManager _syncManager;

  @override
  void initState() {
    super.initState();
    _syncManager = SyncManager();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<dynamic>(
      stream: _syncManager.statusStream,
      builder: (context, snapshot) {
        final syncStatus = _syncManager.syncStatus;
        final syncError = _syncManager.syncError;
        final syncedCount = _syncManager.syncedCount;

        if (syncStatus.toString().contains('idle')) {
          return const SizedBox.shrink();
        }

        Color backgroundColor;
        Color textColor;
        IconData icon;
        String message;

        if (syncStatus.toString().contains('syncing')) {
          backgroundColor = const Color(0xFF2196F3).withOpacity(0.1);
          textColor = const Color(0xFF2196F3);
          icon = Icons.sync_rounded;
          message = 'Syncing offline changes...';
        } else if (syncStatus.toString().contains('success')) {
          backgroundColor = const Color(0xFF4CAF50).withOpacity(0.1);
          textColor = const Color(0xFF4CAF50);
          icon = Icons.check_circle_rounded;
          message = '$syncedCount exam(s) synced successfully! ✓';
        } else {
          backgroundColor = const Color(0xFFBA1A1A).withOpacity(0.1);
          textColor = const Color(0xFFBA1A1A);
          icon = Icons.error_rounded;
          message = syncError ?? 'Sync error occurred';
        }

        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: textColor.withOpacity(0.3), width: 1),
          ),
          child: Row(
            children: [
              if (syncStatus.toString().contains('syncing'))
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(textColor),
                  ),
                )
              else
                Icon(icon, color: textColor, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              if (widget.onDismiss != null && !syncStatus.toString().contains('syncing'))
                IconButton(
                  onPressed: widget.onDismiss,
                  icon: Icon(Icons.close_rounded, color: textColor, size: 18),
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.only(left: 8),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Widget showing offline exam status
class OfflineExamStatusBadge extends StatelessWidget {
  final String examId;
  final bool isDownloaded;
  final bool isPending;
  final bool isSynced;

  const OfflineExamStatusBadge({
    required this.examId,
    this.isDownloaded = false,
    this.isPending = false,
    this.isSynced = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    String label;
    Color backgroundColor;
    Color textColor;
    IconData icon;

    if (isSynced) {
      label = 'Synced';
      backgroundColor = const Color(0xFF4CAF50).withOpacity(0.1);
      textColor = const Color(0xFF4CAF50);
      icon = Icons.check_circle_rounded;
    } else if (isPending) {
      label = 'Pending Sync';
      backgroundColor = const Color(0xFFFFC107).withOpacity(0.1);
      textColor = const Color(0xFFFFC107);
      icon = Icons.cloud_upload_rounded;
    } else if (isDownloaded) {
      label = 'Downloaded';
      backgroundColor = const Color(0xFF2196F3).withOpacity(0.1);
      textColor = const Color(0xFF2196F3);
      icon = Icons.download_done_rounded;
    } else {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: textColor.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: textColor, size: 14),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
