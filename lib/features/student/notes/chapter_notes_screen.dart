import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_markdown_latex/flutter_markdown_latex.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../widgets/student_drawer.dart';
import 'note_markdown_style.dart';
import 'repositories/notes_repository.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key, required this.chapterId});

  final String chapterId;

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final _repo = NotesRepository();
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _repo.listNotesForChapter(widget.chapterId);
  }

  Future<void> _reload() async {
    setState(() => _future = _repo.listNotesForChapter(widget.chapterId));
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const StudentDrawer(),
      appBar: AppBar(
        leading: const AppBarDrawerLeading(),
        automaticallyImplyLeading: false,
        leadingWidth: leadingWidthForDrawer(context),
        title: Text('ক্লাসনোট', style: GoogleFonts.hindSiliguri()),
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const DownloadedNotesScreen()),
            ),
            icon: const Icon(Icons.download_done_outlined),
            tooltip: 'ডাউনলোড',
          ),
          const AppBarDrawerAction(),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('লোড ব্যর্থ: ${snap.error}', style: GoogleFonts.hindSiliguri()));
          }
          final rows = snap.data ?? [];
          if (rows.isEmpty) {
            return Center(child: Text('কোনো নোট নেই', style: GoogleFonts.hindSiliguri()));
          }
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: rows.length,
              itemBuilder: (context, index) {
                final n = rows[index];
                final progress = (n['progress'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
                final isViewed = progress['is_viewed'] == true;
                final watched = (progress['video_watched_seconds'] as num?)?.toInt() ?? 0;
                final duration = (n['duration_seconds'] as num?)?.toInt() ?? 0;
                final isNew = _isNew(n['created_at'] as String?);
                return Card(
                  child: ListTile(
                    leading: _typeIcon((n['type'] as String?) ?? 'text'),
                    title: Text(n['title'] as String? ?? '', style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      _statusText(isViewed: isViewed, isNew: isNew, watched: watched, duration: duration),
                      style: GoogleFonts.hindSiliguri(fontSize: 12),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      await _repo.markViewed(n['id'] as String);
                      if (!mounted) return;
                      await Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => _NoteViewerScreen(note: n, repo: _repo)),
                      );
                      await _reload();
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  bool _isNew(String? iso) {
    if (iso == null) return false;
    final created = DateTime.tryParse(iso);
    if (created == null) return false;
    return DateTime.now().difference(created.toLocal()).inDays <= 7;
  }

  String _statusText({
    required bool isViewed,
    required bool isNew,
    required int watched,
    required int duration,
  }) {
    if (duration > 0 && watched > 0 && watched < duration) {
      final pct = (watched * 100 / duration).round();
      return '▶ $pct% দেখা হয়েছে';
    }
    if (isViewed) return '✅ দেখা হয়েছে';
    if (isNew) return '🆕 নতুন';
    return '⬜ দেখা হয়নি';
  }

  Widget _typeIcon(String type) {
    switch (type) {
      case 'pdf':
        return const Icon(Icons.picture_as_pdf_outlined);
      case 'video_youtube':
      case 'video_upload':
      case 'lecture':
        return const Icon(Icons.ondemand_video_outlined);
      case 'image':
        return const Icon(Icons.image_outlined);
      case 'link':
        return const Icon(Icons.link_outlined);
      default:
        return const Icon(Icons.article_outlined);
    }
  }
}

class _NoteViewerScreen extends StatelessWidget {
  const _NoteViewerScreen({required this.note, required this.repo});

  final Map<String, dynamic> note;
  final NotesRepository repo;

  @override
  Widget build(BuildContext context) {
    final type = note['type'] as String? ?? 'text';
    return Scaffold(
      appBar: AppBar(title: Text(note['title'] as String? ?? '', style: GoogleFonts.hindSiliguri())),
      body: switch (type) {
        'pdf' => _PdfViewer(note: note),
        'video_youtube' => _YoutubeViewer(note: note, repo: repo),
        'lecture' => _LectureViewer(note: note, repo: repo),
        'video_upload' => _ExternalOpenViewer(note: note),
        'image' => _ImageViewer(note: note),
        'link' => _ExternalOpenViewer(note: note),
        _ => _RichTextViewer(note: note),
      },
    );
  }
}

class _PdfViewer extends StatefulWidget {
  const _PdfViewer({required this.note});
  final Map<String, dynamic> note;

  @override
  State<_PdfViewer> createState() => _PdfViewerState();
}

class _PdfViewerState extends State<_PdfViewer> {
  String? _localPath;
  int _current = 0;
  int _total = 0;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    final url = (widget.note['file_url'] ?? widget.note['external_url']) as String?;
    if (url == null || url.isEmpty) return;
    final file = await _DownloadStore.downloadAndRegister(url, widget.note['title'] as String? ?? 'pdf');
    if (!mounted) return;
    setState(() => _localPath = file.path);
  }

  @override
  Widget build(BuildContext context) {
    final url = (widget.note['file_url'] ?? widget.note['external_url']) as String?;
    if (url == null || url.isEmpty) return const Center(child: Text('PDF URL পাওয়া যায়নি'));
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Expanded(child: Text('Page ${_current + 1} / ${_total == 0 ? '-' : _total}', style: GoogleFonts.nunito())),
              FilledButton.tonalIcon(
                onPressed: () async {
                  final uri = Uri.parse(url);
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                },
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _localPath == null
              ? const Center(child: CircularProgressIndicator())
              : PDFView(
                  filePath: _localPath!,
                  onRender: (pages) => setState(() => _total = pages ?? 0),
                  onPageChanged: (page, _) => setState(() => _current = page ?? 0),
                ),
        ),
      ],
    );
  }
}

