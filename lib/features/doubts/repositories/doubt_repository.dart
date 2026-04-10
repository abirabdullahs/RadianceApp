import 'dart:io';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants.dart';
import '../../../core/storage_upload_hint.dart';
import '../../../core/supabase_client.dart';
import '../../../shared/models/doubt_thread_model.dart';
import '../../../shared/models/user_model.dart';

/// Doubt threads + messages (1:1 chat per doubt).
class DoubtRepository {
  DoubtRepository({SupabaseClient? client}) : _client = client ?? supabaseClient;

  final SupabaseClient _client;
  static const _uuid = Uuid();

  Future<int> countSolvedForStudent(String studentId) async {
    final row = await _client
        .from(kTableStudentDoubtStats)
        .select('total_solved')
        .eq('student_id', studentId)
        .maybeSingle();
    if (row == null) return 0;
    return (row['total_solved'] as num?)?.toInt() ?? 0;
  }

  Future<List<DoubtThreadModel>> listMyDoubts() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return [];
    final rows = await _client
        .from(kTableDoubts)
        .select()
        .eq('student_id', uid)
        .order('created_at', ascending: false);
    return (rows as List<dynamic>)
        .map((e) => DoubtThreadModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Admin + teacher: all threads, newest first.
  Future<List<DoubtThreadModel>> listAllForStaff() async {
    final rows =
        await _client.from(kTableDoubts).select().order('created_at', ascending: false);
    return (rows as List<dynamic>)
        .map((e) => DoubtThreadModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<DoubtThreadModel>> listForStaff({
    String? status,
    String? courseId,
  }) async {
    var q = _client.from(kTableDoubts).select();
    if (status != null && status.isNotEmpty && status != 'all') {
      q = q.eq('status', status);
    }
    if (courseId != null && courseId.isNotEmpty) {
      q = q.eq('course_id', courseId);
    }
    final rows = await q.order('created_at', ascending: false);
    return (rows as List<dynamic>)
        .map((e) => DoubtThreadModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<Map<String, UserModel>> loadUsersByIds(Iterable<String> ids) async {
    final list = ids.toSet().toList();
    if (list.isEmpty) return {};
    final rows = await _client.from(kTableUsers).select().inFilter('id', list);
    final out = <String, UserModel>{};
    for (final raw in rows as List<dynamic>) {
      final u = UserModel.fromJson(Map<String, dynamic>.from(raw as Map));
      out[u.id] = u;
    }
    return out;
  }

  Future<DoubtThreadModel?> getThread(String id) async {
    final row = await _client.from(kTableDoubts).select().eq('id', id).maybeSingle();
    if (row == null) return null;
    return DoubtThreadModel.fromJson(Map<String, dynamic>.from(row));
  }

  Future<DoubtThreadModel> createThread({
    String? courseId,
    String? subject,
    String? chapter,
    String? title,
    required String problemDescription,
    File? problemImage,
  }) async {
    final uid = _client.auth.currentUser!.id;
    String? imageUrl;
    if (problemImage != null) {
      try {
        final ext = problemImage.path.split('.').last.toLowerCase();
        final safe = ext.length > 5 ? 'jpg' : ext;
        final path = 'doubts/$uid/${_uuid.v4()}.$safe';
        await supabaseStorage.from(kStorageBucketCommunity).upload(
              path,
              problemImage,
              fileOptions: FileOptions(
                upsert: true,
                contentType: safe == 'png'
                    ? 'image/png'
                    : (safe == 'webp' ? 'image/webp' : 'image/jpeg'),
              ),
            );
        imageUrl = supabaseStorage.from(kStorageBucketCommunity).getPublicUrl(path);
      } catch (e) {
        throw StateError(storageUploadHint(e));
      }
    }

    final row = await _client.from(kTableDoubts).insert(<String, dynamic>{
      'student_id': uid,
      'course_id': courseId,
      'subject': subject?.trim().isEmpty == true ? null : subject?.trim(),
      'chapter': chapter?.trim().isEmpty == true ? null : chapter?.trim(),
      'title': (title?.trim().isNotEmpty == true)
          ? title!.trim()
          : _autoTitle(problemDescription),
      'description': problemDescription.trim(),
      'image_url': imageUrl,
      'resolution_type': 'chat',
      'status': DoubtStatus.open.toJson(),
    }).select().single();
    return DoubtThreadModel.fromJson(Map<String, dynamic>.from(row));
  }

  String _autoTitle(String description) {
    final text = description.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (text.length <= 120) return text;
    return '${text.substring(0, 120)}...';
  }

  Future<void> markSolved(String doubtId) async {
    await _client.rpc('mark_doubt_solved_and_delete', params: {'p_doubt_id': doubtId});
  }

  Future<List<Map<String, dynamic>>> listMessages(String doubtId) async {
    final rows = await _client
        .from(kTableDoubtMessages)
        .select()
        .eq('doubt_id', doubtId)
        .order('created_at', ascending: true);
    return (rows as List<dynamic>)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  /// Realtime stream (primary key).
  Stream<List<Map<String, dynamic>>> streamMessages(String doubtId) {
    return _client
        .from(kTableDoubtMessages)
        .stream(primaryKey: const ['id'])
        .eq('doubt_id', doubtId)
        .order('created_at');
  }

  Future<void> sendTextMessage({
    required String doubtId,
    required String text,
  }) async {
    final uid = _client.auth.currentUser!.id;
    await _client.from(kTableDoubtMessages).insert({
      'doubt_id': doubtId,
      'sender_id': uid,
      'message_type': 'text',
      'content': text.trim(),
      'body': text.trim(),
    });
    await _setInProgressIfOpen(doubtId);
    await _touchThread(doubtId);
  }

  Future<void> _setInProgressIfOpen(String doubtId) async {
    await _client
        .from(kTableDoubts)
        .update({'status': DoubtStatus.inProgress.toJson()})
        .eq('id', doubtId)
        .eq('status', DoubtStatus.open.toJson());
  }

  Future<void> _touchThread(String doubtId) async {
    await _client.from(kTableDoubts).update({
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', doubtId);
  }

  Future<void> uploadAndSendFile({
    required String doubtId,
    required Uint8List bytes,
    required String extension,
    required String messageType,
    String? caption,
  }) async {
    final uid = _client.auth.currentUser!.id;
    final path = 'doubts/$doubtId/${_uuid.v4()}.$extension';
    try {
      await supabaseStorage.from(kStorageBucketCommunity).uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              upsert: true,
              contentType: mimeForStorageExtension(extension),
            ),
          );
    } catch (e) {
      throw StateError(storageUploadHint(e));
    }
    final url = supabaseStorage.from(kStorageBucketCommunity).getPublicUrl(path);
    await _client.from(kTableDoubtMessages).insert({
      'doubt_id': doubtId,
      'sender_id': uid,
      'message_type': messageType,
      'content': caption ?? '',
      'body': caption,
      'file_url': url,
      'image_url': messageType == 'image' ? url : null,
    });
    await _setInProgressIfOpen(doubtId);
    await _touchThread(doubtId);
  }

  /// RPC: delete all messages in thread (user must confirm in UI first).
  Future<void> purgeMessages(String doubtId) async {
    await _client.rpc('purge_doubt_messages', params: {'p_doubt_id': doubtId});
  }

  Future<void> scheduleMeeting({
    required String doubtId,
    required DateTime meetingTime,
    required String meetingLink,
    String? meetingNote,
  }) async {
    await _client.rpc(
      'schedule_doubt_meeting',
      params: {
        'p_doubt_id': doubtId,
        'p_meeting_time': meetingTime.toUtc().toIso8601String(),
        'p_meeting_link': meetingLink.trim(),
        'p_meeting_note': meetingNote?.trim().isEmpty == true ? null : meetingNote?.trim(),
      },
    );
  }

  Future<Map<String, int>> getMyStats(String studentId) async {
    final row = await _client
        .from(kTableStudentDoubtStats)
        .select('total_submitted,total_solved')
        .eq('student_id', studentId)
        .maybeSingle();
    if (row == null) return {'totalSubmitted': 0, 'totalSolved': 0};
    return {
      'totalSubmitted': (row['total_submitted'] as num?)?.toInt() ?? 0,
      'totalSolved': (row['total_solved'] as num?)?.toInt() ?? 0,
    };
  }

  Future<Map<String, int>> getInboxCounts() async {
    final rows = await _client.from(kTableDoubts).select('status');
    var open = 0;
    var inProgress = 0;
    var meeting = 0;
    for (final raw in rows as List<dynamic>) {
      final s = (raw as Map)['status'] as String?;
      if (s == 'open') open++;
      if (s == 'in_progress') inProgress++;
      if (s == 'meeting_scheduled') meeting++;
    }
    return {
      'open': open,
      'inProgress': inProgress,
      'meetingScheduled': meeting,
    };
  }
}
