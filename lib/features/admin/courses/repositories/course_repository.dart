import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants.dart';
import '../../../../core/supabase_client.dart';
import '../../../../shared/models/chapter_model.dart';
import '../../../../shared/models/chapter_suggestion_model.dart';
import '../../../../shared/models/course_model.dart';
import '../../../../shared/models/note_model.dart';
import '../../../../shared/models/subject_model.dart';

/// Course / subject / chapter data access (Supabase + Storage `thumbnails` bucket).
class CourseRepository {
  CourseRepository({SupabaseClient? client}) : _client = client ?? supabaseClient;

  final SupabaseClient _client;
  static const _uuid = Uuid();

  /// All courses, newest first.
  Future<List<CourseModel>> getCourses() async {
    final rows = await _client
        .from(kTableCourses)
        .select()
        .order('created_at', ascending: false);
    final list = rows as List<dynamic>;
    return list
        .map((e) => CourseModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<CourseModel> getCourseById(String id) async {
    final row = await _client
        .from(kTableCourses)
        .select()
        .eq('id', id)
        .maybeSingle();
    if (row == null) {
      throw StateError('Course not found: $id');
    }
    return CourseModel.fromJson(Map<String, dynamic>.from(row));
  }

  /// Inserts a course. [course.id] is ignored; a new UUID is generated.
  /// Uploads [thumbnailFile] to bucket [kStorageBucketThumbnails] under `courses/{id}/`.
  Future<CourseModel> addCourse(CourseModel course, File? thumbnailFile) async {
    final id = _uuid.v4();
    String? thumbnailUrl;
    if (thumbnailFile != null) {
      thumbnailUrl = await _uploadThumbnail(thumbnailFile, 'courses/$id');
    }

    final now = DateTime.now().toUtc().toIso8601String();
    final inserted = await _client.from(kTableCourses).insert({
      'id': id,
      'name': course.name,
      'description': course.description,
      'thumbnail_url': thumbnailUrl,
      'monthly_fee': course.monthlyFee,
      'is_active': course.isActive,
      'created_by': course.createdBy,
      'created_at': now,
      'updated_at': now,
    }).select().single();

    return CourseModel.fromJson(Map<String, dynamic>.from(inserted));
  }

  Future<CourseModel> updateCourse(CourseModel course, File? newThumbnail) async {
    String? thumbnailUrl = course.thumbnailUrl;
    if (newThumbnail != null) {
      thumbnailUrl = await _uploadThumbnail(newThumbnail, 'courses/${course.id}');
    }

    final updated = await _client
        .from(kTableCourses)
        .update({
          'name': course.name,
          'description': course.description,
          'thumbnail_url': thumbnailUrl,
          'monthly_fee': course.monthlyFee,
          'is_active': course.isActive,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', course.id)
        .select()
        .single();

    return CourseModel.fromJson(Map<String, dynamic>.from(updated));
  }

  Future<void> deleteCourse(String id) async {
    await _client.from(kTableCourses).delete().eq('id', id);
  }

  /// Active enrollments per course id (only rows in [courseIds]).
  Future<Map<String, int>> getEnrollmentCountsForCourses(
    List<String> courseIds,
  ) async {
    if (courseIds.isEmpty) return {};
    final rows = await _client
        .from(kTableEnrollments)
        .select('course_id')
        .eq('status', 'active')
        .inFilter('course_id', courseIds);
    final map = <String, int>{};
    for (final e in rows as List<dynamic>) {
      final m = Map<String, dynamic>.from(e as Map);
      final cid = m['course_id'] as String;
      map[cid] = (map[cid] ?? 0) + 1;
    }
    return map;
  }

  Future<List<SubjectModel>> getSubjects(String courseId) async {
    final rows = await _client
        .from(kTableSubjects)
        .select()
        .eq('course_id', courseId)
        .order('display_order', ascending: true);
    final list = rows as List<dynamic>;
    return list
        .map((e) => SubjectModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// [subject.id] is ignored; a new UUID is generated.
  Future<SubjectModel> addSubject(SubjectModel subject) async {
    final id = _uuid.v4();
    final now = DateTime.now().toUtc().toIso8601String();
    final inserted = await _client.from(kTableSubjects).insert({
      'id': id,
      'course_id': subject.courseId,
      'name': subject.name,
      'description': subject.description,
      'display_order': subject.displayOrder,
      'is_active': subject.isActive,
      'created_at': now,
    }).select().single();

    return SubjectModel.fromJson(Map<String, dynamic>.from(inserted));
  }

  /// Sets `display_order` to each item's index in [subjects] (0-based).
  Future<void> updateSubjectOrder(List<SubjectModel> subjects) async {
    for (var i = 0; i < subjects.length; i++) {
      await _client.from(kTableSubjects).update({
        'display_order': i,
      }).eq('id', subjects[i].id);
    }
  }

  Future<void> deleteSubject(String id) async {
    await _client.from(kTableSubjects).delete().eq('id', id);
  }

  Future<List<ChapterModel>> getChapters(String subjectId) async {
    final rows = await _client
        .from(kTableChapters)
        .select()
        .eq('subject_id', subjectId)
        .order('display_order', ascending: true);
    final list = rows as List<dynamic>;
    return list
        .map((e) => ChapterModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// [chapter.id] is ignored; a new UUID is generated.
  Future<ChapterModel> addChapter(ChapterModel chapter) async {
    final id = _uuid.v4();
    final now = DateTime.now().toUtc().toIso8601String();
    final inserted = await _client.from(kTableChapters).insert({
      'id': id,
      'subject_id': chapter.subjectId,
      'name': chapter.name,
      'description': chapter.description,
      'display_order': chapter.displayOrder,
      'is_active': chapter.isActive,
      'created_at': now,
    }).select().single();

    return ChapterModel.fromJson(Map<String, dynamic>.from(inserted));
  }

  Future<void> deleteChapter(String id) async {
    await _client.from(kTableChapters).delete().eq('id', id);
  }

  /// Notes for a chapter (admin: includes unpublished).
  Future<List<NoteModel>> getNotesForChapter(String chapterId) async {
    final rows = await _client
        .from(kTableNotes)
        .select()
        .eq('chapter_id', chapterId)
        .order('display_order', ascending: true);
    final list = rows as List<dynamic>;
    return list
        .map((e) => NoteModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Next [display_order] for a new note in this chapter.
  Future<int> nextNoteDisplayOrder(String chapterId) async {
    final rows = await _client
        .from(kTableNotes)
        .select('display_order')
        .eq('chapter_id', chapterId)
        .order('display_order', ascending: false)
        .limit(1);
    final list = rows as List<dynamic>;
    if (list.isEmpty) return 0;
    final v = Map<String, dynamic>.from(list.first as Map)['display_order'];
    if (v is num) return v.toInt() + 1;
    return 0;
  }

  /// [type] e.g. `lecture` (markdown + optional video [fileUrl]).
  Future<NoteModel> addNote(NoteModel note) async {
    final id = _uuid.v4();
    final now = DateTime.now().toUtc().toIso8601String();
    final inserted = await _client.from(kTableNotes).insert({
      'id': id,
      'chapter_id': note.chapterId,
      'title': note.title,
      'description': note.description,
      'type': note.type,
      'file_url': note.fileUrl,
      'content': note.content,
      'is_published': note.isPublished ?? true,
      'display_order': note.displayOrder ?? 0,
      'created_by': _client.auth.currentUser?.id,
      'created_at': now,
      'updated_at': now,
    }).select().single();

    return NoteModel.fromJson(Map<String, dynamic>.from(inserted));
  }

  Future<void> updateNote(NoteModel note) async {
    await _client.from(kTableNotes).update({
      'title': note.title,
      'description': note.description,
      'type': note.type,
      'file_url': note.fileUrl,
      'content': note.content,
      'is_published': note.isPublished,
      'display_order': note.displayOrder,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', note.id);
  }

  Future<void> deleteNote(String id) async {
    await _client.from(kTableNotes).delete().eq('id', id);
  }

  /// Suggestions linked to a chapter ([chapter_id] set in DB).
  Future<List<ChapterSuggestionModel>> getSuggestionsForChapter(String chapterId) async {
    final rows = await _client
        .from(kTableSuggestions)
        .select()
        .eq('chapter_id', chapterId)
        .order('created_at', ascending: false);
    final list = rows as List<dynamic>;
    return list
        .map(
          (e) => ChapterSuggestionModel.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  Future<ChapterSuggestionModel> addChapterSuggestion({
    required String courseId,
    required String chapterId,
    required String title,
    String? content,
    String? pdfUrl,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now().toUtc().toIso8601String();
    final inserted = await _client.from(kTableSuggestions).insert({
      'id': id,
      'title': title,
      'content': content,
      'type': 'guide',
      'course_id': courseId,
      'chapter_id': chapterId,
      'pdf_url': pdfUrl,
      'is_published': true,
      'created_by': _client.auth.currentUser?.id,
      'created_at': now,
    }).select().single();

    return ChapterSuggestionModel.fromJson(Map<String, dynamic>.from(inserted));
  }

  Future<void> updateChapterSuggestion(ChapterSuggestionModel s) async {
    await _client.from(kTableSuggestions).update({
      'title': s.title,
      'content': s.content,
      'pdf_url': s.pdfUrl,
      'is_published': s.isPublished ?? true,
    }).eq('id', s.id);
  }

  Future<void> deleteChapterSuggestion(String id) async {
    await _client.from(kTableSuggestions).delete().eq('id', id);
  }

  Future<String> _uploadThumbnail(File file, String storagePrefix) async {
    final ext = _fileExtension(file.path);
    final path = '$storagePrefix/thumbnail.$ext';
    await _client.storage.from(kStorageBucketThumbnails).upload(
          path,
          file,
          fileOptions: FileOptions(
            upsert: true,
            contentType: _mimeForExtension(ext),
          ),
        );
    return _client.storage.from(kStorageBucketThumbnails).getPublicUrl(path);
  }

  static String _fileExtension(String path) {
    final i = path.lastIndexOf('.');
    if (i == -1 || i == path.length - 1) return 'jpg';
    return path.substring(i + 1).toLowerCase();
  }

  static String _mimeForExtension(String ext) {
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      case 'jpg':
      case 'jpeg':
      default:
        return 'image/jpeg';
    }
  }
}
