import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math';
import 'dart:typed_data';

import '../../../core/constants.dart';
import '../../../core/supabase_client.dart';
import '../../../shared/models/qbank_models.dart';

class QBankRepository {
  QBankRepository({SupabaseClient? client}) : _client = client ?? supabaseClient;

  final SupabaseClient _client;

  static const _sessionCols =
      'id,name,name_bn,display_order,is_active,created_at';
  static const _subjectCols =
      'id,session_id,name,name_bn,display_order,is_active,created_at';
  static const _chapterCols =
      'id,subject_id,name,name_bn,display_order,is_active,created_at';
  static const _chapterStatsCols = 'chapter_id,subject_id,mcq_count,cq_count';
  static const _mcqCols =
      'id,chapter_id,question_text,image_url,option_a,option_b,option_c,option_d,correct_option,explanation,explanation_image_url,difficulty,source,board_year,board_name,tags,is_published,created_by,created_at,updated_at';
  static const _cqCols =
      'id,chapter_id,stem_text,stem_image_url,ga_text,ga_image_url,ga_answer,ga_marks,gha_text,gha_image_url,gha_answer,gha_marks,difficulty,source,board_year,board_name,tags,is_published,created_by,created_at,updated_at';
  static const _bookmarkCols =
      'id,student_id,question_type,question_id,note,created_at';
  static const _practiceSessionCols =
      'id,chapter_id,question_type,total_questions,correct_answers,started_at,completed_at';

