import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../shared/models/user_model.dart';
import '../../admin/students/repositories/student_repository.dart';
import '../widgets/student_drawer.dart';

/// Student: edit own profile (`users` row fields allowed by RLS).
class StudentEditProfileScreen extends ConsumerStatefulWidget {
  const StudentEditProfileScreen({super.key});

  @override
  ConsumerState<StudentEditProfileScreen> createState() =>
      _StudentEditProfileScreenState();
}

class _StudentEditProfileScreenState extends ConsumerState<StudentEditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameBn = TextEditingController();
  final _nameEn = TextEditingController();
  final _guardianPhone = TextEditingController();
  final _dobDisplay = TextEditingController();
  final _college = TextEditingController();
  final _address = TextEditingController();

  final _repo = StudentRepository();

  File? _photo;
  DateTime? _dob;
  ClassLevel? _classLevel = ClassLevel.ssc;

  bool _submitting = false;
  bool _loadingUser = true;
  bool _noUser = false;
  UserModel? _user;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadUser());
  }

  Future<void> _loadUser() async {
    final u = await ref.read(currentUserProvider.future);
    if (!mounted) return;
    if (u == null) {
      setState(() {
        _loadingUser = false;
        _noUser = true;
      });
      return;
    }
    _fillFrom(u);
    setState(() {
      _user = u;
      _loadingUser = false;
    });
  }

  @override
  void dispose() {
    _nameBn.dispose();
    _nameEn.dispose();
    _guardianPhone.dispose();
    _dobDisplay.dispose();
    _college.dispose();
    _address.dispose();
    super.dispose();
  }

  void _fillFrom(UserModel u) {
    _nameBn.text = u.fullNameBn;
    _nameEn.text = u.fullNameEn ?? '';
    _guardianPhone.text = u.guardianPhone ?? '';
    _college.text = u.college ?? '';
    _address.text = u.address ?? '';
    _dob = u.dateOfBirth;
    if (_dob != null) {
      final d = _dob!;
      _dobDisplay.text =
          '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    }
    _classLevel = u.classLevel ?? ClassLevel.ssc;
  }

  Future<void> _pickPhoto() async {
    final x = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 88,
    );
    if (x != null) setState(() => _photo = File(x.path));
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final initial = _dob ?? DateTime(now.year - 15, now.month, now.day);
    final first = DateTime(1990);
    final last = DateTime(now.year - 8, now.month, now.day);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
      helpText: 'জন্ম তারিখ',
    );
    if (picked != null) {
      setState(() {
        _dob = picked;
        _dobDisplay.text =
            '${picked.day.toString().padLeft(2, '0')}/'
            '${picked.month.toString().padLeft(2, '0')}/'
            '${picked.year}';
      });
    }
  }

  String? _validateGuardian(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return null;
    if (s.length != 11 || !s.startsWith('01')) {
      return '১১ সংখ্যা, ০১ দিয়ে শুরু';
    }
    return null;
  }

  Future<void> _submit() async {
    final base = _user;
    if (base == null) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    try {
      final updated = UserModel(
        id: base.id,
        phone: base.phone,
        email: base.email,
        fullNameBn: _nameBn.text.trim(),
        fullNameEn: _nameEn.text.trim().isEmpty ? null : _nameEn.text.trim(),
        avatarUrl: base.avatarUrl,
        role: base.role,
        studentId: base.studentId,
        dateOfBirth: _dob,
        guardianPhone:
            _guardianPhone.text.trim().isEmpty ? null : _guardianPhone.text.trim(),
        address: _address.text.trim().isEmpty ? null : _address.text.trim(),
        college: _college.text.trim().isEmpty ? null : _college.text.trim(),
        classLevel: _classLevel,
        fcmToken: base.fcmToken,
        isActive: base.isActive,
      );

      await _repo.updateMyProfile(updated, _photo);
      if (!mounted) return;
      ref.invalidate(currentUserProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'প্রোফাইল সংরক্ষিত হয়েছে',
            style: GoogleFonts.hindSiliguri(color: Colors.white),
          ),
        ),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'ব্যর্থ: $e',
            style: GoogleFonts.hindSiliguri(color: Colors.white),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  InputDecoration _decoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.hindSiliguri(),
      alignLabelWithHint: true,
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: GoogleFonts.hindSiliguri(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: context.themePrimary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (_loadingUser) {
      return Scaffold(
        drawer: const StudentDrawer(),
        appBar: AppBar(
          leading: const AppBarDrawerLeading(),
          automaticallyImplyLeading: false,
          leadingWidth: leadingWidthForDrawer(context),
          title: Text('প্রোফাইল', style: GoogleFonts.hindSiliguri()),
          actions: const [AppBarDrawerAction()],
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_noUser || _user == null) {
      return Scaffold(
        drawer: const StudentDrawer(),
        appBar: AppBar(
          leading: const AppBarDrawerLeading(),
          automaticallyImplyLeading: false,
          leadingWidth: leadingWidthForDrawer(context),
          title: Text('প্রোফাইল', style: GoogleFonts.hindSiliguri()),
          actions: const [AppBarDrawerAction()],
        ),
        body: const Center(child: Text('লগইন প্রয়োজন')),
      );
    }

    final user = _user!;

    return Scaffold(
      drawer: const StudentDrawer(),
      appBar: AppBar(
        leading: const AppBarDrawerLeading(),
        automaticallyImplyLeading: false,
        leadingWidth: leadingWidthForDrawer(context),
        title: Text(
          'প্রোফাইল সম্পাদনা',
          style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600),
        ),
        actions: const [AppBarDrawerAction()],
      ),
      body: Stack(
        children: [
          Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                _sectionTitle('ছবি'),
                const SizedBox(height: 12),
                Center(child: _photoPicker(scheme, user)),
                    const SizedBox(height: 24),
                    _sectionTitle('মৌলিক তথ্য'),
                    const SizedBox(height: 12),
                    Text(
                      'মোবাইল (পরিবর্তনযোগ্য নয়)',
                      style: GoogleFonts.hindSiliguri(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.phone,
                      style: GoogleFonts.nunito(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (user.studentId != null && user.studentId!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        'শিক্ষার্থী আইডি',
                        style: GoogleFonts.hindSiliguri(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.studentId!,
                        style: GoogleFonts.nunito(fontWeight: FontWeight.w600),
                      ),
                    ],
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nameBn,
                      enabled: !_submitting,
                      decoration: _decoration('পূর্ণ নাম (বাংলা) *'),
                      style: GoogleFonts.hindSiliguri(),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'নাম দিন';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _nameEn,
                      enabled: !_submitting,
                      textCapitalization: TextCapitalization.words,
                      decoration: _decoration('পূর্ণ নাম (ইংরেজি)'),
                      style: GoogleFonts.nunito(),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _guardianPhone,
                      enabled: !_submitting,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(11),
                      ],
                      decoration: _decoration('অভিভাবকের মোবাইল'),
                      style: GoogleFonts.nunito(),
                      validator: _validateGuardian,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _dobDisplay,
                      enabled: !_submitting,
                      readOnly: true,
                      onTap: _submitting ? null : _pickDob,
                      decoration: _decoration('জন্ম তারিখ').copyWith(
                        suffixIcon: const Icon(Icons.calendar_today_outlined),
                      ),
                      style: GoogleFonts.nunito(),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<ClassLevel>(
                      // ignore: deprecated_member_use — selection via setState
                      value: _classLevel,
                      decoration: _decoration('শ্রেণি'),
                      items: const [
                        DropdownMenuItem(value: ClassLevel.ssc, child: Text('SSC')),
                        DropdownMenuItem(value: ClassLevel.hsc, child: Text('HSC')),
                        DropdownMenuItem(
                          value: ClassLevel.admission,
                          child: Text('Admission'),
                        ),
                        DropdownMenuItem(value: ClassLevel.other, child: Text('Other')),
                      ],
                      onChanged: _submitting
                          ? null
                          : (v) => setState(() => _classLevel = v ?? ClassLevel.ssc),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _college,
                      enabled: !_submitting,
                      textCapitalization: TextCapitalization.words,
                      decoration: _decoration('কলেজ / স্কুল'),
                      style: GoogleFonts.hindSiliguri(),
                    ),
                    const SizedBox(height: 24),
                    _sectionTitle('ঠিকানা'),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _address,
                      enabled: !_submitting,
                      maxLines: 3,
                      decoration: _decoration('ঠিকানা'),
                      style: GoogleFonts.hindSiliguri(),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _submitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: context.themePrimary,
                          foregroundColor: scheme.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                          ),
                        ),
                        child: Text(
                          'সংরক্ষণ করুন',
                          style: GoogleFonts.hindSiliguri(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_submitting)
                Positioned.fill(
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: 0.3),
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                ),
            ],
          ),
        );
  }

  Widget _photoPicker(ColorScheme scheme, UserModel user) {
    return GestureDetector(
      onTap: _submitting ? null : _pickPhoto,
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          CircleAvatar(
            radius: 56,
            backgroundColor: scheme.surfaceContainerHighest,
            backgroundImage: _photo != null
                ? FileImage(_photo!)
                : (user.avatarUrl != null && user.avatarUrl!.isNotEmpty)
                    ? NetworkImage(user.avatarUrl!)
                    : null,
            child: _photo == null &&
                    (user.avatarUrl == null || user.avatarUrl!.isEmpty)
                ? Icon(
                    Icons.person_outline,
                    size: 56,
                    color: scheme.onSurfaceVariant,
                  )
                : null,
          ),
          Material(
            color: context.themePrimary,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: _submitting ? null : _pickPhoto,
              customBorder: const CircleBorder(),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(Icons.camera_alt, color: scheme.onPrimary, size: 22),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
