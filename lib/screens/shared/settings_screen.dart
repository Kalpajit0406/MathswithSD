import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/storage_service.dart';
import '../../utils/constants.dart';
import '../../widgets/glass_card.dart';
import '../../services/kiosk_service.dart';
import '../../providers/theme_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _baseUrlController;
  String? _currentOverride;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _baseUrlController = TextEditingController();
    _loadCurrentBaseUrl();
  }

  Future<void> _loadCurrentBaseUrl() async {
    try {
      final override = await AuthStorageService.getBaseUrlOverride();
      setState(() {
        _currentOverride = override;
        _baseUrlController.text = override ?? AppConstants.baseUrl;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading settings: $e')));
    }
  }

  Future<void> _saveBaseUrl() async {
    try {
      final url = _baseUrlController.text.trim();
      if (url.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Base URL cannot be empty')),
        );
        return;
      }
      await AuthStorageService.saveBaseUrlOverride(url);
      if (!mounted) return;
      setState(() => _currentOverride = url);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Base URL saved. Restart app to apply.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error saving base URL: $e')));
    }
  }

  Future<void> _clearOverride() async {
    try {
      await AuthStorageService.saveBaseUrlOverride('');
      if (!mounted) return;
      setState(() {
        _currentOverride = null;
        _baseUrlController.text = AppConstants.baseUrl;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Override cleared. Using default URL.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error clearing override: $e')));
    }
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final textColor = isDark ? Colors.white : Colors.black;
    final secondaryTextColor = isDark ? Colors.white60 : Colors.black54;
    final borderColor = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFECEEF0);
    final containerFillColor = isDark
        ? const Color(0xFF1E293B)
        : const Color(0xFFF8FAFC);

    if (_loading) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            'Settings',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: textColor,
              fontSize: 22,
              letterSpacing: -0.5,
            ),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: textColor,
          actions: [
            IconButton(
              icon: const Icon(
                Icons.exit_to_app_rounded,
                color: Colors.redAccent,
              ),
              tooltip: 'Exit App',
              onPressed: () => KioskService.showExitDialog(context),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFF0051D5)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          'Settings',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: textColor,
            fontSize: 22,
            letterSpacing: -0.5,
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: textColor,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.exit_to_app_rounded,
              color: Colors.redAccent,
            ),
            tooltip: 'Exit App',
            onPressed: () => KioskService.showExitDialog(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20.0),
        child: GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'API Base URL Configuration',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: textColor,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Default: ${AppConstants.baseUrl}',
                style: TextStyle(
                  fontSize: 12,
                  color: secondaryTextColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Manual Override (optional)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _baseUrlController,
                style: TextStyle(
                  color: textColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  labelText: 'Base URL',
                  labelStyle: TextStyle(
                    color: secondaryTextColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  hintText: 'e.g., http://192.168.1.5:5000',
                  hintStyle: TextStyle(
                    color: isDark ? Colors.white30 : Colors.black38,
                  ),
                  prefixIcon: const Icon(
                    Icons.link_rounded,
                    color: Color(0xFF0051D5),
                  ),
                  filled: true,
                  fillColor: containerFillColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: Color(0xFF0051D5),
                      width: 1.5,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saveBaseUrl,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0051D5),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Save Override',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _clearOverride,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: textColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: borderColor),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        backgroundColor: Colors.transparent,
                      ),
                      child: const Text(
                        'Clear Override',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Theme selector UI
              Text(
                'App Theme Mode',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _ThemeOptionCard(
                      title: 'Light Mode',
                      icon: Icons.light_mode_rounded,
                      isActive: themeProvider.themeMode == ThemeMode.light,
                      onTap: () => themeProvider.setThemeMode(ThemeMode.light),
                      textColor: textColor,
                      borderColor: borderColor,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _ThemeOptionCard(
                      title: 'Dark Mode',
                      icon: Icons.dark_mode_rounded,
                      isActive: themeProvider.themeMode == ThemeMode.dark,
                      onTap: () => themeProvider.setThemeMode(ThemeMode.dark),
                      textColor: textColor,
                      borderColor: borderColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              Text(
                'Current Status',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: containerFillColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Using: ${_currentOverride ?? AppConstants.baseUrl}',
                      style: TextStyle(
                        fontSize: 13,
                        color: textColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _currentOverride == null
                                ? const Color(0xFF10B981)
                                : const Color(0xFFF59E0B),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _currentOverride == null
                              ? 'Default URL active'
                              : 'Custom override active',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _currentOverride == null
                                ? const Color(0xFF10B981)
                                : const Color(0xFFF59E0B),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemeOptionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;
  final Color textColor;
  final Color borderColor;

  const _ThemeOptionCard({
    required this.title,
    required this.icon,
    required this.isActive,
    required this.onTap,
    required this.textColor,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFF0051D5).withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? const Color(0xFF0051D5) : borderColor,
            width: isActive ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isActive
                  ? const Color(0xFF0051D5)
                  : (textColor.withValues(alpha: 0.6)),
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: isActive ? const Color(0xFF0051D5) : textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