  Future<List<QbankSession>> getSessions() async {
    final rows = await _client
        .from(kTableQbankSessions)
        .select(_sessionCols)
        .order('display_order', ascending: true);
    return (rows as List<dynamic>)
        .map((e) => QbankSession.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<QbankSubject>> getSubjects(String sessionId) async {
    final rows = await _client
        .from(kTableQbankSubjects)
        .select(_subjectCols)
        .eq('session_id', sessionId)
        .order('display_order', ascending: true);
    return (rows as List<dynamic>)
        .map((e) => QbankSubject.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<QbankSubject> addSubject({
    required String sessionId,
    required String name,
    required String nameBn,
    int displayOrder = 0,
    bool isActive = true,
  }) async {
    final row = await _client
        .from(kTableQbankSubjects)
        .insert({
          'session_id': sessionId,
          'name': name.trim(),
          'name_bn': nameBn.trim(),
          'display_order': displayOrder,
          'is_active': isActive,
        })
        .select(_subjectCols)
        .single();
    return QbankSubject.fromJson(Map<String, dynamic>.from(row));
  }

  Future<List<QbankChapter>> getChapters(String subjectId) async {
    final rows = await _client
        .from(kTableQbankChapters)
        .select(_chapterCols)
        .eq('subject_id', subjectId)
        .order('display_order', ascending: true);
    return (rows as List<dynamic>)
        .map((e) => QbankChapter.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<QbankChapter> addChapter({
    required String subjectId,
    required String name,
    required String nameBn,
    int displayOrder = 0,
    bool isActive = true,
  }) async {
    final row = await _client
        .from(kTableQbankChapters)
        .insert({
          'subject_id': subjectId,
          'name': name.trim(),
          'name_bn': nameBn.trim(),
          'display_order': displayOrder,
          'is_active': isActive,
        })
        .select(_chapterCols)
        .single();
    return QbankChapter.fromJson(Map<String, dynamic>.from(row));
  }

  Future<List<QbankChapterStats>> getChapterStatsForSubject(String subjectId) async {
    final rows = await _client
        .from('qbank_chapter_stats')
        .select(_chapterStatsCols)
        .eq('subject_id', subjectId);
    return (rows as List<dynamic>)
        .map((e) =>
            QbankChapterStats.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<QbankMcq>> getMcqQuestions({
    required String chapterId,
    String? difficulty,
    String? source,
    int? boardYear,
    int? limit,
    int? offset,
  }) async {
    dynamic query = _client.from(kTableQbankMcq).select(_mcqCols).eq('chapter_id', chapterId);
    if (difficulty != null && difficulty.isNotEmpty) {
      query = query.eq('difficulty', difficulty);
    }
    if (source != null && source.isNotEmpty) {
      query = query.eq('source', source);
    }
    if (boardYear != null) {
      query = query.eq('board_year', boardYear);
    }
    query = query.order('created_at', ascending: false);
    if (limit != null) {
      final from = offset ?? 0;
      final to = from + limit - 1;
      query = query.range(from, to);
    }
    final rows = await query;
    return (rows as List<dynamic>)
        .map((e) => QbankMcq.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<QbankCq>> getCqQuestions({
    required String chapterId,
    String? difficulty,
    String? source,
    int? boardYear,
    int? limit,
    int? offset,
  }) async {
    dynamic query = _client.from(kTableQbankCq).select(_cqCols).eq('chapter_id', chapterId);
    if (difficulty != null && difficulty.isNotEmpty) {
      query = query.eq('difficulty', difficulty);
    }
    if (source != null && source.isNotEmpty) {
      query = query.eq('source', source);
    }
    if (boardYear != null) {
      query = query.eq('board_year', boardYear);
    }
    query = query.order('created_at', ascending: false);
    if (limit != null) {
      final from = offset ?? 0;
      final to = from + limit - 1;
      query = query.range(from, to);
    }
    final rows = await query;
    return (rows as List<dynamic>)
        .map((e) => QbankCq.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<QbankSearchResult>> searchQuestions(
    String query, {
    String? sessionId,
    String? subjectId,
    String? type,
    int limit = 30,
  }) async {
    final rows = await _client.rpc(
      'qbank_search_questions',
      params: <String, dynamic>{
        'p_query': query,
        'p_session_id': sessionId,
        'p_subject_id': subjectId,
        'p_question_type': type,
        'p_limit': limit,
      },
    );
    return (rows as List<dynamic>)
        .map((e) => QbankSearchResult.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> toggleBookmark({
    required String studentId,
    required String questionType,
    required String questionId,
    String? note,
  }) async {
    final existing = await _client
        .from(kTableQbankBookmarksV2)
        .select('id')
        .eq('student_id', studentId)
        .eq('question_type', questionType)
        .eq('question_id', questionId)
        .maybeSingle();
    if (existing == null) {
      await _client.from(kTableQbankBookmarksV2).insert(<String, dynamic>{
        'student_id': studentId,
        'question_type': questionType,
        'question_id': questionId,
        'note': note,
      });
    } else {
      await _client
          .from(kTableQbankBookmarksV2)
          .delete()
          .eq('student_id', studentId)
          .eq('question_type', questionType)
          .eq('question_id', questionId);
    }
  }

  Future<List<QbankBookmarkItem>> getBookmarks(String studentId) async {
    final rows = await _client
        .from(kTableQbankBookmarksV2)
        .select(_bookmarkCols)
        .eq('student_id', studentId)
        .order('created_at', ascending: false);
    return (rows as List<dynamic>)
        .map((e) =>
            QbankBookmarkItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> updateBookmarkNote({
    required String bookmarkId,
    String? note,
  }) async {
    await _client.from(kTableQbankBookmarksV2).update({
      'note': (note == null || note.trim().isEmpty) ? null : note.trim(),
    }).eq('id', bookmarkId);
  }

  Future<void> removeBookmarkById(String bookmarkId) async {
    await _client.from(kTableQbankBookmarksV2).delete().eq('id', bookmarkId);
  }

  Future<List<QbankBookmarkView>> getBookmarkViews(String studentId) async {
    final items = await getBookmarks(studentId);
    if (items.isEmpty) return const [];
    final mcqIds = items
        .where((e) => e.questionType == 'mcq')
        .map((e) => e.questionId)
        .toList();
    final cqIds = items
        .where((e) => e.questionType == 'cq')
        .map((e) => e.questionId)
        .toList();
    final preview = <String, String>{};
    if (mcqIds.isNotEmpty) {
      final rows = await _client
          .from(kTableQbankMcq)
          .select('id,question_text')
          .inFilter('id', mcqIds);
      for (final r in rows as List<dynamic>) {
        final m = Map<String, dynamic>.from(r as Map);
        preview[m['id'] as String] = (m['question_text'] as String? ?? '').trim();
      }
    }
    if (cqIds.isNotEmpty) {
      final rows =
          await _client.from(kTableQbankCq).select('id,stem_text').inFilter('id', cqIds);
      for (final r in rows as List<dynamic>) {
        final m = Map<String, dynamic>.from(r as Map);
        preview[m['id'] as String] = (m['stem_text'] as String? ?? '').trim();
      }
    }
    return items
        .map((b) => QbankBookmarkView(
              bookmark: b,
              previewText: preview[b.questionId] ?? b.questionId,
            ))
        .toList();
  }

  Future<String> startPracticeSession({
    required String studentId,
    String? chapterId,
    required String questionType,
    required int totalQuestions,
  }) async {
    final row = await _client
        .from(kTableQbankPracticeSessions)
        .insert(<String, dynamic>{
          'student_id': studentId,
          'chapter_id': chapterId,
          'question_type': questionType,
          'total_questions': totalQuestions,
        })
        .select('id')
        .single();
    return Map<String, dynamic>.from(row as Map)['id'] as String;
  }

  Future<void> savePracticeAnswer({
    required String sessionId,
    required String questionId,
    required String questionType,
    String? selectedOption,
    bool? isCorrect,
  }) async {
    await _client.from(kTableQbankPracticeAnswers).insert(<String, dynamic>{
      'session_id': sessionId,
      'question_id': questionId,
      'question_type': questionType,
      'selected_option': selectedOption,
      'is_correct': isCorrect,
    });
  }

  Future<void> completePracticeSession({
    required String sessionId,
    required int correctAnswers,
  }) async {
    await _client.from(kTableQbankPracticeSessions).update(<String, dynamic>{
      'correct_answers': correctAnswers,
      'completed_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', sessionId);
  }

  Future<List<QbankPracticeSessionView>> listPracticeHistory({
    required String studentId,
    String? chapterId,
    int limit = 20,
  }) async {
    dynamic q = _client
        .from(kTableQbankPracticeSessions)
        .select(_practiceSessionCols)
        .eq('student_id', studentId)
        .order('started_at', ascending: false)
        .limit(limit);
    if (chapterId != null && chapterId.isNotEmpty) {
      q = q.eq('chapter_id', chapterId);
    }
    final rows = await q;
    return (rows as List<dynamic>)
        .map((e) => QbankPracticeSessionView.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  // Admin CRUD
  Future<QbankMcq> addMcq(QbankMcq mcq) async {
    final row = await _client
        .from(kTableQbankMcq)
        .insert(mcq.toInsertJson())
        .select(_mcqCols)
        .single();
    return QbankMcq.fromJson(Map<String, dynamic>.from(row));
  }

  Future<QbankCq> addCq(QbankCq cq) async {
    final row = await _client
        .from(kTableQbankCq)
        .insert(cq.toInsertJson())
        .select(_cqCols)
        .single();
    return QbankCq.fromJson(Map<String, dynamic>.from(row));
  }

  Future<void> updateMcq(String id, Map<String, dynamic> patch) async {
    await _client.from(kTableQbankMcq).update(patch).eq('id', id);
  }

  Future<void> updateCq(String id, Map<String, dynamic> patch) async {
    await _client.from(kTableQbankCq).update(patch).eq('id', id);
  }

  Future<void> deleteMcq(String id) async {
    await _client.from(kTableQbankMcq).delete().eq('id', id);
  }

  Future<void> deleteCq(String id) async {
    await _client.from(kTableQbankCq).delete().eq('id', id);
  }

  Future<QbankMcq> getMcqById(String id) async {
    final row = await _client.from(kTableQbankMcq).select(_mcqCols).eq('id', id).single();
    return QbankMcq.fromJson(Map<String, dynamic>.from(row));
  }

  Future<QbankCq> getCqById(String id) async {
    final row = await _client.from(kTableQbankCq).select(_cqCols).eq('id', id).single();
    return QbankCq.fromJson(Map<String, dynamic>.from(row));
  }

  Future<void> batchInsertMcq(List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return;
    await _client.from(kTableQbankMcq).insert(rows);
  }

  Future<void> batchInsertCq(List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return;
    await _client.from(kTableQbankCq).insert(rows);
  }

  Future<List<QbankMcq>> getPracticeQuestions({
    required String chapterId,
    int count = 10,
    String? difficulty,
    String? source,
  }) async {
    final all = await getMcqQuestions(
      chapterId: chapterId,
      difficulty: difficulty,
      source: source,
    );
    if (all.isEmpty) return all;
    final list = [...all]..shuffle(Random());
    final take = count <= 0 ? list.length : count.clamp(1, list.length);
    return list.take(take).toList();
  }

  Future<String> uploadQbankImage({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final clean = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final path = 'qbank/${DateTime.now().millisecondsSinceEpoch}_$clean';
    await _client.storage.from(kStorageBucketQbank).uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );
    return _client.storage.from(kStorageBucketQbank).getPublicUrl(path);
  }
}
