import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/exam_provider.dart';
import '../../models/test_model.dart';
import '../../widgets/glass_card.dart';

class AnnouncementsScreen extends StatefulWidget {
  final bool isAdmin;
  final String? studentClass; // for filtering

  const AnnouncementsScreen({super.key, required this.isAdmin, this.studentClass});

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ExamProvider>(context, listen: false)
          .loadAnnouncements(targetClass: widget.isAdmin ? null : widget.studentClass);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0A0F1D), Color(0xFF1E1B4B)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Custom Glass AppBar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFFD3BBFF), size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Announcements',
                      style: TextStyle(
                        color: Colors.white,
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
                    if (provider.announcementsState == LoadState.loading) {
                      return const Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6)));
                    }
                    if (provider.announcementsState == LoadState.error) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.04),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white.withOpacity(0.08)),
                              ),
                              child: const Icon(Icons.cloud_off_rounded, size: 64, color: Color(0xFFA8A5B8)),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              provider.announcementsError ?? 'Failed to load',
                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: () => provider.loadAnnouncements(targetClass: widget.studentClass),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF8B5CF6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Retry', style: TextStyle(color: Colors.white)),
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
                                color: Colors.white.withOpacity(0.04),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white.withOpacity(0.08)),
                              ),
                              child: Icon(Icons.notifications_none_rounded, size: 64, color: Colors.white.withOpacity(0.25)),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'No announcements yet.',
                              style: TextStyle(color: Color(0xFFCCC3D4), fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      );
                    }
                    return RefreshIndicator(
                      color: const Color(0xFF8B5CF6),
                      backgroundColor: const Color(0xFF1E1B4B),
                      onRefresh: () => provider.loadAnnouncements(targetClass: widget.studentClass),
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        itemCount: provider.announcements.length,
                        physics: const BouncingScrollPhysics(),
                        itemBuilder: (context, i) => _AnnouncementCard(ann: provider.announcements[i]),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
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
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                child: Image.network(
                  ann.image!,
                  width: double.infinity,
                  height: 180,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
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
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(50),
                          border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.25), width: 1.2),
                        ),
                        child: Text(
                          ann.targetClass == 'all' ? 'All Classes' : 'Class ${ann.targetClass}',
                          style: const TextStyle(
                            color: Color(0xFFD3BBFF),
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Icon(Icons.schedule_rounded, size: 14, color: Colors.white.withOpacity(0.4)),
                      const SizedBox(width: 6),
                      Text(
                        ann.formattedDate,
                        style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    ann.title,
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.white, letterSpacing: -0.3),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    ann.message,
                    style: const TextStyle(fontSize: 14, color: Color(0xFFCCC3D4), height: 1.5, fontWeight: FontWeight.w500),
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
