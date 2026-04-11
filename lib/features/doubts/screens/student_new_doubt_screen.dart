import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/i18n/app_localizations.dart';
import '../../../app/theme.dart';
import '../repositories/doubt_repository.dart';
import '../../student/widgets/student_drawer.dart';

class StudentNewDoubtScreen extends StatefulWidget {
  const StudentNewDoubtScreen({super.key});

  @override
  State<StudentNewDoubtScreen> createState() => _StudentNewDoubtScreenState();
}

class _StudentNewDoubtScreenState extends State<StudentNewDoubtScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subject = TextEditingController();
  final _chapter = TextEditingController();
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _repo = DoubtRepository();
  File? _image;
  bool _submitting = false;

  @override
  void dispose() {
    _subject.dispose();
    _chapter.dispose();
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 2048);
    if (x != null) setState(() => _image = File(x.path));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final t = await _repo.createThread(
        subject: _subject.text,
        chapter: _chapter.text,
        title: _title.text,
        problemDescription: _desc.text,
        problemImage: _image,
      );
      if (!mounted) return;
      context.go('/student/doubts/${t.id}');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppLocalizations.of(context).t('failed')}: $e', style: GoogleFonts.hindSiliguri())),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      drawer: const StudentDrawer(),
      appBar: AppBar(
        leading: const AppBarDrawerLeading(),
        automaticallyImplyLeading: false,
        leadingWidth: leadingWidthForDrawer(context),
        title: Text(l10n.t('doubt_new_short'), style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600)),
        actions: const [AppBarDrawerAction()],
      ),
      body: Stack(
        children: [
          Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  l10n.t('doubt_form_section_desc'),
                  style: GoogleFonts.hindSiliguri(
                    fontWeight: FontWeight.w700,
                    color: context.themePrimary,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _subject,
                  enabled: !_submitting,
                  decoration: InputDecoration(
                    labelText: l10n.t('doubt_field_subject_optional'),
                    labelStyle: GoogleFonts.hindSiliguri(),
                    border: const OutlineInputBorder(),
                  ),
                  style: GoogleFonts.hindSiliguri(),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _chapter,
                  enabled: !_submitting,
                  decoration: InputDecoration(
                    labelText: l10n.t('doubt_field_chapter_optional'),
                    labelStyle: GoogleFonts.hindSiliguri(),
                    border: const OutlineInputBorder(),
                  ),
                  style: GoogleFonts.hindSiliguri(),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _title,
                  enabled: !_submitting,
                  decoration: InputDecoration(
                    labelText: l10n.t('doubt_field_title_required'),
                    labelStyle: GoogleFonts.hindSiliguri(),
                    border: const OutlineInputBorder(),
                  ),
                  style: GoogleFonts.hindSiliguri(),
                  validator: (v) {
                    if (v == null || v.trim().length < 5) return l10n.t('doubt_validate_title_short');
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _desc,
                  enabled: !_submitting,
                  minLines: 5,
                  maxLines: 12,
                  decoration: InputDecoration(
                    labelText: l10n.t('doubt_field_desc_required'),
                    labelStyle: GoogleFonts.hindSiliguri(),
                    alignLabelWithHint: true,
                    border: const OutlineInputBorder(),
                  ),
                  style: GoogleFonts.hindSiliguri(),
                  validator: (v) {
                    if (v == null || v.trim().length < 8) return l10n.t('doubt_validate_desc_short');
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                Text(
                  l10n.t('doubt_image_optional'),
                  style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _submitting ? null : _pickImage,
                  icon: const Icon(Icons.image_outlined),
                  label: Text(_image == null ? l10n.t('doubt_add_image') : l10n.t('doubt_change_image'), style: GoogleFonts.hindSiliguri()),
                ),
                if (_image != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Image.file(_image!, height: 160, fit: BoxFit.contain),
                  ),
                const SizedBox(height: 28),
                FilledButton(
                  onPressed: _submitting ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: context.themePrimary,
                    foregroundColor: scheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                    l10n.t('doubt_submit'),
                    style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          if (_submitting)
            const ColoredBox(
              color: Color(0x44000000),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
