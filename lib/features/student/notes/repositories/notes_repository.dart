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
    final mapped = (rows as List<dynamic>)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final progress = await _loadProgressForNotes(
      mapped.map((e) => e['id'] as String).where((e) => e.isNotEmpty).toList(),
    );
    for (final row in mapped) {
      final p = progress[row['id']];
      if (p != null) {
        row['progress'] = p;
      }
    }
    return mapped;
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

  Future<void> markViewed(String noteId) async {
    await _client.rpc('upsert_note_progress', params: <String, dynamic>{
      'p_note_id': noteId,
      'p_is_viewed': true,
      'p_video_watched_seconds': 0,
    });
    await _client.rpc('increment_view_count', params: <String, dynamic>{'p_note_id': noteId});
  }

  Future<void> updateVideoProgress({
    required String noteId,
    required int watchedSeconds,
    required int durationSeconds,
  }) async {
    await _client.rpc('upsert_note_progress', params: <String, dynamic>{
      'p_note_id': noteId,
      'p_is_viewed': watchedSeconds >= durationSeconds && durationSeconds > 0,
      'p_video_watched_seconds': watchedSeconds,
    });
  }

  Future<Map<String, Map<String, dynamic>>> _loadProgressForNotes(List<String> noteIds) async {
    if (noteIds.isEmpty) return <String, Map<String, dynamic>>{};
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return <String, Map<String, dynamic>>{};
    final rows = await _client
        .from(kTableNoteProgress)
        .select('note_id,is_viewed,video_watched_seconds,viewed_at')
        .eq('student_id', uid)
        .inFilter('note_id', noteIds);
    final out = <String, Map<String, dynamic>>{};
    for (final e in rows as List<dynamic>) {
      final m = Map<String, dynamic>.from(e as Map);
      final id = m['note_id'] as String?;
      if (id != null) out[id] = m;
    }
    return out;
  }
}
