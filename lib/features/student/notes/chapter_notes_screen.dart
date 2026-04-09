import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme.dart';
import '../widgets/student_drawer.dart';
import 'repositories/notes_repository.dart';

/// Chapter materials: [lecture] gets a distinct card; detail view renders markdown.
class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key, required this.chapterId});

  final String chapterId;

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = NotesRepository().listNotesForChapter(widget.chapterId);
  }

  Future<void> _reload() async {
    setState(() {
      _future = NotesRepository().listNotesForChapter(widget.chapterId);
    });
    await _future;
  }

  MarkdownStyleSheet _markdownStyle(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = MarkdownStyleSheet.fromTheme(Theme.of(context));
    return base.copyWith(
      p: GoogleFonts.hindSiliguri(
        fontSize: 15,
        height: 1.55,
        color: scheme.onSurface,
      ),
      h1: GoogleFonts.hindSiliguri(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: scheme.onSurface,
      ),
      h2: GoogleFonts.hindSiliguri(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: scheme.onSurface,
      ),
      h3: GoogleFonts.hindSiliguri(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
      listBullet: GoogleFonts.hindSiliguri(fontSize: 15, color: scheme.onSurface),
      code: GoogleFonts.firaCode(fontSize: 13, color: scheme.primary),
      blockquote: GoogleFonts.hindSiliguri(
        fontSize: 14,
        fontStyle: FontStyle.italic,
        color: scheme.onSurfaceVariant,
      ),
      a: GoogleFonts.hindSiliguri(
        fontSize: 15,
        color: scheme.primary,
        decoration: TextDecoration.underline,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      drawer: const StudentDrawer(),
      appBar: AppBar(
        leading: const AppBarDrawerLeading(),
        automaticallyImplyLeading: false,
        leadingWidth: leadingWidthForDrawer(context),
        title: Text('নোট ও লেকচার', style: GoogleFonts.hindSiliguri()),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'লোড ব্যর্থ: ${snap.error}',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.hindSiliguri(color: scheme.error),
                ),
              ),
            );
          }
          final rows = snap.data ?? [];
          if (rows.isEmpty) {
            return Center(
              child: Text('কোনো নোট নেই', style: GoogleFonts.hindSiliguri()),
            );
          }

          final lectures = rows.where((n) => (n['type'] as String?) == 'lecture').toList();
          final others = rows.where((n) => (n['type'] as String?) != 'lecture').toList();

          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                if (lectures.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Icon(Icons.school_outlined, color: context.themePrimary, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          'লেকচার',
                          style: GoogleFonts.hindSiliguri(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: context.themePrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...lectures.map((n) => _LectureCard(
                        note: n,
                        onTap: () => _openDetail(context, n),
                      )),
                  if (others.isNotEmpty) const SizedBox(height: 16),
                ],
                if (others.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Icon(Icons.folder_outlined, color: scheme.onSurfaceVariant, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          'অন্যান্য',
                          style: GoogleFonts.hindSiliguri(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...others.map((n) => _OtherNoteTile(
                        note: n,
                        onTap: () => _openDetail(context, n),
                      )),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  void _openDetail(BuildContext context, Map<String, dynamic> note) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (ctx) => _NoteDetailScreen(
          note: note,
          markdownStyle: _markdownStyle(ctx),
        ),
      ),
    );
  }
}

/// Distinct UI for admin-created `lecture` notes (markdown + optional video).
class _LectureCard extends StatelessWidget {
  const _LectureCard({required this.note, required this.onTap});

  final Map<String, dynamic> note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final title = note['title'] as String? ?? '';
    final content = note['content'] as String?;
    final fileUrl = note['file_url'] as String?;
    final preview = _previewText(content);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: context.themePrimary.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: context.themePrimary.withValues(alpha: 0.35)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: context.themePrimary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.play_circle_fill_rounded, color: context.themePrimary, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.hindSiliguri(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (fileUrl != null && fileUrl.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.ondemand_video, size: 16, color: scheme.primary),
                              const SizedBox(width: 4),
                              Text(
                                'ভিডিও আছে',
                                style: GoogleFonts.hindSiliguri(
                                  fontSize: 12,
                                  color: scheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
                ],
              ),
              if (preview.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  preview,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.hindSiliguri(
                    fontSize: 14,
                    height: 1.4,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _previewText(String? md) {
    if (md == null || md.trim().isEmpty) return '';
    var s = md.replaceAll(RegExp(r'[#*_`>\[\]\(\)]'), ' ');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (s.length > 160) return '${s.substring(0, 160)}…';
    return s;
  }
}

class _OtherNoteTile extends StatelessWidget {
  const _OtherNoteTile({required this.note, required this.onTap});

  final Map<String, dynamic> note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final title = note['title'] as String? ?? '';
    final type = note['type'] as String? ?? '';
    IconData icon;
    switch (type) {
      case 'pdf':
        icon = Icons.picture_as_pdf_outlined;
        break;
      case 'video_youtube':
      case 'video_upload':
        icon = Icons.video_library_outlined;
        break;
      case 'image':
        icon = Icons.image_outlined;
        break;
      case 'link':
        icon = Icons.link;
        break;
      default:
        icon = Icons.article_outlined;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: scheme.primary),
        title: Text(title, style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600)),
        subtitle: Text(type, style: GoogleFonts.nunito(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _NoteDetailScreen extends StatelessWidget {
  const _NoteDetailScreen({
    required this.note,
    required this.markdownStyle,
  });

  final Map<String, dynamic> note;
  final MarkdownStyleSheet markdownStyle;

  bool get _isLecture => (note['type'] as String?) == 'lecture';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final title = note['title'] as String? ?? '';
    final type = note['type'] as String? ?? '';
    final content = note['content'] as String?;
    final fileUrl = note['file_url'] as String?;

    return Scaffold(
      drawer: const StudentDrawer(),
      appBar: AppBar(
        leading: const AppBarDrawerLeading(),
        automaticallyImplyLeading: false,
        leadingWidth: leadingWidthForDrawer(context),
        title: Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_isLecture)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: context.themePrimary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: context.themePrimary.withValues(alpha: 0.35)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.school_outlined, color: context.themePrimary),
                    const SizedBox(width: 10),
                    Text(
                      'লেকচার',
                      style: GoogleFonts.hindSiliguri(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: context.themePrimary,
                      ),
                    ),
                  ],
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Chip(
                  label: Text(type, style: GoogleFonts.nunito(fontSize: 12)),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            if (content != null && content.trim().isNotEmpty)
              MarkdownBody(
                data: content,
                selectable: true,
                styleSheet: markdownStyle,
                onTapLink: (text, href, title) async {
                  if (href == null || href.isEmpty) return;
                  final u = Uri.tryParse(href);
                  if (u != null && await canLaunchUrl(u)) {
                    await launchUrl(u, mode: LaunchMode.externalApplication);
                  }
                },
              )
            else if (type == 'text' || type == 'lecture')
              Text(
                'কোনো লিখিত বিষয়বস্তু নেই।',
                style: GoogleFonts.hindSiliguri(color: scheme.onSurfaceVariant),
              ),
            if (fileUrl != null && fileUrl.isNotEmpty) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () async {
                  final u = Uri.tryParse(fileUrl);
                  if (u != null && await canLaunchUrl(u)) {
                    await launchUrl(u, mode: LaunchMode.externalApplication);
                  }
                },
                icon: const Icon(Icons.open_in_new),
                label: Text(
                  type == 'lecture' ? 'ভিডিও লিংক খুলুন' : 'লিংক খুলুন',
                  style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: context.themePrimary,
                  foregroundColor: scheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ],
            if ((type == 'pdf' || type == 'link' || type == 'video_youtube') &&
                fileUrl != null &&
                fileUrl.isNotEmpty &&
                (content == null || content.trim().isEmpty))
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'উপরের বাটনে ট্যাপ করে ফাইল বা লিংক খুলুন।',
                  style: GoogleFonts.hindSiliguri(
                    fontSize: 13,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
