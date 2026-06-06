import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/user_model.dart';
import '../../widgets/glass_card.dart';
import '../../services/kiosk_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isEditing = false;
  bool _isSaving = false;
  int? _selectedClassNo;
  String? _selectedLanguage;
  bool _selectedIsJoint = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AuthProvider>(context, listen: false).refreshProfile();
    });
  }

  void _startEditing(AppUser user) {
    setState(() {
      _isEditing = true;
      _selectedClassNo = user.classNo;
      _selectedLanguage = user.language ?? 'English';
      _selectedIsJoint = user.isJoint ?? false;
    });
  }

  /// Returns true only when the student has actually changed at least one field.
  bool get _hasChanges {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.user;
    if (user == null) return false;

    final originalClass = user.classNo;
    final originalLanguage = user.language ?? 'English';
    // isJoint is only meaningful for class 11/12; treat it as false otherwise.
    final originalIsJoint =
        (originalClass == 11 || originalClass == 12) ? (user.isJoint ?? false) : false;
    final effectiveIsJoint =
        (_selectedClassNo == 11 || _selectedClassNo == 12) ? _selectedIsJoint : false;

    return _selectedClassNo != originalClass ||
        _selectedLanguage != originalLanguage ||
        effectiveIsJoint != originalIsJoint;
  }

  Future<void> _saveChanges(AuthProvider auth) async {
    if (_selectedClassNo == null || _selectedLanguage == null) return;
    
    setState(() {
      _isSaving = true;
    });

    final success = await auth.updateProfileRequest(
      _selectedClassNo!,
      _selectedLanguage!,
      isJoint: (_selectedClassNo == 11 || _selectedClassNo == 12) ? _selectedIsJoint : false,
    );

    if (mounted) {
      setState(() {
        _isSaving = false;
      });

      if (success) {
        setState(() {
          _isEditing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Edit request submitted to teacher for approval.'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(auth.errorMessage ?? 'Failed to submit edit request.'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.user;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final secondaryTextColor = isDark ? Colors.white60 : Colors.black54;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFECEEF0);
    final themePrimary = isDark ? const Color(0xFF5D9BFF) : const Color(0xFF0051D5);
    
    final hasPendingEdit = user?.pendingProfileEdit != null;
    final pendingClass = user?.pendingProfileEdit?['classNo'];
    final pendingLanguage = user?.pendingProfileEdit?['language'];
    final pendingIsJoint = user?.pendingProfileEdit?['isJoint'] == true;

    String getPendingClassDisplay() {
      if (pendingClass == null) return 'N/A';
      if (pendingIsJoint && (pendingClass == 11 || pendingClass == 12)) {
        return '$pendingClass Joint';
      }
      return pendingClass.toString();
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          'My Profile',
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
            icon: const Icon(Icons.exit_to_app_rounded, color: Colors.redAccent),
            tooltip: 'Exit App',
            onPressed: () => KioskService.showExitDialog(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Center(
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: themePrimary.withValues(alpha: 0.2), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: themePrimary.withValues(alpha: 0.05),
                      blurRadius: 16,
                    )
                  ],
                ),
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  child: Icon(Icons.person_rounded, size: 50, color: themePrimary),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              user?.fullName ?? 'Student',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: textColor,
                letterSpacing: -0.5,
              ),
            ),
            if (user?.role != null) ...[
              const SizedBox(height: 6),
              Text(
                user!.role!.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: themePrimary,
                  letterSpacing: 1.0,
                ),
              ),
            ],
            const SizedBox(height: 24),

            // Pending Approval Banner
            if (hasPendingEdit) ...[
              GlassCard(
                color: Colors.amber.withValues(alpha: isDark ? 0.15 : 0.08),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.pending_actions_rounded, color: Colors.amber, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Pending Teacher Approval',
                            style: TextStyle(fontWeight: FontWeight.w800, color: Colors.amber, fontSize: 14),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Requested Class: ${getPendingClassDisplay()} • Medium: $pendingLanguage',
                            style: TextStyle(color: secondaryTextColor, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Profile info cards
            if (!_isEditing) ...[
              GlassCard(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Column(
                  children: [
                    _profileItem(Icons.person_outline_rounded, 'Full Name', user?.fullName ?? 'N/A', textColor, secondaryTextColor, borderColor, themePrimary, isLocked: true),
                    _divider(borderColor),
                    _profileItem(Icons.phone_outlined, 'Phone Number', user?.phone ?? 'N/A', textColor, secondaryTextColor, borderColor, themePrimary, isLocked: true),
                    _divider(borderColor),
                    _profileItem(Icons.family_restroom_outlined, 'Father\'s Name', user?.fatherName ?? 'Not provided', textColor, secondaryTextColor, borderColor, themePrimary, isLocked: true),
                    _divider(borderColor),
                    _profileItem(
                      Icons.class_outlined,
                      'Class',
                      user?.classNo != null
                          ? 'Class ${user!.classNo}${user.isJoint == true ? ' Joint' : ''}'
                          : 'N/A',
                      textColor,
                      secondaryTextColor,
                      borderColor,
                      themePrimary,
                    ),
                    if (user?.classNo == 11 || user?.classNo == 12) ...[
                      _divider(borderColor),
                      _profileItem(
                        Icons.school_outlined,
                        'Joint Entrance',
                        user?.isJoint == true ? 'Enrolled' : 'Not Enrolled',
                        textColor,
                        secondaryTextColor,
                        borderColor,
                        themePrimary,
                      ),
                    ],
                    _divider(borderColor),
                    _profileItem(Icons.translate_outlined, 'Medium', user?.language ?? 'English', textColor, secondaryTextColor, borderColor, themePrimary),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              
              if (!hasPendingEdit)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _startEditing(user!),
                    icon: const Icon(Icons.edit_outlined, color: Colors.white),
                    label: const Text('Edit Class & Medium', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: themePrimary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor),
                    ),
                    child: Text(
                      'Request Pending Approval',
                      style: TextStyle(color: secondaryTextColor, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
            ] else ...[
              // Edit Mode UI
              GlassCard(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Edit Details',
                      style: TextStyle(fontWeight: FontWeight.w900, color: textColor, fontSize: 18),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'You can request a change for Class and Medium. These changes will require teacher approval to finalize.',
                      style: TextStyle(color: secondaryTextColor, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 24),

                    // Dropdown for Class
                    Text('Select Class', style: TextStyle(color: secondaryTextColor, fontWeight: FontWeight.w800, fontSize: 13)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderColor),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: _selectedClassNo,
                          isExpanded: true,
                          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                          style: TextStyle(color: textColor, fontWeight: FontWeight.w700),
                          items: const [
                            DropdownMenuItem(value: 9, child: Text('Class 9')),
                            DropdownMenuItem(value: 10, child: Text('Class 10')),
                            DropdownMenuItem(value: 11, child: Text('Class 11')),
                            DropdownMenuItem(value: 12, child: Text('Class 12')),
                          ],
                          onChanged: (val) {
                            setState(() {
                              _selectedClassNo = val;
                              if (_selectedClassNo != 11 && _selectedClassNo != 12) {
                                _selectedIsJoint = false;
                              }
                            });
                          },
                        ),
                      ),
                    ),
                    if (_selectedClassNo == 11 || _selectedClassNo == 12) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          SizedBox(
                            height: 24,
                            width: 24,
                            child: Checkbox(
                              value: _selectedIsJoint,
                              onChanged: (val) {
                                setState(() {
                                  _selectedIsJoint = val ?? false;
                                });
                              },
                              activeColor: themePrimary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Enroll in Joint Entrance preparation',
                                  style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Optional curriculum for engineering entrance prep',
                                  style: TextStyle(color: secondaryTextColor, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 20),

                    // Dropdown for Medium (Language)
                    Text('Select Medium', style: TextStyle(color: secondaryTextColor, fontWeight: FontWeight.w800, fontSize: 13)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderColor),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedLanguage,
                          isExpanded: true,
                          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                          style: TextStyle(color: textColor, fontWeight: FontWeight.w700),
                          items: const [
                            DropdownMenuItem(value: 'English', child: Text('English')),
                            DropdownMenuItem(value: 'Bengali', child: Text('Bengali')),
                            DropdownMenuItem(value: 'Both', child: Text('Both')),
                          ],
                          onChanged: (val) {
                            setState(() {
                              _selectedLanguage = val;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Read-only parameters warning
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.2)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline_rounded, color: Colors.redAccent, size: 20),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Other details (Name, Father\'s Name, Phone) cannot be modified.',
                              style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSaving ? null : () => setState(() => _isEditing = false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        side: BorderSide(color: borderColor),
                      ),
                      child: Text('Cancel', style: TextStyle(color: textColor, fontWeight: FontWeight.w800)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: (_isSaving || !_hasChanges)
                          ? null
                          : () => _saveChanges(auth),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            _hasChanges ? themePrimary : Colors.grey.shade300,
                        disabledBackgroundColor: Colors.grey.shade300,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : Text(
                              'Save Changes',
                              style: TextStyle(
                                color: _hasChanges
                                    ? Colors.white
                                    : Colors.grey.shade500,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _confirmLogout(context, auth, textColor, secondaryTextColor),
                icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                label: const Text('Logout', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w800)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.4)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  backgroundColor: Colors.redAccent.withValues(alpha: 0.06),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _profileItem(IconData icon, String label, String value, Color textColor, Color secondaryTextColor, Color borderColor, Color themePrimary, {bool isLocked = false}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: themePrimary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: Icon(icon, color: themePrimary, size: 22),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(color: secondaryTextColor, fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: textColor),
              ),
            ],
          ),
        ),
        if (isLocked)
          Icon(Icons.lock_outline_rounded, color: secondaryTextColor.withValues(alpha: 0.4), size: 18),
      ],
    );
  }

  Widget _divider(Color borderColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Divider(height: 1, color: borderColor),
    );
  }

  void _confirmLogout(BuildContext context, AuthProvider auth, Color textColor, Color secondaryTextColor) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text('Logout?', style: TextStyle(color: textColor, fontWeight: FontWeight.w900)),
        content: Text('Are you sure you want to logout?', style: TextStyle(color: secondaryTextColor, fontWeight: FontWeight.w500)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: secondaryTextColor, fontWeight: FontWeight.w700)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              auth.logout();
            },
            child: const Text('Logout', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}
