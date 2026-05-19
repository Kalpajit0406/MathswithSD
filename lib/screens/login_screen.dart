import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../utils/constants.dart';
import '../../widgets/fade_in_slide.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onNavigateToRegister;
  const LoginScreen({super.key, required this.onNavigateToRegister});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _passwordVisible = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.login(_phoneController.text.trim(), _passwordController.text);
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage ?? 'Login failed'),
          backgroundColor: const Color(0xFFBA1A1A),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Deep Academic Blue theme
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Logo / Branding with elegant slide
                    Center(
                      child: FadeInSlide(
                        duration: const Duration(milliseconds: 700),
                        slideOffset: 30,
                        child: Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF0051D5), Color(0xFF316BF3)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0051D5).withOpacity(0.35),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              )
                            ],
                          ),
                          child: const Icon(Icons.school_rounded, color: Colors.white, size: 44),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    
                    Center(
                      child: FadeInSlide(
                        duration: const Duration(milliseconds: 700),
                        delay: const Duration(milliseconds: 100),
                        slideOffset: 20,
                        child: const Text(
                          'MathsWithSD',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    
                    Center(
                      child: FadeInSlide(
                        duration: const Duration(milliseconds: 700),
                        delay: const Duration(milliseconds: 150),
                        slideOffset: 15,
                        child: const Text(
                          'Sign in to your student academy portal',
                          style: TextStyle(
                            color: Color(0xFF75859D),
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 48),

                    // Phone Field with slide-up
                    FadeInSlide(
                      duration: const Duration(milliseconds: 650),
                      delay: const Duration(milliseconds: 200),
                      slideOffset: 24,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('Mobile Number'),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                            decoration: _inputDecoration(
                              hint: 'Enter your 10-digit number',
                              icon: Icons.phone_android_rounded,
                            ),
                            validator: (val) {
                              if (val == null || val.isEmpty) return 'Phone number is required';
                              if (val.length < 10) return 'Enter a valid 10-digit number';
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Password Field with slide-up
                    FadeInSlide(
                      duration: const Duration(milliseconds: 650),
                      delay: const Duration(milliseconds: 250),
                      slideOffset: 24,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('Account Password'),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: !_passwordVisible,
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                            decoration: _inputDecoration(
                              hint: 'Enter your account password',
                              icon: Icons.lock_outline_rounded,
                              suffix: IconButton(
                                icon: Icon(
                                  _passwordVisible ? Icons.visibility : Icons.visibility_off,
                                  color: const Color(0xFF75859D),
                                ),
                                onPressed: () => setState(() => _passwordVisible = !_passwordVisible),
                              ),
                            ),
                            validator: (val) {
                              if (val == null || val.isEmpty) return 'Password is required';
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 36),

                    // Login Button
                    FadeInSlide(
                      duration: const Duration(milliseconds: 650),
                      delay: const Duration(milliseconds: 300),
                      slideOffset: 24,
                      child: SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: auth.status == AuthStatus.loading
                            ? const Center(
                                child: CircularProgressIndicator(
                                  color: Color(0xFF0051D5),
                                ),
                              )
                            : BounceOnTap(
                                onTap: _login,
                                child: Container(
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF0051D5), Color(0xFF316BF3)],
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF0051D5).withOpacity(0.3),
                                        blurRadius: 16,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: const Text(
                                    'Sign In',
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
                    const SizedBox(height: 28),

                    // Register Link
                    FadeInSlide(
                      duration: const Duration(milliseconds: 650),
                      delay: const Duration(milliseconds: 350),
                      slideOffset: 20,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            "New to MathsWithSD? ",
                            style: TextStyle(color: Color(0xFF75859D), fontSize: 15, fontWeight: FontWeight.w500),
                          ),
                          TextButton(
                            onPressed: widget.onNavigateToRegister,
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF0051D5),
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              'Create Account',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF75859D),
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF4A5568), fontWeight: FontWeight.w500),
      prefixIcon: Icon(icon, color: const Color(0xFF0051D5), size: 20),
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFF1E293B), // Sleek slate container
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF334155)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF334155)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF0051D5), width: 1.5),
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    );
  }
}
