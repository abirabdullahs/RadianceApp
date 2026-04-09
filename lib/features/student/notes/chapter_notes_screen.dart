import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';

import 'repositories/notes_repository.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('নোট', style: GoogleFonts.hindSiliguri()),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final rows = snap.data!;
          if (rows.isEmpty) {
            return Center(
              child: Text('কোনো নোট নেই', style: GoogleFonts.hindSiliguri()),
            );
          }
          return ListView.builder(
            itemCount: rows.length,
            itemBuilder: (context, i) {
              final n = rows[i];
              final title = n['title'] as String? ?? '';
              final type = n['type'] as String? ?? '';
              final fileUrl = n['file_url'] as String?;
              return ListTile(
                title: Text(title, style: GoogleFonts.hindSiliguri()),
                subtitle: Text(type, style: GoogleFonts.nunito(fontSize: 12)),
                trailing: const Icon(Icons.open_in_new),
                onTap: () async {
                  if (fileUrl != null && fileUrl.isNotEmpty) {
                    final u = Uri.tryParse(fileUrl);
                    if (u != null && await canLaunchUrl(u)) {
                      await launchUrl(u, mode: LaunchMode.externalApplication);
                    }
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}