class _YoutubeViewer extends StatefulWidget {
  const _YoutubeViewer({required this.note, required this.repo});
  final Map<String, dynamic> note;
  final NotesRepository repo;

  @override
  State<_YoutubeViewer> createState() => _YoutubeViewerState();
}

class _YoutubeViewerState extends State<_YoutubeViewer> {
  YoutubePlayerController? _controller;

  @override
  void initState() {
    super.initState();
    final url = (widget.note['youtube_url'] ?? widget.note['file_url']) as String?;
    final id = url == null ? null : YoutubePlayer.convertUrlToId(url);
    if (id != null) {
      _controller = YoutubePlayerController(
        initialVideoId: id,
        flags: const YoutubePlayerFlags(autoPlay: false),
      )..addListener(_onTick);
    }
  }

  void _onTick() {
    final c = _controller;
    if (c == null || !c.value.isReady) return;
    final watched = c.value.position.inSeconds;
    final total = c.metadata.duration.inSeconds;
    widget.repo.updateVideoProgress(
      noteId: widget.note['id'] as String,
      watchedSeconds: watched,
      durationSeconds: total,
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null) return const Center(child: Text('Invalid YouTube URL'));
    return YoutubePlayerBuilder(
      player: YoutubePlayer(controller: _controller!),
      builder: (context, player) => Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            player,
            const SizedBox(height: 10),
            Text('Playback speed, full screen, progress supported', style: GoogleFonts.nunito()),
          ],
        ),
      ),
    );
  }
}

class _LectureViewer extends StatelessWidget {
  const _LectureViewer({required this.note, required this.repo});

  final Map<String, dynamic> note;
  final NotesRepository repo;

  @override
  Widget build(BuildContext context) {
    final text = (note['text_content'] ?? note['content']) as String?;
    final youtube = (note['youtube_url'] ?? note['file_url']) as String?;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (youtube != null && youtube.isNotEmpty)
          SizedBox(height: 240, child: _YoutubeViewer(note: note, repo: repo)),
        if (text != null && text.trim().isNotEmpty)
          MarkdownBody(
            data: text,
            selectable: true,
            styleSheet: bengaliNoteMarkdownStyleSheet(context),
            extensionSet: md.ExtensionSet(
              md.ExtensionSet.gitHubFlavored.blockSyntaxes,
              <md.InlineSyntax>[LatexInlineSyntax()],
            ),
            blockSyntaxes: <md.BlockSyntax>[LatexBlockSyntax()],
            builders: <String, MarkdownElementBuilder>{'latex': LatexElementBuilder()},
            onTapLink: (text, href, title) async {
              if (href == null) return;
              final uri = Uri.tryParse(href);
              if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
            },
          ),
      ],
    );
  }
}

class _RichTextViewer extends StatelessWidget {
  const _RichTextViewer({required this.note});

  final Map<String, dynamic> note;

  @override
  Widget build(BuildContext context) {
    final text = (note['text_content'] ?? note['content']) as String?;
    if (text == null || text.trim().isEmpty) return const Center(child: Text('কনটেন্ট নেই'));
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: MarkdownBody(
        data: text,
        selectable: true,
        styleSheet: bengaliNoteMarkdownStyleSheet(context),
        extensionSet: md.ExtensionSet(
          md.ExtensionSet.gitHubFlavored.blockSyntaxes,
          <md.InlineSyntax>[LatexInlineSyntax()],
        ),
        blockSyntaxes: <md.BlockSyntax>[LatexBlockSyntax()],
        builders: <String, MarkdownElementBuilder>{'latex': LatexElementBuilder()},
      ),
    );
  }
}

