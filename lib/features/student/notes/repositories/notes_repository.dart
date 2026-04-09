import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants.dart';
import '../../../../core/supabase_client.dart';

/// Study materials (`notes` table).
class NotesRepository {
  NotesRepository({SupabaseClient? client}) : _client = client ?? supabaseClient;

  final SupabaseClient _client;

  Future<List<Map<String, dynamic>>> listNotesForChapter(String chapterId) async {
    final rows = await _client
        .from(kTableNotes)
        .select()
        .eq('chapter_id', chapterId)
        .or('is_published.eq.true,is_published.is.null')
        .order('created_at', ascending: false);
    return (rows as List<dynamic>)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }
}
