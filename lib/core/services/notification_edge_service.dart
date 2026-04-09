import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase_client.dart';

/// Invokes the Supabase Edge Function `send-notification` to deliver FCM for queued rows.
///
/// Deploy: `supabase functions deploy send-notification`
/// Secret: `FCM_SERVICE_ACCOUNT_JSON` = Firebase service account JSON (same GCP project as the app).
class NotificationEdgeService {
  NotificationEdgeService({SupabaseClient? client})
      : _client = client ?? supabaseClient;

  final SupabaseClient _client;

  /// Optional: pass [userIds], [title], [body] to trigger a send from the client (admin tools).
  Future<void> invokeSendNotification({
    List<String>? userIds,
    String? title,
    String? body,
    String? actionRoute,
    String? type,
  }) async {
    try {
      await _client.functions.invoke(
        'send-notification',
        body: <String, dynamic>{
          if (userIds != null) 'user_ids': userIds,
          if (title != null) 'title': title,
          if (body != null) 'body': body,
          if (actionRoute != null) 'action_route': actionRoute,
          if (type != null) 'type': type,
        },
      );
    } catch (e, st) {
      debugPrint('send-notification edge invoke failed: $e\n$st');
    }
  }
}
