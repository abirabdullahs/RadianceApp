import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants.dart';
import '../../../../core/supabase_client.dart';
import '../../../../shared/models/overdue_student_info.dart';
import '../../../../shared/models/payment_due_model.dart';
import '../../../../shared/models/payment_model.dart';
import '../../../../shared/models/user_model.dart';

/// Payments, dues, revenue aggregates, overdue lists (Supabase).
class PaymentRepository {
  PaymentRepository({SupabaseClient? client}) : _client = client ?? supabaseClient;

  final SupabaseClient _client;
  static const _uuid = Uuid();

  /// Lists payments with optional filters. [month] is normalized to the first day of that month.
  Future<List<PaymentModel>> getPayments({
    String? studentId,
    String? courseId,
    DateTime? month,
  }) async {
    var q = _client.from(kTablePayments).select();

    if (studentId != null && studentId.isNotEmpty) {
      q = q.eq('student_id', studentId);
    }
    if (courseId != null && courseId.isNotEmpty) {
      q = q.eq('course_id', courseId);
    }
    if (month != null) {
      final m = DateTime(month.year, month.month, 1);
      q = q.eq('for_month', dateToSqlDate(m));
    }

    final rows = await q.order('paid_at', ascending: false);
    return (rows as List<dynamic>)
        .map((e) => PaymentModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Lists payment due rows with optional course and billing month.
  Future<List<PaymentDueModel>> getDues({
    String? courseId,
    String? studentId,
    DateTime? month,
  }) async {
    var q = _client.from(kTablePaymentDues).select();

    if (studentId != null && studentId.isNotEmpty) {
      q = q.eq('student_id', studentId);
    }
    if (courseId != null && courseId.isNotEmpty) {
      q = q.eq('course_id', courseId);
    }
    if (month != null) {
      final m = DateTime(month.year, month.month, 1);
      q = q.eq('for_month', dateToSqlDate(m));
    }

    final rows = await q.order('for_month', ascending: false);
    return (rows as List<dynamic>)
        .map((e) => PaymentDueModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Inserts a payment (empty [PaymentModel.voucherNo] lets DB trigger assign RCC-VCH-…),
  /// then marks the matching `payment_dues` row as paid for the same student/course/month.
  Future<PaymentModel> addPayment(PaymentModel payment) async {
    final id = payment.id.isNotEmpty ? payment.id : _uuid.v4();
    final paidAt = payment.paidAt ?? DateTime.now();

    final insert = <String, dynamic>{
      'id': id,
      'student_id': payment.studentId,
      'course_id': payment.courseId,
      'for_month': dateToSqlDate(payment.forMonth),
      'amount': payment.amount,
      'payment_method': payment.paymentMethod?.toJson(),
      'status': payment.status.toJson(),
      'note': payment.note,
      'paid_at': paidAt.toUtc().toIso8601String(),
      'created_by': payment.createdBy,
    };

    if (payment.voucherNo.isEmpty) {
      insert['voucher_no'] = '';
    } else {
      insert['voucher_no'] = payment.voucherNo;
    }

    final row = await _client.from(kTablePayments).insert(insert).select().single();

    final nowIso = DateTime.now().toUtc().toIso8601String();
    await _client
        .from(kTablePaymentDues)
        .update(<String, dynamic>{
          'status': DueStatus.paid.toJson(),
          'updated_at': nowIso,
        })
        .eq('student_id', payment.studentId)
        .eq('course_id', payment.courseId)
        .eq('for_month', dateToSqlDate(payment.forMonth));

    return PaymentModel.fromJson(Map<String, dynamic>.from(row));
  }

  /// Last six calendar months (oldest → newest), each with total collected [amount] by `paid_at`.
  ///
  /// Map keys: `month` (`yyyy-MM`), `label` (short English, e.g. `Nov 2025`), `amount` ([double]).
  Future<List<Map<String, dynamic>>> getMonthlyRevenue() async {
    final now = DateTime.now();
    final rangeStart = DateTime(now.year, now.month - 5, 1);
    final rangeEnd = DateTime(now.year, now.month + 1, 1);

    final rows = await _client
        .from(kTablePayments)
        .select('amount, paid_at')
        .gte('paid_at', rangeStart.toUtc().toIso8601String())
        .lt('paid_at', rangeEnd.toUtc().toIso8601String());

    final buckets = <String, double>{};
    final labels = <String, String>{};
    final orderedKeys = <String>[];

    for (var i = 0; i < 6; i++) {
      final d = DateTime(now.year, now.month - 5 + i, 1);
      final key = '${d.year}-${d.month.toString().padLeft(2, '0')}';
      orderedKeys.add(key);
      buckets[key] = 0;
      labels[key] = _monthLabelEn(d);
    }

    for (final raw in rows as List<dynamic>) {
      final m = Map<String, dynamic>.from(raw as Map);
      final paidAt = _parsePaidAt(m['paid_at']);
      if (paidAt == null) continue;
      final local = paidAt.toLocal();
      final key =
          '${local.year}-${local.month.toString().padLeft(2, '0')}';
      if (!buckets.containsKey(key)) continue;
      final amt = _parseAmount(m['amount']);
      buckets[key] = (buckets[key] ?? 0) + amt;
    }

    return orderedKeys
        .map(
          (k) => <String, dynamic>{
            'month': k,
            'label': labels[k] ?? k,
            'amount': buckets[k] ?? 0.0,
          },
        )
        .toList();
  }

  /// Students with a **past** unpaid month: `payment_dues.status = due` and
  /// `for_month` before the first day of the current calendar month.
  Future<List<OverdueStudentInfo>> getOverdueStudents() async {
    final today = DateTime.now();
    final thisMonthStart = DateTime(today.year, today.month, 1);
    final cutoff = dateToSqlDate(thisMonthStart);

    final dueRows = await _client
        .from(kTablePaymentDues)
        .select()
        .eq('status', DueStatus.due.toJson())
        .lt('for_month', cutoff);

    final list = (dueRows as List<dynamic>)
        .map((e) => PaymentDueModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    if (list.isEmpty) return [];

    final studentIds = list.map((d) => d.studentId).toSet().toList();
    final courseIds = list.map((d) => d.courseId).toSet().toList();

    final usersRaw = await _client.from(kTableUsers).select().inFilter('id', studentIds);
    final coursesRaw = await _client.from(kTableCourses).select('id, name').inFilter('id', courseIds);

    final usersById = <String, UserModel>{};
    for (final raw in usersRaw as List<dynamic>) {
      final m = Map<String, dynamic>.from(raw as Map);
      usersById[m['id'] as String] = UserModel.fromJson(m);
    }

    final courseNames = <String, String>{};
    for (final raw in coursesRaw as List<dynamic>) {
      final m = Map<String, dynamic>.from(raw as Map);
      courseNames[m['id'] as String] = m['name'] as String? ?? '';
    }

    final out = <OverdueStudentInfo>[];
    for (final due in list) {
      final student = usersById[due.studentId];
      if (student == null) continue;
      out.add(
        OverdueStudentInfo(
          student: student,
          due: due,
          courseName: courseNames[due.courseId] ?? '',
        ),
      );
    }
    return out;
  }
}

String _monthLabelEn(DateTime d) {
  const names = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${names[d.month - 1]} ${d.year}';
}

DateTime? _parsePaidAt(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

double _parseAmount(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}
