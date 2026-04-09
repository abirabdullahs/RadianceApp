import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants.dart';
import '../../../core/supabase_client.dart';

/// Public marketing content (`home_content`).
class HomeContentRepository {
  HomeContentRepository({SupabaseClient? client}) : _client = client ?? supabaseClient;

  final SupabaseClient _client;

  Future<List<Map<String, dynamic>>> listActivePublic() async {
    final rows = await _client
        .from(kTableHomeContent)
        .select()
        .eq('is_active', true)
        .order('display_order', ascending: true);
    return (rows as List<dynamic>)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<List<Map<String, dynamic>>> listAllForAdmin() async {
    final rows = await _client
        .from(kTableHomeContent)
        .select()
        .order('display_order', ascending: true);
    return (rows as List<dynamic>)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<void> insertBanner({
    required String title,
    String? imageUrl,
    int order = 0,
  }) async {
    final uid = _client.auth.currentUser?.id;
    await _client.from(kTableHomeContent).insert(<String, dynamic>{
      'type': 'banner',
      'title': title,
      'image_url': imageUrl,
      'display_order': order,
      'is_active': true,
      'created_by': uid,
    });
  }

  Future<void> setActive(String id, bool active) async {
    await _client.from(kTableHomeContent).update(<String, dynamic>{
      'is_active': active,
    }).eq('id', id);
  }

  Future<void> deleteRow(String id) async {
    await _client.from(kTableHomeContent).delete().eq('id', id);
  }
}
