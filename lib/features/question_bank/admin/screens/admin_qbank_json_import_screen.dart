import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../repositories/qbank_repository.dart';
import '../../services/qbank_json_importer.dart';

class AdminQbankJsonImportScreen extends StatefulWidget {
  const AdminQbankJsonImportScreen({super.key, required this.chapterId});

  final String chapterId;

  @override
  State<AdminQbankJsonImportScreen> createState() => _AdminQbankJsonImportScreenState();
}

class _AdminQbankJsonImportScreenState extends State<AdminQbankJsonImportScreen> {
  final _importer = QBankJsonImporter();
  final _repo = QBankRepository();

  String? _fileName;
  QbankImportResult? _result;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('JSON Import', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FilledButton.icon(
            onPressed: _busy ? null : _pickFile,
            icon: const Icon(Icons.upload_file),
            label: Text('JSON ফাইল নির্বাচন করুন', style: GoogleFonts.hindSiliguri()),
          ),
          if (_fileName != null) ...[
            const SizedBox(height: 8),
            Text('File: $_fileName', style: GoogleFonts.nunito()),
          ],
          const SizedBox(height: 16),
          if (_result != null) ...[
            _SummaryCard(result: _result!),
            const SizedBox(height: 12),
            if (_result!.errors.isNotEmpty) _ErrorsCard(errors: _result!.errors),
            const SizedBox(height: 12),
            _PreviewCard(result: _result!),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _busy || _result!.validRows.isEmpty ? null : _importValidRows,
              icon: const Icon(Icons.cloud_upload_outlined),
              label: Text(
                '${_result!.validRows.length} টি প্রশ্ন Import করুন',
                style: GoogleFonts.hindSiliguri(),
              ),
            ),
          ],
          if (_busy) ...[
            const SizedBox(height: 12),
            const Center(child: CircularProgressIndicator()),
          ],
        ],
      ),
    );
  }

  Future<void> _pickFile() async {
    try {
      final picked = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['json'],
        withData: true,
      );
      if (picked == null || picked.files.isEmpty) return;
      final file = picked.files.single;
      if (file.bytes == null) return;
      final raw = utf8.decode(file.bytes!);
      final result = _importer.parse(raw);
      if (!mounted) return;
      setState(() {
        _fileName = file.name;
        _result = result;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _importValidRows() async {
    final result = _result;
    if (result == null) return;
    setState(() => _busy = true);
    try {
      if (result.type == 'mcq') {
        final rows = result.validRows.map((q) {
          return <String, dynamic>{
            'chapter_id': widget.chapterId,
            'question_text': q['question_text'],
            'image_url': q['image_url'],
            'option_a': q['option_a'],
            'option_b': q['option_b'],
            'option_c': q['option_c'],
            'option_d': q['option_d'],
            'correct_option': (q['correct_option'] ?? 'A').toString().toUpperCase(),
            'explanation': q['explanation'],
            'explanation_image_url': q['explanation_image_url'],
            'difficulty': q['difficulty'] ?? 'medium',
            'source': q['source'],
            'board_year': q['board_year'],
            'board_name': q['board_name'],
            'tags': q['tags'] is List ? q['tags'] : <String>[],
          };
        }).toList();
        await _repo.batchInsertMcq(rows);
      } else {
        final rows = result.validRows.map((q) {
          return <String, dynamic>{
            'chapter_id': widget.chapterId,
            'stem_text': q['stem_text'],
            'stem_image_url': q['stem_image_url'],
            'ga_text': q['ga_text'],
            'ga_image_url': q['ga_image_url'],
            'ga_answer': q['ga_answer'],
            'ga_marks': q['ga_marks'] ?? 3,
            'gha_text': q['gha_text'],
            'gha_image_url': q['gha_image_url'],
            'gha_answer': q['gha_answer'],
            'gha_marks': q['gha_marks'] ?? 4,
            'difficulty': q['difficulty'] ?? 'medium',
            'source': q['source'],
            'board_year': q['board_year'],
            'board_name': q['board_name'],
            'tags': q['tags'] is List ? q['tags'] : <String>[],
          };
        }).toList();
        await _repo.batchInsertCq(rows);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Import failed: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.result});
  final QbankImportResult result;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text('পার্স ফলাফল', style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600)),
        subtitle: Text(
          'Type: ${result.type.toUpperCase()} · Total: ${result.totalCount} · Valid: ${result.validRows.length} · Error: ${result.errors.length}',
          style: GoogleFonts.nunito(),
        ),
      ),
    );
  }
}

class _ErrorsCard extends StatelessWidget {
  const _ErrorsCard({required this.errors});
  final List<ImportErrorItem> errors;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ত্রুটি', style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            ...errors.take(20).map(
                  (e) => Text('#${e.index}: ${e.message}', style: GoogleFonts.nunito()),
                ),
            if (errors.length > 20)
              Text('আরো ${errors.length - 20} টি...', style: GoogleFonts.nunito(fontStyle: FontStyle.italic)),
          ],
        ),
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.result});
  final QbankImportResult result;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Preview', style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            ...result.validRows.take(10).map((q) {
              final text = result.type == 'mcq'
                  ? (q['question_text'] ?? '').toString()
                  : (q['stem_text'] ?? '').toString();
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('• $text', style: GoogleFonts.hindSiliguri()),
              );
            }),
            if (result.validRows.length > 10)
              Text('আরো ${result.validRows.length - 10} টি...', style: GoogleFonts.nunito()),
          ],
        ),
      ),
    );
  }
}
