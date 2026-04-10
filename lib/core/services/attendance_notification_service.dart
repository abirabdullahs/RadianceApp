import 'package:intl/intl.dart';

import '../constants.dart';
import '../supabase_client.dart';
import '../../features/admin/attendance/repositories/attendance_repository.dart';
import 'notification_edge_service.dart';
import 'sms_service.dart';

class AttendanceNotificationService {
  AttendanceNotificationService({
    AttendanceRepository? attendanceRepository,
    NotificationEdgeService? notificationEdgeService,
    SmsService? smsService,
  })  : _attendanceRepository = attendanceRepository ?? AttendanceRepository(),
        _notificationEdgeService = notificationEdgeService ?? NotificationEdgeService(),
        _smsService = smsService ?? SmsService();

  final AttendanceRepository _attendanceRepository;
  final NotificationEdgeService _notificationEdgeService;
  final SmsService _smsService;

  Future<int> sendWeeklyPushForCourse({required String courseId}) async {
    final rows = await _attendanceRepository.getWeeklyRecipients(courseId: courseId);
    if (rows.isEmpty) return 0;
    final userIds = rows.map((e) => e.studentId).toList();
    for (final r in rows) {
      final pct = r.percentage.toStringAsFixed(0);
      await supabaseClient.from(kTableNotifications).insert({
        'user_id': r.studentId,
        'title': 'সাপ্তাহিক উপস্থিতি আপডেট',
        'body': 'এই সপ্তাহে তোমার উপস্থিতি $pct%। চালিয়ে যাও! 💪',
        'type': 'attendance',
        'action_route': '/student/attendance',
        'fcm_sent': false,
      });
    }
    await _notificationEdgeService.invokeSendNotification(
      userIds: userIds,
      title: 'সাপ্তাহিক উপস্থিতি আপডেট',
      body: 'এই সপ্তাহের উপস্থিতির বিস্তারিত দেখতে ট্যাপ করো।',
      actionRoute: '/student/attendance',
      type: 'attendance',
    );
    return userIds.length;
  }

  Future<int> sendWarningPushAndGuardianSms({
    required String courseId,
    required DateTime month,
    required int thresholdPct,
  }) async {
    final rows = await _attendanceRepository.getWarningRecipientsForMonth(
      courseId: courseId,
      month: month,
      thresholdPct: thresholdPct,
    );
    if (rows.isEmpty) return 0;
    final userIds = <String>[];
    final monthLabel = DateFormat('MMMM yyyy').format(month);
    for (final r in rows) {
      userIds.add(r.studentId);
      final pct = r.percentage.toStringAsFixed(0);
      await supabaseClient.from(kTableNotifications).insert({
        'user_id': r.studentId,
        'title': 'উপস্থিতি সতর্কতা',
        'body': 'সতর্কতা! তোমার উপস্থিতি $pct% — $thresholdPct%-এর নিচে।',
        'type': 'attendance',
        'action_route': '/student/attendance',
        'fcm_sent': false,
      });
      final guardianPhone = r.guardianPhone?.trim();
      if (guardianPhone != null && guardianPhone.isNotEmpty) {
        await _smsService.queueSms(
          phone: guardianPhone,
          templateKey: 'attendance_warning_guardian',
          fallbackTemplate:
              'প্রিয় অভিভাবক, {name} এর উপস্থিতি {month} মাসে {percentage}% (সতর্কতা সীমা {threshold}%)। — Radiance Coaching Center',
          vars: {
            'name': r.studentNameBn,
            'month': monthLabel,
            'percentage': pct,
            'threshold': '$thresholdPct',
          },
        );
      }
    }
    await _notificationEdgeService.invokeSendNotification(
      userIds: userIds,
      title: 'উপস্থিতি সতর্কতা',
      body: 'তোমার উপস্থিতি সীমার নিচে নেমে গেছে। বিস্তারিত দেখতে ট্যাপ করো।',
      actionRoute: '/student/attendance',
      type: 'attendance',
    );
    return rows.length;
  }

  Future<Map<String, dynamic>?> invokeScheduledBatch({
    String job = 'both',
    DateTime? month,
    String? courseId,
  }) async {
    final res = await supabaseClient.functions.invoke(
      'attendance-notification-batch',
      body: <String, dynamic>{
        'job': job,
        if (month != null)
          'month':
              '${month.year.toString().padLeft(4, '0')}-${month.month.toString().padLeft(2, '0')}-01',
        if (courseId != null) 'course_id': courseId,
      },
    );
    final d = res.data;
    if (d is Map<String, dynamic>) return d;
    if (d is Map) return Map<String, dynamic>.from(d);
    return null;
  }
}
