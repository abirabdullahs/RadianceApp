import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/theme.dart';
import '../../../../shared/models/chapter_model.dart';
import '../../../../shared/models/chapter_suggestion_model.dart';
import '../../../../shared/models/note_model.dart';
import '../../../../shared/models/subject_model.dart';
import '../repositories/course_repository.dart';

/// Subjects → chapters → lectures ([notes] type `lecture`) + per-chapter [suggestions].
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
      final ch = await _repo.getChapters(s.id);
      _chapters[s.id] = ch;
      for (final c in ch) {
        final notes = await _repo.getNotesForChapter(c.id);
        _notes[c.id] = notes;
        final sug = await _repo.getSuggestionsForChapter(c.id);
        _suggestions[c.id] = sug;
      }
    }
    if (mounted) {
      setState(() {
        _subjects = subjects;
      });
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _reload = _load();
    });
    await _reload;
  }

  Future<void> _addSubject() async {
    final name = TextEditingController();
    final desc = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('নতুন সাবজেক্ট', style: GoogleFonts.hindSiliguri()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'নাম *'),
            ),
            TextField(
              controller: desc,
              decoration: const InputDecoration(labelText: 'বিবরণ'),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('বাতিল')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('যোগ')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    if (name.text.trim().isEmpty) return;
    await _repo.addSubject(
      SubjectModel(
        id: '',
        courseId: widget.courseId,
        name: name.text.trim(),
        description: desc.text.trim().isEmpty ? null : desc.text.trim(),
        displayOrder: _subjects.length,
        isActive: true,
      ),
    );
    await _refresh();
  }

  Future<void> _addChapter(SubjectModel subject) async {
    final name = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('নতুন অধ্যায়', style: GoogleFonts.hindSiliguri()),
        content: TextField(
          controller: name,
          decoration: const InputDecoration(labelText: 'অধ্যায়ের নাম *'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('বাতিল')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('যোগ')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    if (name.text.trim().isEmpty) return;
    final list = _chapters[subject.id] ?? [];
    await _repo.addChapter(
      ChapterModel(
        id: '',
        subjectId: subject.id,
        name: name.text.trim(),
        description: null,
        displayOrder: list.length,
        isActive: true,
      ),
    );
    await _refresh();
  }

  Future<void> _addLecture(String chapterId) async {
    final title = TextEditingController();
    final content = TextEditingController();
    final video = TextEditingController();
    var published = true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text('নতুন লেকচার', style: GoogleFonts.hindSiliguri()),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: title,
                  decoration: const InputDecoration(labelText: 'শিরোনাম *'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: content,
                  decoration: const InputDecoration(
                    labelText: 'মার্কডাউন বিষয়বস্তু',
                    alignLabelWithHint: true,
                  ),
                  maxLines: 8,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: video,
                  decoration: const InputDecoration(
                    labelText: 'ভিডিও লিংক (ঐচ্ছিক)',
                    hintText: 'YouTube বা অন্য URL',
                  ),
                ),
                SwitchListTile(
                  title: Text('প্রকাশিত', style: GoogleFonts.hindSiliguri(fontSize: 14)),
                  value: published,
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
    if (ok != true || !mounted) return;
    if (title.text.trim().isEmpty) return;
    final order = await _repo.nextNoteDisplayOrder(chapterId);
    await _repo.addNote(
      NoteModel(
        id: '',
        chapterId: chapterId,
        title: title.text.trim(),
        description: null,
        type: 'lecture',
        fileUrl: video.text.trim().isEmpty ? null : video.text.trim(),
        content: content.text.trim().isEmpty ? null : content.text.trim(),
        isPublished: published,
        displayOrder: order,
      ),
    );
    await _refresh();
  }

  Future<void> _addSuggestion(String chapterId) async {
    final title = TextEditingController();
    final content = TextEditingController();
    final pdf = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('চ্যাপ্টার সাজেশন', style: GoogleFonts.hindSiliguri()),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: title,
                decoration: const InputDecoration(labelText: 'শিরোনাম *'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: content,
                decoration: const InputDecoration(
                  labelText: 'মার্কডাউন',
                  alignLabelWithHint: true,
                ),
                maxLines: 6,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: pdf,
                decoration: const InputDecoration(
                  labelText: 'PDF লিংক (ঐচ্ছিক)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('বাতিল')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('সংরক্ষণ')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    if (title.text.trim().isEmpty) return;
    await _repo.addChapterSuggestion(
      courseId: widget.courseId,
      chapterId: chapterId,
      title: title.text.trim(),
      content: content.text.trim().isEmpty ? null : content.text.trim(),
      pdfUrl: pdf.text.trim().isEmpty ? null : pdf.text.trim(),
    );
    await _refresh();
  }

  Future<void> _openUrl(String? url) async {
    if (url == null || url.isEmpty) return;
    final u = Uri.tryParse(url);
    if (u != null && await canLaunchUrl(u)) {
      await launchUrl(u, mode: LaunchMode.externalApplication);
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
              FilledButton.icon(
                onPressed: _addSubject,
                icon: const Icon(Icons.add),
                label: Text('সাবজেক্ট যোগ করুন', style: GoogleFonts.hindSiliguri()),
                style: FilledButton.styleFrom(backgroundColor: context.themePrimary),
              ),
              const SizedBox(height: 16),
              if (_subjects.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'কোনো সাবজেক্ট নেই। উপরের বাটনে যোগ করুন।',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.hindSiliguri(color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ),
                ),
              ..._subjects.map((s) => _subjectCard(s)),
            ],
          ),
        );
      },
    );
  }

  Widget _subjectCard(SubjectModel s) {
    final chapters = _chapters[s.id] ?? [];
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    s.name,
                    style: GoogleFonts.hindSiliguri(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.playlist_add, color: context.themePrimary),
                  tooltip: 'অধ্যায়',
                  onPressed: () => _addChapter(s),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text('মুছবেন?', style: GoogleFonts.hindSiliguri()),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('না')),
                          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('হ্যাঁ')),
                        ],
                      ),
                    );
                    if (ok == true && mounted) {
                      await _repo.deleteSubject(s.id);
                      await _refresh();
                    }
                  },
                ),
              ],
            ),
            if (s.description != null && s.description!.isNotEmpty)
              Text(s.description!, style: GoogleFonts.hindSiliguri(fontSize: 13)),
            const SizedBox(height: 8),
            if (chapters.isEmpty)
              Text('কোনো অধ্যায় নেই', style: GoogleFonts.hindSiliguri(color: Theme.of(context).colorScheme.outline)),
            ...chapters.map(_chapterTile),
          ],
        ),
      ),
    );
  }

  Widget _chapterTile(ChapterModel ch) {
    final notes = _notes[ch.id] ?? [];
    final sug = _suggestions[ch.id] ?? [];
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(ch.name, style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600)),
      trailing: IconButton(
        icon: Icon(Icons.delete_outline, size: 20, color: Theme.of(context).colorScheme.error),
        onPressed: () async {
          final ok = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text('অধ্যায় মুছবেন?', style: GoogleFonts.hindSiliguri()),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('না')),
                FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('হ্যাঁ')),
              ],
            ),
          );
          if (ok == true && mounted) {
            await _repo.deleteChapter(ch.id);
            await _refresh();
          }
        },
      ),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => _addLecture(ch.id),
            icon: const Icon(Icons.smart_display_outlined, size: 18),
            label: Text('লেকচার যোগ', style: GoogleFonts.hindSiliguri()),
          ),
        ),
        ...notes.map(
          (n) => ListTile(
            dense: true,
            title: Text(n.title, style: GoogleFonts.hindSiliguri(fontSize: 14)),
            subtitle: Text(
              '${n.type}${n.isPublished == false ? ' · খসড়া' : ''}',
              style: GoogleFonts.nunito(fontSize: 11),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (n.fileUrl != null && n.fileUrl!.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.ondemand_video, size: 20),
                    onPressed: () => _openUrl(n.fileUrl),
                  ),
                IconButton(
                  icon: Icon(Icons.delete_outline, size: 20, color: Theme.of(context).colorScheme.error),
                  onPressed: () async {
                    await _repo.deleteNote(n.id);
                    await _refresh();
                  },
                ),
              ],
            ),
          ),
        ),
        const Divider(),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => _addSuggestion(ch.id),
            icon: const Icon(Icons.lightbulb_outline, size: 18),
            label: Text('সাজেশন যোগ', style: GoogleFonts.hindSiliguri()),
          ),
        ),
        ...sug.map(
          (g) => ListTile(
            dense: true,
            title: Text(g.title, style: GoogleFonts.hindSiliguri(fontSize: 14)),
            subtitle: g.pdfUrl != null && g.pdfUrl!.isNotEmpty
                ? Text('PDF', style: GoogleFonts.nunito(fontSize: 11))
                : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (g.pdfUrl != null && g.pdfUrl!.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.picture_as_pdf_outlined, size: 20),
                    onPressed: () => _openUrl(g.pdfUrl),
                  ),
                IconButton(
                  icon: Icon(Icons.delete_outline, size: 20, color: Theme.of(context).colorScheme.error),
                  onPressed: () async {
                    await _repo.deleteChapterSuggestion(g.id);
                    await _refresh();
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
