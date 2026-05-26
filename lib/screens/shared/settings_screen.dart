import 'package:flutter/material.dart';
import '../../services/storage_service.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import '../../widgets/glass_card.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading settings: $e')),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving base URL: $e')),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error clearing override: $e')),
      );
    }
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Settings'),
          elevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6))),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 22, letterSpacing: -0.5),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20.0),
        child: GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'API Base URL Configuration',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.3),
              ),
              const SizedBox(height: 6),
              Text(
                'Default: ${AppConstants.baseUrl}',
                style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.45), fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 24),
              const Text(
                'Manual Override (optional)',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFFD3BBFF)),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _baseUrlController,
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  labelText: 'Base URL',
                  labelStyle: const TextStyle(color: Color(0xFFCCC3D4), fontSize: 13, fontWeight: FontWeight.w500),
                  hintText: 'e.g., http://192.168.1.5:5000',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.25)),
                  prefixIcon: const Icon(Icons.link_rounded, color: Color(0xFFD3BBFF)),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.04),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFF8B5CF6), width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saveBaseUrl,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B5CF6),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Save Override', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _clearOverride,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFD3BBFF),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: const Color(0xFF8B5CF6).withOpacity(0.4)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        backgroundColor: Colors.white.withOpacity(0.04),
                      ),
                      child: const Text('Clear Override', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              const Text(
                'Current Status',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFFD3BBFF)),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Using: ${_currentOverride ?? AppConstants.baseUrl}',
                      style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _currentOverride == null ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
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
                            color: _currentOverride == null ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
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
