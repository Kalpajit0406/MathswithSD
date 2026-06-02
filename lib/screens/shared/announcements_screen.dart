import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/exam_provider.dart';
import '../../models/test_model.dart';
import '../../widgets/glass_card.dart';

class AnnouncementsScreen extends StatefulWidget {
  final bool isAdmin;
  final String? studentClass; // for filtering

  const AnnouncementsScreen({
    super.key,
    required this.isAdmin,
    this.studentClass,
  });

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ExamProvider>(context, listen: false).loadAnnouncements(
        targetClass: widget.isAdmin ? null : widget.studentClass,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final secondaryTextColor = isDark ? Colors.white60 : Colors.black54;
    final themePrimary = isDark
        ? const Color(0xFF5D9BFF)
        : const Color(0xFF0051D5);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Announcements',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w900,
            fontSize: 22,
            letterSpacing: -0.5,
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: textColor,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: textColor,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Consumer<ExamProvider>(
          builder: (context, provider, _) {
            if (provider.announcementsState == LoadState.loading) {
              return Center(
                child: CircularProgressIndicator(color: themePrimary),
              );
            }
            if (provider.announcementsState == LoadState.error) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: themePrimary.withValues(alpha: 0.04),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: themePrimary.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Icon(
                        Icons.cloud_off_rounded,
                        size: 64,
                        color: secondaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      provider.announcementsError ?? 'Failed to load',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => provider.loadAnnouncements(
                        targetClass: widget.studentClass,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: themePrimary,
                        foregroundColor: isDark ? Colors.black : Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }
            if (provider.announcements.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: themePrimary.withValues(alpha: 0.04),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: themePrimary.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Icon(
                        Icons.notifications_none_rounded,
                        size: 64,
                        color: secondaryTextColor.withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'No announcements yet.',
                      style: TextStyle(
                        color: secondaryTextColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            }
            return RefreshIndicator(
              color: themePrimary,
              backgroundColor: isDark ? const Color(0xFF080C14) : Colors.white,
              onRefresh: () =>
                  provider.loadAnnouncements(targetClass: widget.studentClass),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                itemCount: provider.announcements.length,
                physics: const BouncingScrollPhysics(),
                itemBuilder: (context, i) =>
                    _AnnouncementCard(ann: provider.announcements[i]),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  final Announcement ann;
  const _AnnouncementCard({required this.ann});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final secondaryTextColor = isDark ? Colors.white60 : Colors.black45;
    final themePrimary = isDark
        ? const Color(0xFF5D9BFF)
        : const Color(0xFF0051D5);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: GlassCard(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image if available
            if (ann.image != null && ann.image!.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                child: Image.network(
                  ann.image!,
                  width: double.infinity,
                  height: 180,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Class chip
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: themePrimary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(50),
                          border: Border.all(
                            color: themePrimary.withValues(alpha: 0.15),
                            width: 1.2,
                          ),
                        ),
                        child: Text(
                          ann.targetClass == 'all'
                              ? 'All Classes'
                              : 'Class ${ann.targetClass}',
                          style: TextStyle(
                            color: isDark ? themePrimary : Colors.black,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.schedule_rounded,
                        size: 14,
                        color: secondaryTextColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        ann.formattedDate,
                        style: TextStyle(
                          color: secondaryTextColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    ann.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      color: textColor,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    ann.message,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white70 : Colors.black87,
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 5,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
