import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'dart:convert';
import '../services/api_service.dart';
import '../widgets/glass_card.dart';
import '../widgets/fade_in_slide.dart';

class RegisterScreen extends StatefulWidget {
  final VoidCallback onBackToLogin;
  const RegisterScreen({super.key, required this.onBackToLogin});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  final _fatherNameCtrl = TextEditingController();
  final _studentPhoneCtrl = TextEditingController();
  final _guardianPhoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  String _gender = 'Male';
  String _classNo = '10';
  String _language = 'English';
  bool _passwordVisible = false;
  bool _confirmPasswordVisible = false;
  bool _isLoading = false;
  bool _isJoint = false;

  final _classes = ['9', '10', '11', '12'];
  final _languages = ['Bengali', 'English', 'Both'];
  final _genders = ['Male', 'Female', 'Other'];

  late final AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _dobCtrl.dispose();
    _fatherNameCtrl.dispose();
    _studentPhoneCtrl.dispose();
    _guardianPhoneCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2005, 1, 1),
      firstDate: DateTime(1990),
      lastDate: DateTime.now().subtract(const Duration(days: 365 * 5)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF8B5CF6),
            surface: Color(0xFF1E1B4B),
            onPrimary: Colors.white,
            onSurface: Colors.white,
          ),
          dialogTheme: DialogThemeData(
            backgroundColor: const Color(0xFF0A0F1D),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      _dobCtrl.text = '${picked.day}/${picked.month}/${picked.year}';
    }
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (_passwordCtrl.text != _confirmPasswordCtrl.text) {
      _showError('Passwords do not match');
      return;
    }

    final phone = _studentPhoneCtrl.text.trim();

    // ── Phase 1: Pre-check phone status ───────────────────────────────────
    try {
      final api = ApiService();
      final status = await api.checkPhoneStatus(phone);
      final bool isBlacklisted = status['blacklisted'] == true;
      final int attemptCount =
          (status['attemptCount'] as num?)?.toInt() ?? 0;

      if (!mounted) return;

      // Blocklisted — hard stop, non-dismissable dialog
      if (isBlacklisted || attemptCount >= 5) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            backgroundColor: const Color(0xFF1A0A2E),
            title: const Row(
              children: [
                Icon(Icons.block_rounded, color: Colors.redAccent, size: 26),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Number Blocklisted',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ),
            content: const Text(
              'Your phone number has been permanently blocked due to '
              'repeated rejected registrations.\n\n'
              'Please contact the Administrator to resolve this.',
              style: TextStyle(color: Color(0xFFCBB8FF), height: 1.5),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK',
                    style: TextStyle(
                        color: Colors.redAccent, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
        return;
      }

      // 5th attempt warning — amber dialog
      if (attemptCount == 4) {
        final bool? proceed = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            backgroundColor: const Color(0xFF1A0A2E),
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: Colors.amber, size: 26),
                SizedBox(width: 10),
                Text(
                  'Final Attempt',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            content: const Text(
              'This is your last registration attempt.\n\n'
              'If your registration is rejected again, your phone number '
              'will be permanently blocked and you will need to contact '
              'the Administrator.\n\n'
              'Do you still wish to proceed?',
              style: TextStyle(color: Color(0xFFCBB8FF), height: 1.5),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel',
                    style: TextStyle(
                        color: Color(0xFFCBB8FF), fontWeight: FontWeight.bold)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Proceed Anyway',
                    style: TextStyle(
                        color: Colors.black, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
        );
        if (proceed != true || !mounted) return;
      }
    } catch (_) {
      // Network error during status check — let the backend enforce rules
    }

    // ── Phase 2: Actual registration ──────────────────────────────────────
    setState(() => _isLoading = true);

    try {
      final api = ApiService();
      final response = await api.register({
        'firstName': _firstNameCtrl.text.trim(),
        'lastName': _lastNameCtrl.text.trim(),
        'dateOfBirth': _dobCtrl.text.trim(),
        'gender': _gender,
        'classNo': int.parse(_classNo),
        'language': _language,
        'isJoint': (_classNo == '11' || _classNo == '12') ? _isJoint : false,
        'fatherName': _fatherNameCtrl.text.trim(),
        'studentPhone': _studentPhoneCtrl.text.trim(),
        'guardianPhone': _guardianPhoneCtrl.text.trim(),
        'password': _passwordCtrl.text,
      });

      if (mounted) {
        if (response.statusCode == 200 || response.statusCode == 201) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Registration successful! Please wait for admin approval.',
              ),
              backgroundColor: Colors.green.shade700,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
            ),
          );
          widget.onBackToLogin();
        } else {
          String errMsg = 'Registration failed. Please try again.';
          try {
            final Map<String, dynamic> body = jsonDecode(response.body);
            if (body.containsKey('message')) {
              errMsg = body['message'];
            }
          } catch (_) {}
          _showError(errMsg);
        }
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final labelColor = isDark ? const Color(0xFFD3BBFF) : const Color(0xFF4C1D95);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Animated ambient glowing circles for glassmorphism
          AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              final progress = _animationController.value;
              final angle = progress * 2 * math.pi;

              final dx1 = math.sin(angle) * 45;
              final dy1 = math.cos(angle) * 45;

              final dx2 = math.cos(angle + math.pi / 2) * 55;
              final dy2 = math.sin(angle + math.pi / 2) * 55;

              final dx3 = math.sin(angle + math.pi) * 40;
              final dy3 = math.cos(angle + math.pi) * 40;

              return Stack(
                children: [
                  Positioned(
                    top: -100 + dy1,
                    right: -100 + dx1,
                    child: Container(
                      width: 340,
                      height: 340,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark
                            ? const Color(0xFF0051D5).withValues(alpha: 0.16)
                            : const Color(0xFF0051D5).withValues(alpha: 0.08),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 80 + dy2,
                    left: -100 + dx2,
                    child: Container(
                      width: 360,
                      height: 360,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark
                            ? const Color(0xFFF97316).withValues(alpha: 0.12)
                            : const Color(0xFFF97316).withValues(alpha: 0.06),
                      ),
                    ),
                  ),
                  if (isDark)
                    Positioned(
                      top: 260 + dy3,
                      right: -120 + dx3,
                      child: Container(
                        width: 300,
                        height: 300,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFD946EF).withValues(alpha: 0.09),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
              child: const SizedBox.shrink(),
            ),
          ),
          SafeArea(
          child: Column(
            children: [
              // Clean Glass Custom AppBar
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                     IconButton(
                      icon: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: labelColor,
                        size: 20,
                      ),
                      onPressed: widget.onBackToLogin,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Create Account',
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Personal Information Card
                        FadeInSlide(
                          duration: const Duration(milliseconds: 600),
                          slideOffset: 20,
                          child: GlassCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _sectionTitle('Personal Info'),
                                const SizedBox(height: 20),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _darkField(
                                        'First Name',
                                        _firstNameCtrl,
                                        icon: Icons.person_outline,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _darkField(
                                        'Last Name',
                                        _lastNameCtrl,
                                        icon: Icons.person_outline,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                GestureDetector(
                                  onTap: _pickDate,
                                  child: AbsorbPointer(
                                    child: _darkField(
                                      'Date of Birth',
                                      _dobCtrl,
                                      icon: Icons.calendar_today_rounded,
                                      hint: 'dd/mm/yyyy',
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _darkField(
                                  'Father\'s Name',
                                  _fatherNameCtrl,
                                  icon: Icons.family_restroom_rounded,
                                ),
                                const SizedBox(height: 16),
                                _dropdownField(
                                  'Gender',
                                  _gender,
                                  _genders,
                                  (val) => setState(() => _gender = val!),
                                  icon: Icons.wc_rounded,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Academic Details Card
                        FadeInSlide(
                          duration: const Duration(milliseconds: 600),
                          delay: const Duration(milliseconds: 100),
                          slideOffset: 20,
                          child: GlassCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _sectionTitle('Academic Details'),
                                const SizedBox(height: 20),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _dropdownField(
                                        'Class',
                                        _classNo,
                                        _classes,
                                        (val) => setState(() {
                                          _classNo = val!;
                                          if (_classNo != '11' &&
                                              _classNo != '12') {
                                            _isJoint = false;
                                          }
                                        }),
                                        icon: Icons.class_rounded,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _dropdownField(
                                        'Medium',
                                        _language,
                                        _languages,
                                        (val) =>
                                            setState(() => _language = val!),
                                        icon: Icons.translate_rounded,
                                      ),
                                    ),
                                  ],
                                ),
                                if (_classNo == '11' || _classNo == '12') ...[
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF8B5CF6)
                                          .withValues(alpha: 0.07),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: const Color(0xFF8B5CF6)
                                            .withValues(alpha: 0.2),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.info_outline_rounded,
                                          color: Color(0xFF8B5CF6),
                                          size: 16,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Joint Entrance enrolment can be requested from your profile after your account is approved by the teacher.',
                                            style: TextStyle(
                                              color: const Color(0xFF8B5CF6)
                                                  .withValues(alpha: 0.9),
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              height: 1.4,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Contact & Security Card
                        FadeInSlide(
                          duration: const Duration(milliseconds: 600),
                          delay: const Duration(milliseconds: 150),
                          slideOffset: 20,
                          child: GlassCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _sectionTitle('Contact & Security'),
                                const SizedBox(height: 20),
                                _darkField(
                                  'Student\'s Phone',
                                  _studentPhoneCtrl,
                                  icon: Icons.phone_android_rounded,
                                  keyboardType: TextInputType.phone,
                                  validator: (val) {
                                    if (val == null || val.isEmpty) {
                                      return 'Required';
                                    }
                                    if (val.length != 10) {
                                      return 'Must be 10 digits';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                _darkField(
                                  'Guardian\'s Phone',
                                  _guardianPhoneCtrl,
                                  icon: Icons.phone_in_talk_rounded,
                                  keyboardType: TextInputType.phone,
                                  validator: (val) {
                                    if (val == null || val.isEmpty) {
                                      return 'Required';
                                    }
                                    if (val.length != 10) {
                                      return 'Must be 10 digits';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                _passwordField(
                                  'Password',
                                  _passwordCtrl,
                                  _passwordVisible,
                                  () => setState(
                                    () => _passwordVisible = !_passwordVisible,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _passwordField(
                                  'Confirm Password',
                                  _confirmPasswordCtrl,
                                  _confirmPasswordVisible,
                                  () => setState(
                                    () => _confirmPasswordVisible =
                                        !_confirmPasswordVisible,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Submit Button
                        FadeInSlide(
                          duration: const Duration(milliseconds: 600),
                          delay: const Duration(milliseconds: 200),
                          slideOffset: 20,
                          child: SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: _isLoading
                                ? const Center(
                                    child: CircularProgressIndicator(
                                      color: Color(0xFF8B5CF6),
                                    ),
                                  )
                                : BounceOnTap(
                                    onTap: _register,
                                    child: Container(
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFF8B5CF6),
                                            Color(0xFF4C1D95),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(
                                              0xFF8B5CF6,
                                            ).withValues(alpha: 0.3),
                                            blurRadius: 16,
                                            offset: const Offset(0, 6),
                                          ),
                                        ],
                                      ),
                                      child: const Text(
                                        'Register Account',
                                        style: TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Already have an account? ',
                              style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFFA8A5B8) : const Color(0xFF64748B)),
                            ),
                            TextButton(
                              onPressed: widget.onBackToLogin,
                              style: TextButton.styleFrom(
                                foregroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFFD3BBFF) : const Color(0xFF6D28D9),
                                padding: EdgeInsets.zero,
                              ),
                              child: const Text(
                                'Login',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

  Widget _sectionTitle(String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: isDark ? const Color(0xFFD3BBFF) : const Color(0xFF4C1D95),
            fontWeight: FontWeight.w900,
            fontSize: 15,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        Container(height: 1, color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08)),
      ],
    );
  }

  Widget _darkField(
    String label,
    TextEditingController ctrl, {
    required IconData icon,
    String? hint,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      style: TextStyle(
        color: isDark ? Colors.white : const Color(0xFF0F172A),
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(
          color: isDark ? const Color(0xFFCCC3D4) : const Color(0xFF475569),
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: TextStyle(color: isDark ? Colors.white.withValues(alpha: 0.35) : Colors.black.withValues(alpha: 0.4)),
        prefixIcon: Icon(icon, color: isDark ? const Color(0xFFD3BBFF) : const Color(0xFF4C1D95), size: 20),
        filled: true,
        fillColor: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: isDark ? const Color(0xFF8B5CF6) : const Color(0xFF6D28D9), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
        errorStyle: const TextStyle(color: Colors.redAccent),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      validator:
          validator ??
          (val) => (val == null || val.isEmpty) ? 'Required' : null,
    );
  }

  Widget _passwordField(
    String label,
    TextEditingController ctrl,
    bool visible,
    VoidCallback toggle,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextFormField(
      controller: ctrl,
      obscureText: !visible,
      style: TextStyle(
        color: isDark ? Colors.white : const Color(0xFF0F172A),
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: isDark ? const Color(0xFFCCC3D4) : const Color(0xFF475569),
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: Icon(
          Icons.lock_outline_rounded,
          color: isDark ? const Color(0xFFD3BBFF) : const Color(0xFF4C1D95),
          size: 20,
        ),
        suffixIcon: IconButton(
          icon: Icon(
            visible ? Icons.visibility : Icons.visibility_off,
            color: isDark ? const Color(0xFFD3BBFF) : const Color(0xFF6D28D9),
          ),
          onPressed: toggle,
        ),
        filled: true,
        fillColor: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: isDark ? const Color(0xFF8B5CF6) : const Color(0xFF6D28D9), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
        errorStyle: const TextStyle(color: Colors.redAccent),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      validator: (val) {
        if (val == null || val.isEmpty) return 'Required';
        if (val.length < 6) return 'Minimum 6 characters';
        return null;
      },
    );
  }

  Widget _dropdownField(
    String label,
    String value,
    List<String> options,
    ValueChanged<String?> onChanged, {
    required IconData icon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DropdownButtonFormField<String>(
      initialValue: value,
      onChanged: onChanged,
      dropdownColor: isDark ? const Color(0xFF1E1B4B) : Colors.white,
      style: TextStyle(
        color: isDark ? Colors.white : const Color(0xFF0F172A),
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: isDark ? const Color(0xFFCCC3D4) : const Color(0xFF475569),
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: Icon(icon, color: isDark ? const Color(0xFFD3BBFF) : const Color(0xFF4C1D95), size: 20),
        filled: true,
        fillColor: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: isDark ? const Color(0xFF8B5CF6) : const Color(0xFF6D28D9), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      items: options
          .map((o) => DropdownMenuItem(value: o, child: Text(o)))
          .toList(),
    );
  }
}
