import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../shared/models/qbank_models.dart';
import '../../widgets/mixed_content_renderer.dart';
import '../../repositories/qbank_repository.dart';

class AdminQbankQuestionEditorScreen extends StatefulWidget {
  const AdminQbankQuestionEditorScreen({
    super.key,
    required this.type,
    required this.chapterId,
    this.questionId,
  });

  final String type; // mcq | cq
  final String chapterId;
  final String? questionId;

  @override
  State<AdminQbankQuestionEditorScreen> createState() =>
      _AdminQbankQuestionEditorScreenState();
}

class _AdminQbankQuestionEditorScreenState
    extends State<AdminQbankQuestionEditorScreen> {
  final _repo = QBankRepository();
  final _form = GlobalKey<FormState>();
  bool _loading = false;

  final _questionText = TextEditingController();
  final _optionA = TextEditingController();
  final _optionB = TextEditingController();
  final _optionC = TextEditingController();
  final _optionD = TextEditingController();
  final _explanation = TextEditingController();
  final _questionImage = TextEditingController();
  final _explanationImage = TextEditingController();

  final _stem = TextEditingController();
  final _gaText = TextEditingController();
  final _gaAns = TextEditingController();
  final _ghaText = TextEditingController();
  final _ghaAns = TextEditingController();
  final _stemImage = TextEditingController();
  final _gaImage = TextEditingController();
  final _ghaImage = TextEditingController();

  String _correctOption = 'A';
  String _difficulty = 'medium';
  int? _boardYear;
  final _sourceCtrl = TextEditingController();
  final _boardName = TextEditingController();
  final _tags = TextEditingController();
  int _gaMarks = 3;
  int _ghaMarks = 4;
  bool _isPublished = true;

  bool get _isEdit => widget.questionId != null;
  bool get _isMcq => widget.type == 'mcq';

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _load();
    }
  }

  @override
  void dispose() {
    _questionText.dispose();
    _optionA.dispose();
    _optionB.dispose();
    _optionC.dispose();
    _optionD.dispose();
    _explanation.dispose();
    _questionImage.dispose();
    _explanationImage.dispose();
    _stem.dispose();
    _gaText.dispose();
    _gaAns.dispose();
    _ghaText.dispose();
    _ghaAns.dispose();
    _stemImage.dispose();
    _gaImage.dispose();
    _ghaImage.dispose();
    _sourceCtrl.dispose();
    _boardName.dispose();
    _tags.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      if (_isMcq) {
        final q = await _repo.getMcqById(widget.questionId!);
        _questionText.text = q.questionText;
        _optionA.text = q.optionA;
        _optionB.text = q.optionB;
        _optionC.text = q.optionC;
        _optionD.text = q.optionD;
        _correctOption = q.correctOption;
        _explanation.text = q.explanation ?? '';
        _questionImage.text = q.imageUrl ?? '';
        _explanationImage.text = q.explanationImageUrl ?? '';
        _difficulty = q.difficulty;
        _sourceCtrl.text = q.source ?? '';
        _boardYear = q.boardYear;
        _boardName.text = q.boardName ?? '';
        _tags.text = q.tags.join(', ');
        _isPublished = q.isPublished;
      } else {
        final q = await _repo.getCqById(widget.questionId!);
        _stem.text = q.stemText;
        _stemImage.text = q.stemImageUrl ?? '';
        _gaText.text = q.gaText;
        _gaImage.text = q.gaImageUrl ?? '';
        _gaAns.text = q.gaAnswer ?? '';
        _ghaText.text = q.ghaText;
        _ghaImage.text = q.ghaImageUrl ?? '';
        _ghaAns.text = q.ghaAnswer ?? '';
        _gaMarks = q.gaMarks;
        _ghaMarks = q.ghaMarks;
        _difficulty = q.difficulty;
        _sourceCtrl.text = q.source ?? '';
        _boardYear = q.boardYear;
        _boardName.text = q.boardName ?? '';
        _tags.text = q.tags.join(', ');
        _isPublished = q.isPublished;
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isMcq ? (_isEdit ? 'MCQ সম্পাদনা' : 'নতুন MCQ') : (_isEdit ? 'CQ সম্পাদনা' : 'নতুন CQ'),
          style: GoogleFonts.hindSiliguri(),
        ),
        actions: [
          TextButton.icon(
            onPressed: _showPreview,
            icon: const Icon(Icons.visibility_outlined),
            label: Text('Preview', style: GoogleFonts.hindSiliguri()),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_isMcq) ..._mcqFields() else ..._cqFields(),
                  const SizedBox(height: 8),
                  _commonFields(),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.save),
                    label: Text('সংরক্ষণ করুন', style: GoogleFonts.hindSiliguri()),
                  ),
                ],
              ),
            ),
    );
  }

  List<Widget> _mcqFields() => [
        _textField(_questionText, 'প্রশ্ন', minLines: 2),
        _imageField(_questionImage, 'প্রশ্নের ছবি URL'),
        _textField(_optionA, 'Option A'),
        _textField(_optionB, 'Option B'),
        _textField(_optionC, 'Option C'),
        _textField(_optionD, 'Option D'),
        DropdownButtonFormField<String>(
          initialValue: _correctOption,
          decoration: InputDecoration(
            labelText: 'সঠিক উত্তর',
            labelStyle: GoogleFonts.hindSiliguri(),
            border: const OutlineInputBorder(),
          ),
          items: const ['A', 'B', 'C', 'D']
              .map((e) => DropdownMenuItem<String>(value: e, child: Text(e)))
              .toList(),
          onChanged: (v) => setState(() => _correctOption = v ?? 'A'),
        ),
        _textField(_explanation, 'ব্যাখ্যা', minLines: 2, required: false),
        _imageField(_explanationImage, 'ব্যাখ্যার ছবি URL'),
      ];

  List<Widget> _cqFields() => [
        _textField(_stem, 'উদ্দীপক', minLines: 2),
        _imageField(_stemImage, 'উদ্দীপকের ছবি URL'),
        _textField(_gaText, 'গ প্রশ্ন'),
        _imageField(_gaImage, 'গ প্রশ্নের ছবি URL'),
        _textField(_gaAns, 'গ মডেল উত্তর', minLines: 2, required: false),
        _intField('গ নম্বর', _gaMarks, (v) => _gaMarks = v ?? 3),
        _textField(_ghaText, 'ঘ প্রশ্ন'),
        _imageField(_ghaImage, 'ঘ প্রশ্নের ছবি URL'),
        _textField(_ghaAns, 'ঘ মডেল উত্তর', minLines: 2, required: false),
        _intField('ঘ নম্বর', _ghaMarks, (v) => _ghaMarks = v ?? 4),
      ];

  Widget _commonFields() {
    return Column(
      children: [
        DropdownButtonFormField<String>(
          initialValue: _difficulty,
          decoration: InputDecoration(
            labelText: 'কঠিনতা',
            labelStyle: GoogleFonts.hindSiliguri(),
            border: const OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: 'easy', child: Text('সহজ')),
            DropdownMenuItem(value: 'medium', child: Text('মধ্যম')),
            DropdownMenuItem(value: 'hard', child: Text('কঠিন')),
          ],
          onChanged: (v) => setState(() => _difficulty = v ?? 'medium'),
        ),
        const SizedBox(height: 12),
        _textField(
          _sourceCtrl,
          'উৎস (board/practice/custom)',
          required: false,
        ),
        _intField('বোর্ড বছর', _boardYear, (v) => _boardYear = v, required: false),
        _textField(_boardName, 'বোর্ড নাম', required: false),
        _textField(_tags, 'ট্যাগ (কমা দিয়ে)', required: false),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _isPublished,
          onChanged: (v) => setState(() => _isPublished = v),
          title: Text('Published', style: GoogleFonts.nunito()),
        ),
      ],
    );
  }

  Widget _imageField(TextEditingController ctl, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: ctl,
              decoration: InputDecoration(
                labelText: label,
                labelStyle: GoogleFonts.hindSiliguri(),
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Upload',
            onPressed: () => _pickAndUploadImage(ctl),
            icon: const Icon(Icons.upload_file),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndUploadImage(TextEditingController target) async {
    try {
      final picked = await FilePicker.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (picked == null || picked.files.isEmpty) return;
      final file = picked.files.single;
      final bytes = file.bytes;
      if (bytes == null) return;
      setState(() => _loading = true);
      final url = await _repo.uploadQbankImage(
        bytes: bytes,
        fileName: file.name,
      );
      target.text = url;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _textField(
    TextEditingController controller,
    String label, {
    int minLines = 1,
    bool required = true,
    ValueChanged<String>? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        minLines: minLines,
        maxLines: minLines == 1 ? 1 : null,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.hindSiliguri(),
          border: const OutlineInputBorder(),
        ),
        onChanged: onChanged,
        validator: required
            ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
            : null,
      ),
    );
  }

  Widget _intField(
    String label,
    int? value,
    ValueChanged<int?> onChanged, {
    bool required = true,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        initialValue: value?.toString() ?? '',
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.hindSiliguri(),
          border: const OutlineInputBorder(),
        ),
        onChanged: (v) => onChanged(int.tryParse(v.trim())),
        validator: required
            ? (v) => int.tryParse(v ?? '') == null ? 'Required int' : null
            : null,
      ),
    );
  }

  List<String> _tagsList() => _tags.text
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      if (_isMcq) {
        final payload = <String, dynamic>{
          'chapter_id': widget.chapterId,
          'question_text': _questionText.text.trim(),
          'image_url': _questionImage.text.trim().isEmpty ? null : _questionImage.text.trim(),
          'option_a': _optionA.text.trim(),
          'option_b': _optionB.text.trim(),
          'option_c': _optionC.text.trim(),
          'option_d': _optionD.text.trim(),
          'correct_option': _correctOption,
          'explanation': _explanation.text.trim().isEmpty ? null : _explanation.text.trim(),
          'explanation_image_url':
              _explanationImage.text.trim().isEmpty ? null : _explanationImage.text.trim(),
          'difficulty': _difficulty,
          'source': _sourceCtrl.text.trim().isEmpty ? null : _sourceCtrl.text.trim(),
          'board_year': _boardYear,
          'board_name': _boardName.text.trim().isEmpty ? null : _boardName.text.trim(),
          'tags': _tagsList(),
          'is_published': _isPublished,
        };
        if (_isEdit) {
          await _repo.updateMcq(widget.questionId!, payload);
        } else {
          await _repo.addMcq(
            QbankMcq(
              id: '',
              chapterId: widget.chapterId,
              questionText: payload['question_text'] as String,
              imageUrl: payload['image_url'] as String?,
              optionA: payload['option_a'] as String,
              optionB: payload['option_b'] as String,
              optionC: payload['option_c'] as String,
              optionD: payload['option_d'] as String,
              correctOption: payload['correct_option'] as String,
              explanation: payload['explanation'] as String?,
              explanationImageUrl: payload['explanation_image_url'] as String?,
              difficulty: _difficulty,
              source: _sourceCtrl.text.trim().isEmpty ? null : _sourceCtrl.text.trim(),
              boardYear: _boardYear,
              boardName: payload['board_name'] as String?,
              tags: _tagsList(),
              isPublished: _isPublished,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );
        }
      } else {
        final payload = <String, dynamic>{
          'chapter_id': widget.chapterId,
          'stem_text': _stem.text.trim(),
          'stem_image_url': _stemImage.text.trim().isEmpty ? null : _stemImage.text.trim(),
          'ga_text': _gaText.text.trim(),
          'ga_image_url': _gaImage.text.trim().isEmpty ? null : _gaImage.text.trim(),
          'ga_answer': _gaAns.text.trim().isEmpty ? null : _gaAns.text.trim(),
          'ga_marks': _gaMarks,
          'gha_text': _ghaText.text.trim(),
          'gha_image_url': _ghaImage.text.trim().isEmpty ? null : _ghaImage.text.trim(),
          'gha_answer': _ghaAns.text.trim().isEmpty ? null : _ghaAns.text.trim(),
          'gha_marks': _ghaMarks,
          'difficulty': _difficulty,
          'source': _sourceCtrl.text.trim().isEmpty ? null : _sourceCtrl.text.trim(),
          'board_year': _boardYear,
          'board_name': _boardName.text.trim().isEmpty ? null : _boardName.text.trim(),
          'tags': _tagsList(),
          'is_published': _isPublished,
        };
        if (_isEdit) {
          await _repo.updateCq(widget.questionId!, payload);
        } else {
          await _repo.addCq(
            QbankCq(
              id: '',
              chapterId: widget.chapterId,
              stemText: payload['stem_text'] as String,
              stemImageUrl: payload['stem_image_url'] as String?,
              gaText: payload['ga_text'] as String,
              gaImageUrl: payload['ga_image_url'] as String?,
              gaAnswer: payload['ga_answer'] as String?,
              gaMarks: _gaMarks,
              ghaText: payload['gha_text'] as String,
              ghaImageUrl: payload['gha_image_url'] as String?,
              ghaAnswer: payload['gha_answer'] as String?,
              ghaMarks: _ghaMarks,
              difficulty: _difficulty,
              source: _sourceCtrl.text.trim().isEmpty ? null : _sourceCtrl.text.trim(),
              boardYear: _boardYear,
              boardName: payload['board_name'] as String?,
              tags: _tagsList(),
              isPublished: _isPublished,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );
        }
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showPreview() {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Preview', style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: _isMcq
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MixedContentRenderer(content: _questionText.text),
                    if (_questionImage.text.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Image.network(_questionImage.text.trim(), height: 120),
                    ],
                    const SizedBox(height: 8),
                    Text('A) ${_optionA.text}', style: GoogleFonts.hindSiliguri()),
                    Text('B) ${_optionB.text}', style: GoogleFonts.hindSiliguri()),
                    Text('C) ${_optionC.text}', style: GoogleFonts.hindSiliguri()),
                    Text('D) ${_optionD.text}', style: GoogleFonts.hindSiliguri()),
                    const SizedBox(height: 8),
                    Text('Correct: $_correctOption', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
                    if (_explanation.text.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      MixedContentRenderer(content: _explanation.text),
                    ],
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('উদ্দীপক', style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w700)),
                    MixedContentRenderer(content: _stem.text),
                    const SizedBox(height: 8),
                    Text('গ ($_gaMarks)', style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w700)),
                    MixedContentRenderer(content: _gaText.text),
                    if (_gaAns.text.trim().isNotEmpty) MixedContentRenderer(content: _gaAns.text),
                    const SizedBox(height: 8),
                    Text('ঘ ($_ghaMarks)', style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w700)),
                    MixedContentRenderer(content: _ghaText.text),
                    if (_ghaAns.text.trim().isNotEmpty) MixedContentRenderer(content: _ghaAns.text),
                  ],
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }
}
