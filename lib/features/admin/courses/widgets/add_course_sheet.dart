import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../app/theme.dart';
import '../../../../core/supabase_client.dart';
import '../../../../shared/models/course_model.dart';
import '../providers/courses_provider.dart';

/// Modal bottom sheet: add course with [Form] validation and image preview.
/// Pass [editingCourse] to update an existing course (same sheet).
class AddCourseSheet extends ConsumerStatefulWidget {
  const AddCourseSheet({super.key, this.editingCourse});

  /// When set, the sheet saves via [CourseRepository.updateCourse].
  final CourseModel? editingCourse;

  @override
  ConsumerState<AddCourseSheet> createState() => _AddCourseSheetState();
}

class _AddCourseSheetState extends ConsumerState<AddCourseSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _feeController = TextEditingController();

  File? _imageFile;
  bool _removeThumbnail = false;
  bool _active = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final e = widget.editingCourse;
    if (e != null) {
      _nameController.text = e.name;
      _descController.text = e.description ?? '';
      final f = e.monthlyFee;
      _feeController.text =
          f == f.roundToDouble() ? f.round().toString() : f.toString();
      _active = e.isActive;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _feeController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      imageQuality: 85,
    );
    if (file != null) {
      setState(() {
        _imageFile = File(file.path);
        _removeThumbnail = false;
      });
    }
  }

  void _clearImage() {
    setState(() {
      _imageFile = null;
      if (widget.editingCourse != null) {
        _removeThumbnail = true;
      }
    });
  }

  Future<void> _onSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _submitting = true);
    try {
      final fee = double.parse(_feeController.text.trim());
      final uid = supabaseClient.auth.currentUser?.id;
      final editing = widget.editingCourse;
      if (editing != null) {
        final updated = CourseModel(
          id: editing.id,
          name: _nameController.text.trim(),
          description: _descController.text.trim().isEmpty
              ? null
              : _descController.text.trim(),
          thumbnailUrl: _removeThumbnail ? null : editing.thumbnailUrl,
          monthlyFee: fee,
          isActive: _active,
          createdBy: editing.createdBy,
          createdAt: editing.createdAt,
          updatedAt: editing.updatedAt,
        );
        await ref.read(courseRepositoryProvider).updateCourse(updated, _imageFile);
      } else {
        final course = CourseModel(
          id: '00000000-0000-0000-0000-000000000001',
          name: _nameController.text.trim(),
          description: _descController.text.trim().isEmpty
              ? null
              : _descController.text.trim(),
          thumbnailUrl: null,
          monthlyFee: fee,
          isActive: _active,
          createdBy: uid,
        );

        await ref.read(courseRepositoryProvider).addCourse(course, _imageFile);
      }

      if (!mounted) return;
      ref.invalidate(coursesProvider);
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'সংরক্ষণ ব্যর্থ: $e',
            style: GoogleFonts.hindSiliguri(color: Colors.white),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: bottom + 8,
      ),
      child: Stack(
        children: [
          Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    widget.editingCourse == null ? 'নতুন কোর্স' : 'কোর্স সম্পাদনা',
                    style: GoogleFonts.hindSiliguri(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: context.themePrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _ImagePickerBlock(
                    file: _imageFile,
                    networkUrl: _removeThumbnail
                        ? null
                        : widget.editingCourse?.thumbnailUrl,
                    onPick: _pickImage,
                    onClear: _clearImage,
                    enabled: !_submitting,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _nameController,
                    enabled: !_submitting,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'কোর্সের নাম',
                      hintText: 'কোর্সের নাম',
                      labelStyle: GoogleFonts.hindSiliguri(),
                      hintStyle: GoogleFonts.hindSiliguri(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    style: GoogleFonts.hindSiliguri(),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'কোর্সের নাম দিন';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descController,
                    enabled: !_submitting,
                    maxLines: 3,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'বিবরণ',
                      alignLabelWithHint: true,
                      labelStyle: GoogleFonts.hindSiliguri(),
                    ),
                    style: GoogleFonts.hindSiliguri(),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _feeController,
                    enabled: !_submitting,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                    ],
                    decoration: InputDecoration(
                      labelText: 'মাসিক ফি',
                      labelStyle: GoogleFonts.hindSiliguri(),
                      prefixText: '৳ ',
                      prefixStyle: GoogleFonts.nunito(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    style: GoogleFonts.nunito(fontSize: 16),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'মাসিক ফি দিন';
                      }
                      final n = double.tryParse(v.trim());
                      if (n == null || n < 0) {
                        return 'সঠিক অঙ্ক দিন';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'সক্রিয় কোর্স',
                      style: GoogleFonts.hindSiliguri(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    value: _active,
                    onChanged: _submitting
                        ? null
                        : (v) => setState(() => _active = v),
                    activeThumbColor: context.themePrimary,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _submitting ? null : _onSubmit,
                    style: FilledButton.styleFrom(
                      backgroundColor: context.themePrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      'সংরক্ষণ করুন',
                      style: GoogleFonts.hindSiliguri(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          if (_submitting)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.35),
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ImagePickerBlock extends StatelessWidget {
  const _ImagePickerBlock({
    required this.file,
    this.networkUrl,
    required this.onPick,
    required this.onClear,
    required this.enabled,
  });

  final File? file;
  final String? networkUrl;
  final VoidCallback onPick;
  final VoidCallback onClear;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.cardRadius),
            child: file != null
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.file(
                        file!,
                        fit: BoxFit.cover,
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Material(
                          color: Colors.black54,
                          shape: const CircleBorder(),
                          child: IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: enabled ? onClear : null,
                            tooltip: 'সরান',
                          ),
                        ),
                      ),
                    ],
                  )
                : (networkUrl != null && networkUrl!.isNotEmpty)
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          CachedNetworkImage(
                            imageUrl: networkUrl!,
                            fit: BoxFit.cover,
                            placeholder: (_, _) => ColoredBox(
                              color: scheme.surfaceContainerHighest,
                              child: const Center(child: CircularProgressIndicator()),
                            ),
                            errorWidget: (_, _, _) => ColoredBox(
                              color: scheme.surfaceContainerHighest,
                              child: Icon(Icons.broken_image_outlined, color: scheme.onSurfaceVariant),
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Material(
                              color: Colors.black54,
                              shape: const CircleBorder(),
                              child: IconButton(
                                icon: const Icon(Icons.close, color: Colors.white),
                                onPressed: enabled ? onClear : null,
                                tooltip: 'সরান',
                              ),
                            ),
                          ),
                        ],
                      )
                    : Material(
                    color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
                    child: InkWell(
                      onTap: enabled ? onPick : null,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_photo_alternate_outlined,
                            size: 48,
                            color: scheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'ছবি বেছে নিন',
                            style: GoogleFonts.hindSiliguri(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ),
        if (file != null || (networkUrl != null && networkUrl!.isNotEmpty)) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: enabled ? onPick : null,
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: Text(
              'ছবি পরিবর্তন',
              style: GoogleFonts.hindSiliguri(),
            ),
          ),
        ],
      ],
    );
  }
}
