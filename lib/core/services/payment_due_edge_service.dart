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
      // Direct Postgres RPC (same logic as Edge function) avoids Edge 500s from
      // env/body issues; RLS still applies; function enforces admin-only.
      final params = <String, dynamic>{
        'p_force': force,
      };
      if (month != null) {
        params['p_month'] =
            '${month.year.toString().padLeft(4, '0')}-${month.month.toString().padLeft(2, '0')}-01';
      }
      if (courseId != null && courseId.isNotEmpty) {
        params['p_course_id'] = courseId;
      }
      final data = await _client.rpc<dynamic>(
        'generate_monthly_dues',
        params: params,
      );
      if (data == null) {
        return <String, dynamic>{
          'success': true,
          'result': <String, dynamic>{},
        };
      }
      if (data is Map<String, dynamic>) {
        return <String, dynamic>{
          'success': true,
          'result': data,
        };
      }
      if (data is Map) {
        return <String, dynamic>{
          'success': true,
          'result': Map<String, dynamic>.from(data),
        };
      }
      return <String, dynamic>{
        'success': true,
        'result': <String, dynamic>{'raw': data},
      };
    } catch (e, st) {
      debugPrint('generate_monthly_dues rpc failed: $e\n$st');
      rethrow;
    }
  }
}