class _ImageViewer extends StatelessWidget {
  const _ImageViewer({required this.note});
  final Map<String, dynamic> note;

  @override
  Widget build(BuildContext context) {
    final url = (note['file_url'] ?? note['external_url']) as String?;
    if (url == null || url.isEmpty) return const Center(child: Text('Image URL নেই'));
    return InteractiveViewer(
      child: Center(child: Image.network(url, fit: BoxFit.contain)),
    );
  }
}

class _ExternalOpenViewer extends StatelessWidget {
  const _ExternalOpenViewer({required this.note});
  final Map<String, dynamic> note;

  @override
  Widget build(BuildContext context) {
    final url = (note['external_url'] ?? note['youtube_url'] ?? note['file_url']) as String?;
    return Center(
      child: FilledButton.icon(
        onPressed: () async {
          if (url == null) return;
          final uri = Uri.tryParse(url);
          if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
        },
        icon: const Icon(Icons.open_in_browser),
        label: Text('Open Resource', style: GoogleFonts.hindSiliguri()),
      ),
    );
  }
}

class DownloadedNotesScreen extends StatefulWidget {
  const DownloadedNotesScreen({super.key});

  @override
  State<DownloadedNotesScreen> createState() => _DownloadedNotesScreenState();
}

class _DownloadedNotesScreenState extends State<DownloadedNotesScreen> {
  Map<String, dynamic> _items = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await _DownloadStore.readAll();
    if (!mounted) return;
    setState(() => _items = all);
  }

  Future<void> _delete(String key) async {
    await _DownloadStore.delete(key);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    var total = 0;
    for (final e in _items.values) {
      final m = Map<String, dynamic>.from(e as Map);
      total += (m['bytes'] as num?)?.toInt() ?? 0;
    }
    return Scaffold(
      appBar: AppBar(title: Text('ডাউনলোড করা নোট', style: GoogleFonts.hindSiliguri())),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          ListTile(
            leading: const Icon(Icons.storage_outlined),
            title: Text('ব্যবহৃত: ${(total / (1024 * 1024)).toStringAsFixed(2)} MB', style: GoogleFonts.hindSiliguri()),
            trailing: TextButton(
              onPressed: () async {
                await _DownloadStore.clearAll();
                await _load();
              },
              child: const Text('সব মুছুন'),
            ),
          ),
          ..._items.entries.map((e) {
            final m = Map<String, dynamic>.from(e.value as Map);
            final bytes = (m['bytes'] as num?)?.toInt() ?? 0;
            return Card(
              child: ListTile(
                title: Text(m['title'] as String? ?? 'Note', style: GoogleFonts.hindSiliguri()),
                subtitle: Text('${(bytes / 1024).toStringAsFixed(1)} KB', style: GoogleFonts.nunito()),
                trailing: IconButton(
                  onPressed: () => _delete(e.key),
                  icon: const Icon(Icons.delete_outline),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _DownloadStore {
  static const _key = 'downloaded_notes_v1';

  static Future<File> downloadAndRegister(String url, String title) async {
    final dir = await getApplicationDocumentsDirectory();
    final notesDir = Directory('${dir.path}/notes');
    if (!notesDir.existsSync()) {
      notesDir.createSync(recursive: true);
    }
    final name = '${DateTime.now().millisecondsSinceEpoch}_${url.hashCode}.pdf';
    final path = '${notesDir.path}/$name';
    final f = File(path);
    if (!f.existsSync()) {
      await Dio().download(url, path);
    }
    final prefs = await SharedPreferences.getInstance();
    final old = await readAll();
    old[url] = <String, dynamic>{
      'title': title,
      'path': path,
      'bytes': await f.length(),
      'saved_at': DateTime.now().toIso8601String(),
    };
    await prefs.setString(_key, jsonEncode(old));
    return f;
  }

  static Future<Map<String, dynamic>> readAll() async {
    final prefs = await SharedPreferences.getInstance();
    final text = prefs.getString(_key);
    if (text == null || text.isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(text);
    if (decoded is Map<String, dynamic>) return decoded;
    return <String, dynamic>{};
  }

  static Future<void> delete(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final all = await readAll();
    final m = all[key];
    if (m is Map<String, dynamic>) {
      final path = m['path'] as String?;
      if (path != null && path.isNotEmpty) {
        final file = File(path);
        if (file.existsSync()) {
          await file.delete();
        }
      }
    }
    all.remove(key);
    await prefs.setString(_key, jsonEncode(all));
  }

  static Future<void> clearAll() async {
    final all = await readAll();
    for (final key in all.keys.toList()) {
      await delete(key);
    }
  }
}
