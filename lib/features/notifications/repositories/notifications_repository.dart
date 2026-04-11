import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants.dart';
import '../../../core/supabase_client.dart';

/// In-app notifications ([kTableNotifications]) + unread counts.
class NotificationsRepository {
  NotificationsRepository({SupabaseClient? client})
      : _client = client ?? supabaseClient;

  final SupabaseClient _client;

  Future<List<Map<String, dynamic>>> listForCurrentUser({int limit = 80}) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return [];
    final rows = await _client
        .from(kTableNotifications)
        .select(
          'id,user_id,title,body,type,action_route,is_read,fcm_sent,created_at',
        )
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List<dynamic>)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<int> countUnread() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return 0;
    final rows = await _client
        .from(kTableNotifications)
        .select('id')
        .eq('user_id', uid)
        .eq('is_read', false);
    return (rows as List<dynamic>).length;
  }

  /// Realtime: re-count when any of this user's notification rows change.
  Stream<int> watchUnreadCount() {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return Stream.value(0);
    return _client
        .from(kTableNotifications)
        .stream(primaryKey: const ['id']).eq('user_id', uid).map((rows) {
      var n = 0;
      for (final r in rows) {
        final m = Map<String, dynamic>.from(r);
        if (m['is_read'] != true) n++;
      }
      return n;
    });
  }

  Future<void> markRead(String notificationId) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return;
    await _client.from(kTableNotifications).update(<String, dynamic>{
      'is_read': true,
    }).eq('id', notificationId).eq('user_id', uid);
  }

  Future<void> markAllRead() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return;
    await _client.from(kTableNotifications).update(<String, dynamic>{
      'is_read': true,
    }).eq('user_id', uid).eq('is_read', false);
  }

  /// Admin: one notice row per enrolled student in [courseId].
  Future<int> sendCourseNotice({
    required String courseId,
    required String title,
    required String body,
  }) async {
    final rows = await _client
        .from(kTableEnrollments)
        .select('student_id')
        .eq('course_id', courseId);
    final list = rows as List<dynamic>;
    if (list.isEmpty) return 0;
    final inserts = <Map<String, dynamic>>[];
    for (final raw in list) {
      final m = Map<String, dynamic>.from(raw as Map);
      final sid = m['student_id'] as String?;
      if (sid == null) continue;
      inserts.add(<String, dynamic>{
        'user_id': sid,
        'title': title.trim(),
        'body': body.trim(),
        'type': 'announcement',
        'action_route': '/student/courses/$courseId',
      });
    }
    if (inserts.isEmpty) return 0;
    await _client.from(kTableNotifications).insert(inserts);
    return inserts.length;
  }

  /// Admin: notify all active enrolled students about exam schedule.
  Future<int> sendExamScheduleNotice({
    required String courseId,
    required String examId,
    required String examTitle,
    required String examMode,
    required DateTime startTime,
  }) async {
    final rows = await _client
        .from(kTableEnrollments)
        .select('student_id')
        .eq('course_id', courseId)
        .eq('status', 'active');
    final list = rows as List<dynamic>;
    if (list.isEmpty) return 0;

    final local = startTime.toLocal();
    final date =
        '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
    final time =
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    final modeLabel = examMode == 'offline' ? 'অফলাইন' : 'অনলাইন';

    final inserts = <Map<String, dynamic>>[];
    for (final raw in list) {
      final m = Map<String, dynamic>.from(raw as Map);
      final sid = m['student_id'] as String?;
      if (sid == null) continue;
      inserts.add(<String, dynamic>{
        'user_id': sid,
        'title': 'পরীক্ষার সময়সূচী',
        'body': '$examTitle ($modeLabel) — $date, $time',
        'type': 'exam',
        'action_route': '/student/exams/$examId/take',
      });
    }
    if (inserts.isEmpty) return 0;
    await _client.from(kTableNotifications).insert(inserts);
    return inserts.length;
  }
}
