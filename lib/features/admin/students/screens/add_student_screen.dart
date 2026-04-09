import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../app/theme.dart';
import '../../../../core/constants.dart';
import '../../widgets/admin_drawer.dart';
import '../../../../shared/models/user_model.dart';
import '../repositories/student_repository.dart';

/// Full-screen form to add a student (Auth sign-up + `users` row).
class AddStudentScreen extends StatefulWidget {
  const AddStudentScreen({super.key});

  @override
  State<AddStudentScreen> createState() => _AddStudentScreenState();
}

class _AddStudentScreenState extends State<AddStudentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameBn = TextEditingController();
  final _nameEn = TextEditingController();
  final _phone = TextEditingController();
  final _guardianPhone = TextEditingController();
  final _dobDisplay = TextEditingController();
  final _college = TextEditingController();
  final _address = TextEditingController();

  final _repo = StudentRepository();

  File? _photo;
  DateTime? _dob;
  ClassLevel? _classLevel = ClassLevel.ssc;

  bool _submitting = false;

  @override
  void dispose() {
    _nameBn.dispose();
    _nameEn.dispose();
    _phone.dispose();
    _guardianPhone.dispose();
    _dobDisplay.dispose();
    _college.dispose();
    _address.dispose();
    super.dispose();
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
        _dobDisplay.text = _formatDate(picked);
      });
    }
  }

  String _formatDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/'
        '${d.year}';
  }

  String? _validatePhone(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'মোবাইল নম্বর দিন';
    if (s.length != 11 || !s.startsWith('01')) {
      return '১১ সংখ্যা, ০১ দিয়ে শুরু হতে হবে';
    }
    if (!RegExp(r'^\d{11}$').hasMatch(s)) return 'শুধু সংখ্যা';
    return null;
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
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    try {
      final draft = UserModel(
        id: '00000000-0000-0000-0000-000000000001',
        phone: _phone.text.trim(),
        fullNameBn: _nameBn.text.trim(),
        fullNameEn: _nameEn.text.trim().isEmpty ? null : _nameEn.text.trim(),
        role: UserRole.student,
        studentId: null,
        dateOfBirth: _dob,
        guardianPhone:
            _guardianPhone.text.trim().isEmpty ? null : _guardianPhone.text.trim(),
        address: _address.text.trim().isEmpty ? null : _address.text.trim(),
        college: _college.text.trim().isEmpty ? null : _college.text.trim(),
        classLevel: _classLevel,
        isActive: true,
      );

      final created = await _repo.addStudent(draft, _photo);
      if (!mounted) return;

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: Text(
            'সফল',
            style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w700),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'শিক্ষার্থী যোগ হয়েছে।',
                style: GoogleFonts.hindSiliguri(),
              ),
              const SizedBox(height: 12),
              Text(
                'লগইন: লগইন মোবাইল নম্বর দিন। পাসওয়ার্ড: নম্বরের শেষ ৯ সংখ্যা (${studentPasswordFromPhoneDigits(_phone.text.trim())})।',
                style: GoogleFonts.hindSiliguri(
                  fontSize: 13,
                  color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'শিক্ষার্থী আইডি:',
                style: GoogleFonts.hindSiliguri(
                  fontSize: 12,
                  color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              SelectableText(
                created.studentId ?? created.id,
                style: GoogleFonts.nunito(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: context.themePrimary,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                context.pop();
              },
              child: Text('ঠিক আছে', style: GoogleFonts.hindSiliguri()),
            ),
            FilledButton(
              onPressed: () {
                final id = created.id;
                Navigator.of(ctx).pop();
                context.pop();
                context.push('/admin/students/$id');
              },
              child: Text(
                'এখনই কোর্সে ভর্তি করুন',
                style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      drawer: const AdminDrawer(),
      appBar: AppBar(
        leading: const AppBarDrawerLeading(),
        automaticallyImplyLeading: false,
        leadingWidth: leadingWidthForDrawer(context),
        title: Text(
          'নতুন শিক্ষার্থী যোগ করুন',
          style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600),
        ),
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
                Center(child: _photoPicker(scheme)),
                const SizedBox(height: 24),
                _sectionTitle('মৌলিক তথ্য'),
                const SizedBox(height: 12),
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
                  controller: _phone,
                  enabled: !_submitting,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(11),
                  ],
                  decoration: _decoration('মোবাইল * (০১...)'),
                  style: GoogleFonts.nunito(),
                  validator: _validatePhone,
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
                  // ignore: deprecated_member_use — controlled selection via setState
                  value: _classLevel,
                  decoration: _decoration('শ্রেণি'),
                  items: const [
                    DropdownMenuItem(
                      value: ClassLevel.ssc,
                      child: Text('SSC'),
                    ),
                    DropdownMenuItem(
                      value: ClassLevel.hsc,
                      child: Text('HSC'),
                    ),
                    DropdownMenuItem(
                      value: ClassLevel.admission,
                      child: Text('Admission'),
                    ),
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
                      'শিক্ষার্থী যোগ করুন',
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

  InputDecoration _decoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.hindSiliguri(),
      alignLabelWithHint: true,
    );
  }

  Widget _photoPicker(ColorScheme scheme) {
    return GestureDetector(
      onTap: _submitting ? null : _pickPhoto,
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          CircleAvatar(
            radius: 56,
            backgroundColor: scheme.surfaceContainerHighest,
            backgroundImage:
                _photo != null ? FileImage(_photo!) : null,
            child: _photo == null
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
