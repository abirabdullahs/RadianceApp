import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants.dart';
import '../../../../core/supabase_client.dart';
import '../../../../shared/models/enrollment_model.dart';

/// Course-linked batch groups for chat.
class CommunityRepository {
  CommunityRepository({SupabaseClient? client}) : _client = client ?? supabaseClient;

  final SupabaseClient _client;

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
