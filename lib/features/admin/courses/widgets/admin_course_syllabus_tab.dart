import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/theme.dart';
import '../../../../core/public_links.dart';
import '../../../../shared/models/chapter_model.dart';
import '../../../../shared/models/chapter_suggestion_model.dart';
import '../../../../shared/models/note_model.dart';
import '../../../../shared/models/subject_model.dart';
import '../repositories/course_repository.dart';

class AdminCourseSyllabusTab extends StatefulWidget {
  const AdminCourseSyllabusTab({super.key, required this.courseId});

  final String courseId;

  @override
  State<AdminCourseSyllabusTab> createState() => _AdminCourseSyllabusTabState();
}

class _AdminCourseSyllabusTabState extends State<AdminCourseSyllabusTab> {
  final _repo = CourseRepository();
  late Future<void> _reload;
  List<SubjectModel> _subjects = [];
  final Map<String, List<ChapterModel>> _chapters = {};
  final Map<String, List<NoteModel>> _notes = {};
  final Map<String, List<ChapterSuggestionModel>> _suggestions = {};
  int _storageUsageBytes = 0;

  @override
  void initState() {
    super.initState();
    _reload = _load();
  }

  Future<void> _load() async {
    final subjects = await _repo.getSubjects(widget.courseId);
    _chapters.clear();
    _notes.clear();
    _suggestions.clear();
    for (final s in subjects) {
      final chapters = await _repo.getChapters(s.id);
      _chapters[s.id] = chapters;
      for (final c in chapters) {
        _notes[c.id] = await _repo.getNotesForChapter(c.id);
        _suggestions[c.id] = await _repo.getSuggestionsForChapter(c.id);
      }
    }
    _storageUsageBytes = await _repo.estimateNoteStorageBytes();
    if (!mounted) return;
    setState(() => _subjects = subjects);
  }

  Future<void> _refresh() async {
    setState(() => _reload = _load());
    await _reload;
  }

