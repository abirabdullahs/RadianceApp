import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants.dart';
import '../supabase_client.dart';
import '../../shared/models/sms_template_model.dart';

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
    if (to.isEmpty) {
      throw ArgumentError('Invalid phone number');
    }
    final tpl = await _getTemplateByKey('payment_confirmation');
    final text = _renderTemplate(
      (tpl?.isActive ?? false) ? tpl!.body : _defaultPaymentTemplate,
      <String, String>{
        'name': studentName?.trim().isNotEmpty == true ? studentName!.trim() : 'শিক্ষার্থী',
        'month': '',
        'type': courseName,
        'amount': amountLabel.replaceAll('৳', ''),
        'voucher_no': voucherNo,
      },
    );

    await _client.from(kTableSmsLogs).insert(<String, dynamic>{
      'to_phone': to,
      'message': text,
      'gateway': 'ssl_wireless',
      'status': 'pending',
    });
  }

  Future<void> notifyDueReminder({
    required String phone,
    required String studentName,
    required String monthLabel,
    required String feeTypeLabel,
    required String amountLabel,
  }) async {
    final to = _normalizeBdPhone(phone);
    if (to.isEmpty) {
      throw ArgumentError('Invalid phone number');
    }
    final tpl = await _getTemplateByKey('due_reminder');
    final text = _renderTemplate(
      (tpl?.isActive ?? false) ? tpl!.body : _defaultDueTemplate,
      <String, String>{
        'name': studentName,
        'month': monthLabel,
        'type': feeTypeLabel,
        'amount': amountLabel.replaceAll('৳', ''),
        'voucher_no': '',
      },
    );
    await _client.from(kTableSmsLogs).insert(<String, dynamic>{
      'to_phone': to,
      'message': text,
      'gateway': 'ssl_wireless',
      'status': 'pending',
    });
  }

  Future<List<SmsTemplateModel>> listTemplates() async {
    final rows = await _client
        .from(kTableSmsTemplates)
        .select()
        .order('template_key', ascending: true);
    return (rows as List<dynamic>)
        .map((e) => SmsTemplateModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<SmsTemplateModel> upsertTemplate({
    required String templateKey,
    required String name,
    required String body,
    required bool isActive,
  }) async {
    final row = await _client
        .from(kTableSmsTemplates)
        .upsert(
          <String, dynamic>{
            'template_key': templateKey,
            'name': name,
            'body': body,
            'is_active': isActive,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
            'updated_by': _client.auth.currentUser?.id,
          },
          onConflict: 'template_key',
        )
        .select()
        .single();
    return SmsTemplateModel.fromJson(Map<String, dynamic>.from(row));
  }

  Future<SmsTemplateModel?> _getTemplateByKey(String key) async {
    final row = await _client
        .from(kTableSmsTemplates)
        .select()
        .eq('template_key', key)
        .maybeSingle();
    if (row == null) return null;
    return SmsTemplateModel.fromJson(Map<String, dynamic>.from(row));
  }

  String _renderTemplate(String template, Map<String, String> vars) {
    var out = template;
    for (final e in vars.entries) {
      out = out.replaceAll('{${e.key}}', e.value);
    }
    return out;
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
    return '';
  }
}

const String _defaultPaymentTemplate =
    'প্রিয় {name}, {type} এর ৳{amount} পরিশোধিত হয়েছে। ভাউচার: {voucher_no}। ধন্যবাদ — Radiance';
const String _defaultDueTemplate =
    'প্রিয় {name}, {month} মাসের {type} ৳{amount} এখনও বকেয়া আছে। দ্রুত পরিশোধ করুন। — Radiance';
