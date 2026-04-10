import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase_client.dart';

class PaymentDueEdgeService {
  PaymentDueEdgeService({SupabaseClient? client}) : _client = client ?? supabaseClient;

  final SupabaseClient _client;

  Future<Map<String, dynamic>?> generateMonthlyDues({
    DateTime? month,
    String? courseId,
    bool force = false,
  }) async {
    try {
      final payload = <String, dynamic>{
        if (month != null)
          'month':
              '${month.year.toString().padLeft(4, '0')}-${month.month.toString().padLeft(2, '0')}-01',
        if (courseId != null && courseId.isNotEmpty) 'course_id': courseId,
        'force': force,
      };
      final res = await _client.functions.invoke(
        'generate-monthly-dues',
        body: payload,
      );
      if (res.data is Map<String, dynamic>) {
        return res.data as Map<String, dynamic>;
      }
      if (res.data is Map) {
        return Map<String, dynamic>.from(res.data as Map);
      }
      return null;
    } catch (e, st) {
      debugPrint('generate-monthly-dues invoke failed: $e\n$st');
      rethrow;
    }
  }
}