  Future<void> _addSubject() async {
    final ctl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('সাবজেক্ট যোগ করুন', style: GoogleFonts.hindSiliguri()),
        content: TextField(controller: ctl, decoration: const InputDecoration(labelText: 'নাম *')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('বাতিল')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('যোগ')),
        ],
      ),
    );
    if (ok != true || ctl.text.trim().isEmpty) return;
    await _repo.addSubject(
      SubjectModel(
        id: '',
        courseId: widget.courseId,
        name: ctl.text.trim(),
        description: null,
        displayOrder: _subjects.length,
        isActive: true,
      ),
    );
    await _refresh();
  }

  Future<void> _addChapter(SubjectModel subject) async {
    final ctl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('অধ্যায় যোগ করুন', style: GoogleFonts.hindSiliguri()),
        content: TextField(controller: ctl, decoration: const InputDecoration(labelText: 'নাম *')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('বাতিল')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('যোগ')),
        ],
      ),
    );
    if (ok != true || ctl.text.trim().isEmpty) return;
    final count = (_chapters[subject.id] ?? []).length;
    await _repo.addChapter(
      ChapterModel(
        id: '',
        subjectId: subject.id,
        name: ctl.text.trim(),
        description: null,
        displayOrder: count,
        isActive: true,
      ),
    );
    await _refresh();
  }

  Future<void> _addNoteDialog(String chapterId, {bool forceLecture = false}) async {
    final titleCtl = TextEditingController();
    final textCtl = TextEditingController();
    final youtubeCtl = TextEditingController();
    final externalCtl = TextEditingController();
    var type = forceLecture ? 'lecture' : 'pdf';
    var published = true;
    File? pickedFile;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text('নোট যোগ করুন', style: GoogleFonts.hindSiliguri()),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!forceLecture)
                  DropdownButtonFormField<String>(
                    value: type,
                    decoration: const InputDecoration(labelText: 'নোট টাইপ'),
                    items: const [
                      DropdownMenuItem(value: 'pdf', child: Text('PDF')),
                      DropdownMenuItem(value: 'video_youtube', child: Text('YouTube')),
                      DropdownMenuItem(value: 'video_upload', child: Text('ভিডিও ফাইল')),
                      DropdownMenuItem(value: 'text', child: Text('টেক্সট')),
                      DropdownMenuItem(value: 'image', child: Text('ইমেজ')),
                      DropdownMenuItem(value: 'link', child: Text('লিংক')),
                      DropdownMenuItem(value: 'lecture', child: Text('লেকচার')),
                    ],
                    onChanged: (v) => setLocal(() => type = v ?? 'pdf'),
                  ),
                const SizedBox(height: 10),
                TextField(controller: titleCtl, decoration: const InputDecoration(labelText: 'শিরোনাম *')),
                if (type == 'text' || type == 'lecture') ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: textCtl,
                    maxLines: 6,
                    decoration: const InputDecoration(labelText: 'Markdown + LaTeX'),
                  ),
                ],
                if (type == 'video_youtube' || type == 'lecture') ...[
                  const SizedBox(height: 10),
                  TextField(controller: youtubeCtl, decoration: const InputDecoration(labelText: 'YouTube URL')),
                ],
                if (type == 'link') ...[
                  const SizedBox(height: 10),
                  TextField(controller: externalCtl, decoration: const InputDecoration(labelText: 'External URL')),
                ],
                if (type == 'pdf' || type == 'video_upload' || type == 'image') ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final ext = type == 'pdf'
                          ? <String>['pdf']
                          : type == 'image'
                              ? <String>['jpg', 'jpeg', 'png', 'webp']
                              : <String>['mp4', 'mov', 'mkv', 'avi'];
                      final picked = await FilePicker.pickFiles(
                        type: FileType.custom,
                        allowedExtensions: ext,
                      );
                      if (picked == null || picked.files.single.path == null) return;
                      setLocal(() => pickedFile = File(picked.files.single.path!));
                    },
                    icon: const Icon(Icons.upload_file),
                    label: Text(
                      pickedFile == null ? 'ফাইল নির্বাচন' : pickedFile!.path.split('\\').last,
                      style: GoogleFonts.hindSiliguri(),
                    ),
                  ),
                ],
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: published,
                  title: Text('এখনই publish', style: GoogleFonts.hindSiliguri(fontSize: 14)),
                  onChanged: (v) => setLocal(() => published = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('বাতিল')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('সংরক্ষণ')),
          ],
        ),
      ),
    );
    if (ok != true || titleCtl.text.trim().isEmpty) return;

    String? fileUrl;
    int? fileSizeKb;
    if (pickedFile != null) {
      fileUrl = await _repo.uploadNoteFile(file: pickedFile!, chapterId: chapterId, kind: type);
      fileSizeKb = (await pickedFile!.length() / 1024).round();
    }
    final order = await _repo.nextNoteDisplayOrder(chapterId);
    await _repo.addNote(
      NoteModel(
        id: '',
        chapterId: chapterId,
        title: titleCtl.text.trim(),
        type: type,
        fileUrl: fileUrl ?? (youtubeCtl.text.trim().isEmpty ? null : youtubeCtl.text.trim()),
        youtubeUrl: youtubeCtl.text.trim().isEmpty ? null : youtubeCtl.text.trim(),
        externalUrl: externalCtl.text.trim().isEmpty ? null : externalCtl.text.trim(),
        textContent: textCtl.text.trim().isEmpty ? null : textCtl.text.trim(),
        content: textCtl.text.trim().isEmpty ? null : textCtl.text.trim(),
        fileSizeKb: fileSizeKb,
        isPublished: published,
        displayOrder: order,
      ),
    );
    await _refresh();
  }

  Future<void> _bulkPdfUpload(String chapterId) async {
    final picked = await FilePicker.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
    if (picked == null || picked.files.isEmpty) return;
    var publish = true;
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text('Bulk PDF', style: GoogleFonts.hindSiliguri()),
          content: SwitchListTile(
            value: publish,
            title: Text('সব publish করুন', style: GoogleFonts.hindSiliguri()),
            onChanged: (v) => setLocal(() => publish = v),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('বাতিল')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('আপলোড')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final files = picked.files.where((e) => e.path != null).map((e) => File(e.path!)).toList();
    await _repo.addBulkPdfNotes(chapterId: chapterId, files: files, publish: publish);
    await _refresh();
  }

  Future<void> _editNote(NoteModel note) async {
    final titleCtl = TextEditingController(text: note.title);
    final descCtl = TextEditingController(text: note.description ?? '');
    final textCtl = TextEditingController(text: note.textContent ?? note.content ?? '');
    final linkCtl = TextEditingController(text: note.externalUrl ?? note.youtubeUrl ?? note.fileUrl ?? '');
    var published = note.isPublished ?? true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text('নোট সম্পাদনা', style: GoogleFonts.hindSiliguri()),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(controller: titleCtl, decoration: const InputDecoration(labelText: 'শিরোনাম')),
                const SizedBox(height: 10),
                TextField(controller: descCtl, decoration: const InputDecoration(labelText: 'বিবরণ')),
                if (note.type == 'text' || note.type == 'lecture') ...[
                  const SizedBox(height: 10),
                  TextField(controller: textCtl, maxLines: 6, decoration: const InputDecoration(labelText: 'কনটেন্ট')),
                ],
                if (note.type == 'link' || note.type == 'video_youtube' || note.type == 'lecture') ...[
                  const SizedBox(height: 10),
                  TextField(controller: linkCtl, decoration: const InputDecoration(labelText: 'URL')),
                ],
                SwitchListTile(
                  value: published,
                  title: Text('Publish', style: GoogleFonts.hindSiliguri(fontSize: 14)),
                  onChanged: (v) => setLocal(() => published = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('বাতিল')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('সংরক্ষণ')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    await _repo.updateNote(
      note.copyWith(
        title: titleCtl.text.trim(),
        description: descCtl.text.trim().isEmpty ? null : descCtl.text.trim(),
        content: textCtl.text.trim().isEmpty ? null : textCtl.text.trim(),
        textContent: textCtl.text.trim().isEmpty ? null : textCtl.text.trim(),
        externalUrl: note.type == 'link' ? (linkCtl.text.trim().isEmpty ? null : linkCtl.text.trim()) : note.externalUrl,
        youtubeUrl: (note.type == 'video_youtube' || note.type == 'lecture')
            ? (linkCtl.text.trim().isEmpty ? null : linkCtl.text.trim())
            : note.youtubeUrl,
        fileUrl: (note.type == 'video_youtube' || note.type == 'lecture')
            ? (linkCtl.text.trim().isEmpty ? null : linkCtl.text.trim())
            : note.fileUrl,
        isPublished: published,
      ),
    );
    await _refresh();
  }

  Future<void> _addSuggestion(String chapterId) async {
    final title = TextEditingController();
    final content = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('সাজেশন যোগ', style: GoogleFonts.hindSiliguri()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: title, decoration: const InputDecoration(labelText: 'শিরোনাম *')),
            const SizedBox(height: 10),
            TextField(controller: content, maxLines: 4, decoration: const InputDecoration(labelText: 'কনটেন্ট')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('বাতিল')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('সংরক্ষণ')),
        ],
      ),
    );
    if (ok != true || title.text.trim().isEmpty) return;
    await _repo.addChapterSuggestion(
      courseId: widget.courseId,
      chapterId: chapterId,
      title: title.text.trim(),
      content: content.text.trim().isEmpty ? null : content.text.trim(),
    );
    await _refresh();
  }

  Future<void> _openUrl(String? url) async {
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _reload,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && _subjects.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _addSubject,
                      icon: const Icon(Icons.add),
                      label: Text('সাবজেক্ট যোগ করুন', style: GoogleFonts.hindSiliguri()),
                      style: FilledButton.styleFrom(backgroundColor: context.themePrimary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.storage_outlined),
                  title: Text('স্টোরেজ ব্যবহৃত', style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w700)),
                  subtitle: Text('${(_storageUsageBytes / (1024 * 1024)).toStringAsFixed(2)} MB', style: GoogleFonts.nunito()),
                ),
              ),
              const SizedBox(height: 8),
              ..._subjects.map(_subjectCard),
            ],
          ),
        );
      },
    );
  }

  Widget _subjectCard(SubjectModel subject) {
    final chapters = _chapters[subject.id] ?? [];
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    subject.name,
                    style: GoogleFonts.hindSiliguri(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(onPressed: () => _addChapter(subject), icon: const Icon(Icons.playlist_add)),
              ],
            ),
            ...chapters.map(_chapterTile),
          ],
        ),
      ),
    );
  }

  Widget _chapterTile(ChapterModel chapter) {
    final notes = _notes[chapter.id] ?? [];
    final suggestions = _suggestions[chapter.id] ?? [];
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(chapter.name, style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600)),
      children: [
        Wrap(
          spacing: 6,
          children: [
            TextButton.icon(
              onPressed: () => _addNoteDialog(chapter.id),
              icon: const Icon(Icons.note_add_outlined, size: 18),
              label: Text('নোট যোগ', style: GoogleFonts.hindSiliguri()),
            ),
            TextButton.icon(
              onPressed: () => _addNoteDialog(chapter.id, forceLecture: true),
              icon: const Icon(Icons.smart_display_outlined, size: 18),
              label: Text('লেকচার যোগ', style: GoogleFonts.hindSiliguri()),
            ),
            TextButton.icon(
              onPressed: () => _bulkPdfUpload(chapter.id),
              icon: const Icon(Icons.upload_file_outlined, size: 18),
              label: Text('Bulk PDF', style: GoogleFonts.hindSiliguri()),
            ),
          ],
        ),
        ...notes.map(
          (n) => ListTile(
            dense: true,
            title: Text(n.title, style: GoogleFonts.hindSiliguri(fontSize: 14)),
            subtitle: Text(
              '${n.type} · ${n.viewCount ?? 0} views${n.isPublished == false ? ' · draft' : ''}',
              style: GoogleFonts.nunito(fontSize: 11),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'পাবলিক লিংক কপি',
                  icon: const Icon(Icons.public_outlined, size: 20),
                  onPressed: () async {
                    final t = n.publicShareToken?.trim();
                    if (t == null || t.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'শেয়ার টোকেন তৈরি হয়নি — একবার রিফ্রেশ করুন',
                            style: GoogleFonts.hindSiliguri(),
                          ),
                        ),
                      );
                      return;
                    }
                    final url = publicClassNoteUrl(t);
                    await Clipboard.setData(ClipboardData(text: url));
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'পাবলিক লিংক কপি হয়েছে',
                          style: GoogleFonts.hindSiliguri(),
                        ),
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.open_in_new, size: 20),
                  onPressed: () => _openUrl(n.externalUrl ?? n.youtubeUrl ?? n.fileUrl),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  onPressed: () => _editNote(n),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline, size: 20, color: Theme.of(context).colorScheme.error),
                  onPressed: () async {
                    await _repo.deleteNoteFileByUrl(n.fileUrl);
                    await _repo.deleteNote(n.id);
                    await _refresh();
                  },
                ),
              ],
            ),
          ),
        ),
        const Divider(),
        TextButton.icon(
          onPressed: () => _addSuggestion(chapter.id),
          icon: const Icon(Icons.lightbulb_outline, size: 18),
          label: Text('সাজেশন যোগ', style: GoogleFonts.hindSiliguri()),
        ),
        ...suggestions.map((s) => ListTile(title: Text(s.title, style: GoogleFonts.hindSiliguri(fontSize: 14)))),
      ],
    );
  }
}
