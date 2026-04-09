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
        .order('display_order', ascending: true)
        .order('created_at', ascending: true);
    return (rows as List<dynamic>)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  /// Latest published lecture note visible to the student (RLS: enrolled chapters).
  /// Returns `null` if none or if `lecture` type is unavailable in the project.
  Future<Map<String, dynamic>?> getLatestLectureForCurrentStudent() async {
    try {
      final rows = await _client
          .from(kTableNotes)
          .select('id, title, chapter_id, updated_at')
          .eq('type', 'lecture')
          .order('updated_at', ascending: false)
          .limit(1);
      final list = rows as List<dynamic>;
      if (list.isEmpty) return null;
      return Map<String, dynamic>.from(list.first as Map);
    } catch (_) {
      return null;
    }
  }
}
