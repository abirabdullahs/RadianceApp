import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/supabase_client.dart';

/// Anonymous viewer for a published class note (`public_note_by_share_token` RPC).
class PublicClassNoteScreen extends StatefulWidget {
  const PublicClassNoteScreen({super.key, this.initialToken});

  final String? initialToken;

  @override
  State<PublicClassNoteScreen> createState() => _PublicClassNoteScreenState();
}

class _PublicClassNoteScreenState extends State<PublicClassNoteScreen> {
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _note;

  @override
  void initState() {
    super.initState();
    final t = widget.initialToken?.trim() ?? '';
    if (t.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
  }

  Future<void> _load() async {
    final token = widget.initialToken?.trim() ?? '';
    if (token.isEmpty) {
      setState(() {
        _error = 'লিংকে টোকেন নেই';
        _note = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final out = await supabaseClient.rpc(
        'public_note_by_share_token',
        params: <String, dynamic>{'p_token': token},
      );
      final map = out is Map ? Map<String, dynamic>.from(out) : null;
      final ok = map?['success'] == true;
      final noteRaw = map?['note'];
      if (!ok || noteRaw is! Map) {
        setState(() {
          _note = null;
          _error = 'নোট পাওয়া যায়নি বা প্রকাশিত নয়';
        });
      } else {
        setState(() {
          _note = Map<String, dynamic>.from(noteRaw);
          _error = null;
        });
      }
    } catch (e) {
      setState(() {
        _note = null;
        _error = '$e';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openUrl(String? url) async {
    final u = url?.trim();
    if (u == null || u.isEmpty) return;
    final uri = Uri.tryParse(u);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final n = _note;
    final title = (n?['title'] as String?)?.trim() ?? 'ক্লাস নোট';
    final type = (n?['type'] as String?)?.trim() ?? 'text';
    final desc = (n?['description'] as String?)?.trim();
    final fileUrl = (n?['file_url'] as String?)?.trim();
    final youtubeUrl = (n?['youtube_url'] as String?)?.trim();
    final externalUrl = (n?['external_url'] as String?)?.trim();
    final textContent = (n?['text_content'] as String?)?.trim();
    final content = (n?['content'] as String?)?.trim();
    final thumb = (n?['thumbnail_url'] as String?)?.trim();

    Widget body;
    if (_loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, style: GoogleFonts.hindSiliguri(), textAlign: TextAlign.center),
        ),
      );
    } else if (n == null) {
      body = Center(
        child: Text(
          'লিংকের টোকেন যোগ করে খুলুন',
          style: GoogleFonts.hindSiliguri(),
          textAlign: TextAlign.center,
        ),
      );
    } else if (type == 'pdf' || type == 'video_upload') {
      body = ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (desc != null && desc.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(desc, style: GoogleFonts.hindSiliguri()),
            ),
          FilledButton.icon(
            onPressed: fileUrl == null || fileUrl.isEmpty ? null : () => _openUrl(fileUrl),
            icon: const Icon(Icons.open_in_new),
            label: Text('খুলুন / ডাউনলোড', style: GoogleFonts.hindSiliguri()),
          ),
        ],
      );
    } else if (type == 'image') {
      body = ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (desc != null && desc.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(desc, style: GoogleFonts.hindSiliguri()),
            ),
          if (fileUrl != null && fileUrl.isNotEmpty)
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 4,
              child: Image.network(fileUrl, fit: BoxFit.contain),
            ),
        ],
      );
    } else if (type == 'link') {
      body = ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (desc != null && desc.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(desc, style: GoogleFonts.hindSiliguri()),
            ),
          FilledButton.icon(
            onPressed: externalUrl == null || externalUrl.isEmpty ? null : () => _openUrl(externalUrl),
            icon: const Icon(Icons.link),
            label: Text('লিংক খুলুন', style: GoogleFonts.hindSiliguri()),
          ),
        ],
      );
    } else if (type == 'video_youtube' || type == 'lecture') {
      final md = content ?? textContent ?? '';
      body = ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (desc != null && desc.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(desc, style: GoogleFonts.hindSiliguri()),
            ),
          if (youtubeUrl != null && youtubeUrl.isNotEmpty)
            FilledButton.icon(
              onPressed: () => _openUrl(youtubeUrl),
              icon: const Icon(Icons.play_circle_outline),
              label: Text('YouTube খুলুন', style: GoogleFonts.hindSiliguri()),
            ),
          if (md.isNotEmpty) ...[
            const SizedBox(height: 16),
            MarkdownBody(
              data: md,
              styleSheet: MarkdownStyleSheet(p: GoogleFonts.hindSiliguri()),
            ),
          ],
          if (fileUrl != null &&
              fileUrl.isNotEmpty &&
              (youtubeUrl == null || youtubeUrl.isEmpty))
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: OutlinedButton.icon(
                onPressed: () => _openUrl(fileUrl),
                icon: const Icon(Icons.attach_file),
                label: Text('মিডিয়া খুলুন', style: GoogleFonts.hindSiliguri()),
              ),
            ),
        ],
      );
    } else {
      final md = content ?? textContent ?? '';
      body = ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (desc != null && desc.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(desc, style: GoogleFonts.hindSiliguri()),
            ),
          if (md.isNotEmpty)
            MarkdownBody(data: md, styleSheet: MarkdownStyleSheet(p: GoogleFonts.hindSiliguri())),
          if (thumb != null && thumb.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Image.network(thumb),
            ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: GoogleFonts.hindSiliguri()),
      ),
      body: body,
    );
  }
}
