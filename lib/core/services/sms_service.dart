import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants.dart';
import '../supabase_client.dart';

/// Queues transactional SMS rows in `sms_logs` for gateway workers (e.g. SSL Wireless).
class SmsService {
  SmsService({SupabaseClient? client}) : _client = client ?? supabaseClient;

  final SupabaseClient _client;

  /// Records a payment confirmation SMS as `pending` for the given [phone] (local BD format).
  Future<void> notifyPaymentRecorded({
    required String phone,
    required String voucherNo,
    required String amountLabel,
    required String courseName,
    String? studentName,
  }) async {
    final to = _normalizeBdPhone(phone);
    final name = studentName?.trim();
    final body = StringBuffer('রেডিয়ান্স কোচিং সেন্টার। ');
    if (name != null && name.isNotEmpty) {
      body.write('প্রিয় $name, ');
    }
    body.write(
      'আপনার পেমেন্ট গ্রহণ করা হয়েছে। ভাউচার: $voucherNo। '
      'কোর্স: $courseName। পরিমাণ: $amountLabel। ধন্যবাদ।',
    );

    await _client.from(kTableSmsLogs).insert(<String, dynamic>{
      'to_phone': to,
      'message': body.toString(),
      'gateway': 'ssl_wireless',
      'status': 'pending',
    });
  }

  /// Keeps DB-friendly length; strips spaces/dashes.
  String _normalizeBdPhone(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 11 && digits.startsWith('01')) {
      return digits.substring(0, 11);
    }
    if (digits.length >= 10) {
      return digits.substring(digits.length - 11).padLeft(11, '0');
    }
    return raw.length > 15 ? raw.substring(0, 15) : raw;
  }
}
