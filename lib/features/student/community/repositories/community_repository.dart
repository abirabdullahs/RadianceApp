import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants.dart';
import '../../../../core/supabase_client.dart';
import '../../../../shared/models/enrollment_model.dart';

/// Course-linked batch groups for chat.
class CommunityRepository {
  CommunityRepository({SupabaseClient? client}) : _client = client ?? supabaseClient;

  final SupabaseClient _client;
  static const String _seenKey = 'community_last_seen_by_group_v1';

  Future<List<Map<String, dynamic>>> listGroupsForCurrentStudent() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return [];

    final en = await _client
        .from(kTableEnrollments)
        .select('course_id')
        .eq('student_id', uid)
        .eq('status', EnrollmentStatus.active.toJson());

    final courseIds = (en as List<dynamic>)
        .map((e) => Map<String, dynamic>.from(e as Map)['course_id'] as String)
        .toSet()
        .toList();
    if (courseIds.isEmpty) return [];

    final rows = await _client
        .from(kTableCommunityGroups)
        .select()
        .inFilter('course_id', courseIds)
        .order('name', ascending: true);
    return (rows as List<dynamic>)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<List<Map<String, dynamic>>> listGroupsForCurrentStudentWithUnread() async {
    final uid = _client.auth.currentUser?.id;
    final groups = await listGroupsForCurrentStudent();
    if (uid == null || groups.isEmpty) return groups;

    final groupIds = groups
        .map((g) => g['id'] as String?)
        .whereType<String>()
        .toList();
    final latestByGroup = await _latestMessageMetaByGroup(groupIds);
    final seenMap = await _loadSeenMap();

    return groups.map((g) {
      final id = g['id'] as String?;
      if (id == null) return g;
      final latest = latestByGroup[id];
      final latestAt = latest?.createdAt;
      final latestSender = latest?.senderId;
      final seenAt = seenMap[id];
      final hasUnseen = latestAt != null &&
          latestSender != null &&
          latestSender != uid &&
          (seenAt == null || latestAt.isAfter(seenAt));
      return <String, dynamic>{
        ...g,
        'has_unseen': hasUnseen,
        'last_message_at': latestAt?.toIso8601String(),
      };
    }).toList();
  }

  Future<int> countUnreadGroupsForCurrentStudent() async {
    final groups = await listGroupsForCurrentStudentWithUnread();
    var count = 0;
    for (final g in groups) {
      if (g['has_unseen'] == true) count++;
    }
    return count;
  }

  Stream<int> watchUnreadGroupsCount({
    Duration interval = const Duration(seconds: 10),
  }) async* {
    yield await countUnreadGroupsForCurrentStudent();
    yield* Stream<int>.periodic(interval).asyncMap(
      (_) => countUnreadGroupsForCurrentStudent(),
    );
  }

  Future<void> markGroupSeen(String groupId, {DateTime? seenAt}) async {
    final prefs = await SharedPreferences.getInstance();
    final map = await _loadSeenMap();
    map[groupId] = (seenAt ?? DateTime.now()).toUtc();
    await prefs.setString(_seenKey, _encodeSeenMap(map));
  }

  Future<Map<String, DateTime>> _loadSeenMap() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_seenKey);
    if (raw == null || raw.isEmpty) return <String, DateTime>{};
    final map = <String, DateTime>{};
    for (final entry in raw.split('|')) {
      if (entry.isEmpty) continue;
      final idx = entry.indexOf('=');
      if (idx <= 0 || idx >= entry.length - 1) continue;
      final key = entry.substring(0, idx);
      final value = entry.substring(idx + 1);
      final parsed = DateTime.tryParse(value);
      if (parsed != null) {
        map[key] = parsed.toUtc();
      }
    }
    return map;
  }

  String _encodeSeenMap(Map<String, DateTime> map) {
    final parts = <String>[];
    map.forEach((k, v) {
      parts.add('$k=${v.toUtc().toIso8601String()}');
    });
    return parts.join('|');
  }

  Future<Map<String, _LatestMessageMeta>> _latestMessageMetaByGroup(
    List<String> groupIds,
  ) async {
    if (groupIds.isEmpty) return <String, _LatestMessageMeta>{};
    final rows = await _client
        .from(kTableCommunityMessages)
        .select('group_id, sender_id, created_at, is_deleted')
        .inFilter('group_id', groupIds)
        .order('created_at', ascending: false);
    final out = <String, _LatestMessageMeta>{};
    for (final raw in rows as List<dynamic>) {
      final m = Map<String, dynamic>.from(raw as Map);
      if (m['is_deleted'] == true) continue;
      final groupId = m['group_id'] as String?;
      if (groupId == null || out.containsKey(groupId)) continue;
      final senderId = m['sender_id'] as String?;
      final createdAt = DateTime.tryParse(m['created_at']?.toString() ?? '');
      if (createdAt == null) continue;
      out[groupId] = _LatestMessageMeta(
        senderId: senderId,
        createdAt: createdAt.toUtc(),
      );
      if (out.length == groupIds.length) break;
    }
    return out;
  }

  /// All course-linked groups (admin chat list). Ordered by course name.
  Future<List<Map<String, dynamic>>> listCourseGroupsForAdmin() async {
    final rows = await _client
        .from(kTableCommunityGroups)
        .select('id, name, description, course_id, courses(name)')
        .not('course_id', 'is', null)
        .order('name');

    final list = (rows as List<dynamic>)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    list.sort((a, b) {
      final an = _courseNameFromRow(a);
      final bn = _courseNameFromRow(b);
      return an.compareTo(bn);
    });
    return list;
  }

  String _courseNameFromRow(Map<String, dynamic> row) {
    final c = row['courses'];
    if (c is Map) {
      return (c['name'] as String?)?.trim() ?? '';
    }
    return '';
  }
}

class _LatestMessageMeta {
  const _LatestMessageMeta({
    required this.senderId,
    required this.createdAt,
  });

  final String? senderId;
  final DateTime createdAt;
}
