import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/admin_provider.dart';
import '../../models/test_model.dart';

class YourTestsScreen extends StatefulWidget {
  const YourTestsScreen({super.key});

  @override
  State<YourTestsScreen> createState() => _YourTestsScreenState();
}

class _YourTestsScreenState extends State<YourTestsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AdminProvider>(context, listen: false).loadTests();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFE91E63),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Your Tests', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        elevation: 0,
      ),
      body: Consumer<AdminProvider>(
        builder: (context, provider, _) {
          if (provider.testsState == LoadState.loading) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFE91E63)));
          }
          if (provider.testsState == LoadState.error) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.cloud_off, size: 72, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(provider.testsError ?? 'Failed to load tests', style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => provider.loadTests(),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE91E63)),
                    child: const Text('Retry', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            );
          }
          if (provider.tests.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.fact_check_outlined, size: 80, color: Colors.grey.shade200),
                  const SizedBox(height: 16),
                  const Text('No tests created yet.', style: TextStyle(color: Colors.grey, fontSize: 16)),
                ],
              ),
            );
          }
          return RefreshIndicator(
            color: const Color(0xFFE91E63),
            onRefresh: () => provider.loadTests(),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: provider.tests.length,
              itemBuilder: (context, i) => _TestCard(test: provider.tests[i]),
            ),
          );
        },
      ),
    );
  }
}

class _TestCard extends StatelessWidget {
  final TestConfig test;
  const _TestCard({required this.test});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 3,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFFFCE4EC),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.fact_check, color: Color(0xFFE91E63), size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Class ${test.classNo} • ${test.language}',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Date: ${test.date}  |  Time: ${test.time}',
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${test.totalQuestions} Questions  •  ${test.totalTime} Mins',
                    style: const TextStyle(
                      color: Color(0xFFE91E63),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
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
