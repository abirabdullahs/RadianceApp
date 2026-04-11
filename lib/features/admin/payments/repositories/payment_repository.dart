import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants.dart';
import '../../../../core/supabase_client.dart';
import '../../../../shared/models/fee_service_model.dart';
import '../../../../shared/models/overdue_student_info.dart';
import '../../../../shared/models/payment_ledger_model.dart';
import '../../../../shared/models/payment_due_model.dart';
import '../../../../shared/models/payment_model.dart';
import '../../../../shared/models/payment_schedule_model.dart';
import '../../../../shared/models/payment_type_model.dart';
import '../../../../shared/models/discount_rule_model.dart';
import '../../../../shared/models/student_discount_model.dart';
import '../../../../shared/models/advance_balance_model.dart';
import '../../../../shared/models/payment_report_models.dart';
import '../../../../shared/models/payment_settings_model.dart';
import '../../../../shared/models/user_model.dart';
import '../../students/repositories/student_repository.dart';

/// Payments, dues, revenue aggregates, overdue lists (Supabase).
class PaymentRepository {
  PaymentRepository({SupabaseClient? client}) : _client = client ?? supabaseClient;

  final SupabaseClient _client;
  static const _uuid = Uuid();

  /// Admin catalog: fee types (monthly, admission, …).
  Future<List<FeeServiceModel>> listFeeServices() async {
    final rows = await _client
        .from(kTableFeeServices)
        .select()
        .order('sort_order', ascending: true);
    final list = (rows as List<dynamic>)
        .map((e) => FeeServiceModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    list.sort((a, b) => a.sortOrder != b.sortOrder
        ? a.sortOrder.compareTo(b.sortOrder)
        : a.name.compareTo(b.name));
    return list;
  }

  Future<FeeServiceModel> addFeeService(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('empty name');
    }
    final row = await _client.from(kTableFeeServices).insert(<String, dynamic>{
      'name': trimmed,
      'sort_order': 50,
    }).select().single();
    return FeeServiceModel.fromJson(Map<String, dynamic>.from(row));
  }

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
  Future<PaymentModel?> getPaymentById(String id) async {
    final row = await _client.from(kTablePayments).select().eq('id', id).maybeSingle();
    if (row == null) return null;
    return PaymentModel.fromJson(Map<String, dynamic>.from(row));
  }

  /// Updates an existing payment (voucher number unchanged).
  Future<PaymentModel> updatePayment(PaymentModel payment) async {
    final paidAt = payment.paidAt ?? DateTime.now();
    final update = <String, dynamic>{
      'student_id': payment.studentId,
      'course_id': payment.courseId,
      'for_month': dateToSqlDate(payment.forMonth),
      'amount': payment.amount,
      'subtotal': payment.subtotal,
      'discount': payment.discount,
      'payment_method': payment.paymentMethod?.toJson(),
      'status': payment.status.toJson(),
      'note': payment.note,
      'paid_at': paidAt.toUtc().toIso8601String(),
    };
    if (payment.feeServiceId != null && payment.feeServiceId!.isNotEmpty) {
      update['fee_service_id'] = payment.feeServiceId;
    } else {
      update['fee_service_id'] = null;
    }
    await _client.from(kTablePayments).update(update).eq('id', payment.id);
    final row = await _client.from(kTablePayments).select().eq('id', payment.id).single();
    return PaymentModel.fromJson(Map<String, dynamic>.from(row));
  }

  /// Deletes a payment and restores the matching [payment_dues] row to `due` if present.
  Future<void> deletePayment(String id) async {
    final p = await getPaymentById(id);
    if (p == null) return;
    await _client.from(kTablePayments).delete().eq('id', id);
    final nowIso = DateTime.now().toUtc().toIso8601String();
    await _client
        .from(kTablePaymentDues)
        .update(<String, dynamic>{
          'status': DueStatus.due.toJson(),
          'updated_at': nowIso,
        })
        .eq('student_id', p.studentId)
        .eq('course_id', p.courseId)
        .eq('for_month', dateToSqlDate(p.forMonth));
  }

  Future<PaymentModel> addPayment(PaymentModel payment) async {
    final id = payment.id.isNotEmpty ? payment.id : _uuid.v4();
    final paidAt = payment.paidAt ?? DateTime.now();

    final insert = <String, dynamic>{
      'id': id,
      'student_id': payment.studentId,
      'course_id': payment.courseId,
      'for_month': dateToSqlDate(payment.forMonth),
      'amount': payment.amount,
      'subtotal': payment.subtotal,
      'discount': payment.discount,
      'payment_method': payment.paymentMethod?.toJson(),
      'status': payment.status.toJson(),
      'note': payment.note,
      'paid_at': paidAt.toUtc().toIso8601String(),
      'created_by': payment.createdBy,
    };
    if (payment.feeServiceId != null && payment.feeServiceId!.isNotEmpty) {
      insert['fee_service_id'] = payment.feeServiceId;
    }

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

  /// Sum of [remaining_amount] for rows still owing (pending / partial / overdue).
  Future<double> sumOpenScheduleRemaining() async {
    final rows = await _client
        .from(kTablePaymentSchedule)
        .select('remaining_amount')
        .inFilter('status', ['pending', 'partial', 'overdue']);
    var t = 0.0;
    for (final raw in rows as List<dynamic>) {
      final m = Map<String, dynamic>.from(raw as Map);
      t += _parseAmount(m['remaining_amount']);
    }
    return double.parse(t.toStringAsFixed(2));
  }

  /// Last six calendar months (oldest → newest), each with total collected [amount] by `paid_at`.
  ///
  /// Map keys: `month` (`yyyy-MM`), `label` (short English, e.g. `Nov 2025`), `amount` ([double]).
  /// Optional [courseId] filters ledger rows to that course.
  Future<List<Map<String, dynamic>>> getMonthlyRevenue({String? courseId}) async {
    final now = DateTime.now();
    final rangeStart = DateTime(now.year, now.month - 5, 1);
    final rangeEnd = DateTime(now.year, now.month + 1, 1);

    var q = _client
        .from(kTablePaymentLedger)
        .select('amount_paid, paid_at')
        .gte('paid_at', rangeStart.toUtc().toIso8601String())
        .lt('paid_at', rangeEnd.toUtc().toIso8601String());
    if (courseId != null && courseId.isNotEmpty) {
      q = q.eq('course_id', courseId);
    }
    final rows = await q;

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
      final amt = _parseAmount(m['amount_paid']);
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

  // ---------------------------
  // Section 2: New payment domain data layer
  // ---------------------------

  Future<List<PaymentTypeModel>> listPaymentTypes({bool activeOnly = true}) async {
    var q = _client.from(kTablePaymentTypes).select();
    if (activeOnly) {
      q = q.eq('is_active', true);
    }
    final rows = await q.order('created_at', ascending: true);
    return (rows as List<dynamic>)
        .map((e) => PaymentTypeModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  static const _ledgerRowSelect =
      'id,voucher_no,student_id,course_id,payment_type_id,payment_type_code,for_month,amount_due,amount_paid,discount_amount,fine_amount,payment_method,transaction_ref,status,note,description,paid_at,created_by,created_at';

  /// Recent ledger rows for activity widgets (avoids loading full history).
  Future<List<PaymentLedgerModel>> getRecentPaymentLedger({
    required String studentId,
    int limit = 3,
  }) async {
    final rows = await _client
        .from(kTablePaymentLedger)
        .select(_ledgerRowSelect)
        .eq('student_id', studentId)
        .order('paid_at', ascending: false)
        .limit(limit);
    return (rows as List<dynamic>)
        .map((e) => PaymentLedgerModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<PaymentLedgerModel>> getPaymentLedger({
    String? studentId,
    String? courseId,
    String? paymentTypeCode,
    DateTime? month,
  }) async {
    var q = _client.from(kTablePaymentLedger).select();
    if (studentId != null && studentId.isNotEmpty) {
      q = q.eq('student_id', studentId);
    }
    if (courseId != null && courseId.isNotEmpty) {
      q = q.eq('course_id', courseId);
    }
    if (paymentTypeCode != null && paymentTypeCode.isNotEmpty) {
      q = q.eq('payment_type_code', paymentTypeCode);
    }
    if (month != null) {
      final m = DateTime(month.year, month.month, 1);
      q = q.eq('for_month', dateToSqlDate(m));
    }
    final rows = await q.order('paid_at', ascending: false);
    return (rows as List<dynamic>)
        .map((e) => PaymentLedgerModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<PaymentLedgerModel> addPaymentLedger(PaymentLedgerModel ledger) async {
    final row = await _client
        .from(kTablePaymentLedger)
        .insert(ledger.toInsertJson())
        .select()
        .single();
    return PaymentLedgerModel.fromJson(Map<String, dynamic>.from(row));
  }

  Future<PaymentLedgerModel?> getPaymentLedgerById(String id) async {
    final row = await _client.from(kTablePaymentLedger).select().eq('id', id).maybeSingle();
    if (row == null) return null;
    return PaymentLedgerModel.fromJson(Map<String, dynamic>.from(row));
  }

  Future<PaymentLedgerModel> updatePaymentLedgerRow({
    required String id,
    required double amountDue,
    required double discountAmount,
    required double fineAmount,
    required double amountPaid,
    required String paymentMethod,
    required LedgerPaymentStatus status,
    String? note,
    required DateTime paidAt,
  }) async {
    await _client.from(kTablePaymentLedger).update(<String, dynamic>{
      'amount_due': amountDue,
      'discount_amount': discountAmount,
      'fine_amount': fineAmount,
      'amount_paid': amountPaid,
      'payment_method': paymentMethod,
      'status': status.toJson(),
      'note': note,
      'paid_at': paidAt.toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
    final row = await _client.from(kTablePaymentLedger).select().eq('id', id).single();
    return PaymentLedgerModel.fromJson(Map<String, dynamic>.from(row));
  }

  Future<void> deletePaymentLedgerById(String id) async {
    await _client.from(kTablePaymentLedger).delete().eq('id', id);
  }

  Future<List<PaymentScheduleModel>> getPaymentSchedule({
    String? studentId,
    String? courseId,
    String? paymentTypeCode,
    DateTime? month,
    bool onlyOpen = false,
  }) async {
    var q = _client.from(kTablePaymentSchedule).select();
    if (studentId != null && studentId.isNotEmpty) {
      q = q.eq('student_id', studentId);
    }
    if (courseId != null && courseId.isNotEmpty) {
      q = q.eq('course_id', courseId);
    }
    if (paymentTypeCode != null && paymentTypeCode.isNotEmpty) {
      q = q.eq('payment_type_code', paymentTypeCode);
    }
    if (month != null) {
      final m = DateTime(month.year, month.month, 1);
      q = q.eq('for_month', dateToSqlDate(m));
    }
    if (onlyOpen) {
      q = q.inFilter('status', ['pending', 'partial', 'overdue']);
    }
    final rows = await q.order('due_date', ascending: true);
    return (rows as List<dynamic>)
        .map((e) => PaymentScheduleModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<DiscountRuleModel>> listDiscountRules({bool activeOnly = true}) async {
    var q = _client.from(kTableDiscountRules).select();
    if (activeOnly) {
      q = q.eq('is_active', true);
    }
    final rows = await q.order('created_at', ascending: false);
    return (rows as List<dynamic>)
        .map((e) => DiscountRuleModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<DiscountRuleModel> addDiscountRule({
    required String name,
    required String nameBn,
    required DiscountType discountType,
    required double discountValue,
    required String appliesTo,
    bool isActive = true,
  }) async {
    final row = await _client
        .from(kTableDiscountRules)
        .insert(<String, dynamic>{
          'name': name.trim(),
          'name_bn': nameBn.trim(),
          'discount_type': discountType.toJson(),
          'discount_value': discountValue,
          'applies_to': appliesTo.trim(),
          'is_active': isActive,
        })
        .select()
        .single();
    return DiscountRuleModel.fromJson(Map<String, dynamic>.from(row));
  }

  Future<DiscountRuleModel> updateDiscountRule({
    required String id,
    String? name,
    String? nameBn,
    DiscountType? discountType,
    double? discountValue,
    String? appliesTo,
    bool? isActive,
  }) async {
    final payload = <String, dynamic>{
      if (name != null) 'name': name.trim(),
      if (nameBn != null) 'name_bn': nameBn.trim(),
      if (discountType != null) 'discount_type': discountType.toJson(),
      if (discountValue != null) 'discount_value': discountValue,
      if (appliesTo != null) 'applies_to': appliesTo.trim(),
      if (isActive != null) 'is_active': isActive,
    };
    final row = await _client
        .from(kTableDiscountRules)
        .update(payload)
        .eq('id', id)
        .select()
        .single();
    return DiscountRuleModel.fromJson(Map<String, dynamic>.from(row));
  }

  Future<List<StudentDiscountModel>> getStudentDiscounts({
    String? studentId,
    String? courseId,
    bool onlyActive = true,
  }) async {
    var q = _client.from(kTableStudentDiscounts).select();
    if (studentId != null && studentId.isNotEmpty) {
      q = q.eq('student_id', studentId);
    }
    if (courseId != null && courseId.isNotEmpty) {
      q = q.eq('course_id', courseId);
    }
    if (onlyActive) {
      q = q.eq('is_active', true);
    }
    final rows = await q.order('created_at', ascending: false);
    return (rows as List<dynamic>)
        .map((e) => StudentDiscountModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<StudentDiscountModel> assignStudentDiscount({
    required String studentId,
    required String courseId,
    String? discountRuleId,
    double? customAmount,
    String? customReason,
    required String appliesTo,
    required DateTime validFrom,
    DateTime? validUntil,
    bool isActive = true,
    String? createdBy,
  }) async {
    final row = await _client
        .from(kTableStudentDiscounts)
        .insert(<String, dynamic>{
          'student_id': studentId,
          'course_id': courseId,
          'discount_rule_id': discountRuleId,
          'custom_amount': customAmount,
          'custom_reason': customReason,
          'applies_to': appliesTo,
          'valid_from': dateToSqlDate(validFrom),
          'valid_until': validUntil == null ? null : dateToSqlDate(validUntil),
          'is_active': isActive,
          'created_by': createdBy,
        })
        .select()
        .single();
    return StudentDiscountModel.fromJson(Map<String, dynamic>.from(row));
  }

  Future<void> setStudentDiscountActive({
    required String studentDiscountId,
    required bool isActive,
  }) async {
    await _client
        .from(kTableStudentDiscounts)
        .update(<String, dynamic>{'is_active': isActive})
        .eq('id', studentDiscountId);
  }

  Future<AdvanceBalanceModel?> getAdvanceBalance({
    required String studentId,
    required String courseId,
  }) async {
    final row = await _client
        .from(kTableAdvanceBalance)
        .select()
        .eq('student_id', studentId)
        .eq('course_id', courseId)
        .maybeSingle();
    if (row == null) return null;
    return AdvanceBalanceModel.fromJson(Map<String, dynamic>.from(row));
  }

  Future<AdvanceBalanceModel> upsertAdvanceBalance({
    required String studentId,
    required String courseId,
    required double balance,
  }) async {
    final row = await _client
        .from(kTableAdvanceBalance)
        .upsert(
          <String, dynamic>{
            'student_id': studentId,
            'course_id': courseId,
            'balance': balance,
            'last_updated': DateTime.now().toUtc().toIso8601String(),
          },
          onConflict: 'student_id,course_id',
        )
        .select()
        .single();
    return AdvanceBalanceModel.fromJson(Map<String, dynamic>.from(row));
  }

  Future<PaymentScheduleModel?> getScheduleTarget({
    required String studentId,
    required String courseId,
    required String paymentTypeId,
    DateTime? forMonth,
  }) async {
    var q = _client
        .from(kTablePaymentSchedule)
        .select()
        .eq('student_id', studentId)
        .eq('course_id', courseId)
        .eq('payment_type_id', paymentTypeId);
    if (forMonth == null) {
      q = q.isFilter('for_month', null);
    } else {
      q = q.eq('for_month', dateToSqlDate(DateTime(forMonth.year, forMonth.month, 1)));
    }
    final row = await q.maybeSingle();
    if (row == null) return null;
    return PaymentScheduleModel.fromJson(Map<String, dynamic>.from(row));
  }

  Future<PaymentScheduleModel> upsertPaymentSchedule({
    String? id,
    required String studentId,
    required String courseId,
    required String paymentTypeId,
    required String paymentTypeCode,
    DateTime? forMonth,
    required DateTime dueDate,
    required double amount,
    required PaymentScheduleStatus status,
    required double paidAmount,
    String? note,
  }) async {
    final payload = <String, dynamic>{
      if (id != null && id.isNotEmpty) 'id': id,
      'student_id': studentId,
      'course_id': courseId,
      'payment_type_id': paymentTypeId,
      'payment_type_code': paymentTypeCode,
      'for_month': forMonth == null
          ? null
          : dateToSqlDate(DateTime(forMonth.year, forMonth.month, 1)),
      'due_date': dateToSqlDate(DateTime(dueDate.year, dueDate.month, dueDate.day)),
      'amount': amount,
      'status': status.toJson(),
      'paid_amount': paidAmount,
      'note': note,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    final row = await _client
        .from(kTablePaymentSchedule)
        .upsert(
          payload,
          onConflict: 'student_id,course_id,payment_type_id,for_month',
        )
        .select()
        .single();
    return PaymentScheduleModel.fromJson(Map<String, dynamic>.from(row));
  }

  /// Updates a schedule row by primary key. Use when the row already exists.
  ///
  /// Composite [upsertPaymentSchedule] can fail with duplicate `payment_schedule_pkey`
  /// if `ON CONFLICT (student_id, course_id, payment_type_id, for_month)` does not
  /// match the stored row (e.g. `for_month` NULL semantics or date normalization),
  /// causing an `INSERT` with an existing `id`.
  Future<PaymentScheduleModel> updatePaymentScheduleById({
    required String id,
    required DateTime dueDate,
    required double amount,
    required PaymentScheduleStatus status,
    required double paidAmount,
    required String paymentTypeCode,
    String? note,
  }) async {
    final payload = <String, dynamic>{
      'payment_type_code': paymentTypeCode,
      'due_date': dateToSqlDate(DateTime(dueDate.year, dueDate.month, dueDate.day)),
      'amount': amount,
      'status': status.toJson(),
      'paid_amount': paidAmount,
      'note': note,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    final row = await _client
        .from(kTablePaymentSchedule)
        .update(payload)
        .eq('id', id)
        .select()
        .single();
    return PaymentScheduleModel.fromJson(Map<String, dynamic>.from(row));
  }

  Future<PaymentSettingsModel> getPaymentSettings() async {
    final row = await _client
        .from(kTablePaymentSettings)
        .select()
        .eq('singleton_key', 1)
        .maybeSingle();
    if (row == null) {
      return const PaymentSettingsModel();
    }
    return PaymentSettingsModel.fromJson(Map<String, dynamic>.from(row));
  }

  Future<PaymentSettingsModel> savePaymentSettings(PaymentSettingsModel settings) async {
    final row = await _client
        .from(kTablePaymentSettings)
        .upsert(
          settings.toUpsertJson(updatedBy: _client.auth.currentUser?.id),
          onConflict: 'singleton_key',
        )
        .select()
        .single();
    return PaymentSettingsModel.fromJson(Map<String, dynamic>.from(row));
  }

  Future<MonthlyCollectionReport> getMonthlyCollectionReport({
    required DateTime month,
    String? courseId,
  }) async {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);
    var q = _client
        .from(kTablePaymentLedger)
        .select('payment_type_code, amount_paid, student_id')
        .gte('paid_at', start.toUtc().toIso8601String())
        .lt('paid_at', end.toUtc().toIso8601String());
    if (courseId != null && courseId.isNotEmpty) {
      q = q.eq('course_id', courseId);
    }
    final rows = await q;
    final byType = <String, List<Map<String, dynamic>>>{};
    for (final raw in rows as List<dynamic>) {
      final m = Map<String, dynamic>.from(raw as Map);
      final key = (m['payment_type_code'] as String? ?? 'other').toLowerCase();
      byType.putIfAbsent(key, () => <Map<String, dynamic>>[]).add(m);
    }
    final breakdown = <MonthlyCollectionBreakdownRow>[];
    var total = 0.0;
    var tx = 0;
    for (final e in byType.entries) {
      final list = e.value;
      var subtotal = 0.0;
      final studentIds = <String>{};
      for (final m in list) {
        subtotal += _parseAmount(m['amount_paid']);
        final sid = m['student_id'] as String?;
        if (sid != null) studentIds.add(sid);
      }
      total += subtotal;
      tx += list.length;
      breakdown.add(
        MonthlyCollectionBreakdownRow(
          paymentTypeCode: e.key,
          collectedAmount: double.parse(subtotal.toStringAsFixed(2)),
          transactionsCount: list.length,
          studentCount: studentIds.length,
        ),
      );
    }
    breakdown.sort((a, b) => b.collectedAmount.compareTo(a.collectedAmount));
    return MonthlyCollectionReport(
      month: start,
      totalCollected: double.parse(total.toStringAsFixed(2)),
      totalTransactions: tx,
      breakdown: breakdown,
    );
  }

  Future<List<DueReportRow>> getDueReport({
    DateTime? month,
    String? courseId,
    bool overdueOnly = false,
  }) async {
    var q = _client
        .from(kTablePaymentSchedule)
        .select()
        .inFilter('status', ['pending', 'partial', 'overdue']);
    if (month != null) {
      q = q.eq('for_month', dateToSqlDate(DateTime(month.year, month.month, 1)));
    }
    if (courseId != null && courseId.isNotEmpty) {
      q = q.eq('course_id', courseId);
    }
    if (overdueOnly) {
      q = q.eq('status', 'overdue');
    }
    final rawRows = await q.order('due_date', ascending: true);
    final schedules = (rawRows as List<dynamic>)
        .map((e) => PaymentScheduleModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    if (schedules.isEmpty) return [];

    final studentIds = schedules.map((e) => e.studentId).toSet().toList();
    final courseIds = schedules.map((e) => e.courseId).toSet().toList();
    final usersRaw = await _client.from(kTableUsers).select('id, full_name_bn').inFilter('id', studentIds);
    final coursesRaw = await _client.from(kTableCourses).select('id, name').inFilter('id', courseIds);
    final users = <String, String>{};
    final courses = <String, String>{};
    for (final raw in usersRaw as List<dynamic>) {
      final m = Map<String, dynamic>.from(raw as Map);
      users[m['id'] as String] = m['full_name_bn'] as String? ?? 'Student';
    }
    for (final raw in coursesRaw) {
      final m = Map<String, dynamic>.from(raw);
      courses[m['id'] as String] = m['name'] as String? ?? 'Course';
    }

    final today = DateTime.now();
    return schedules.map((s) {
      final overdue = s.dueDate.isBefore(DateTime(today.year, today.month, today.day))
          ? DateTime(today.year, today.month, today.day)
              .difference(DateTime(s.dueDate.year, s.dueDate.month, s.dueDate.day))
              .inDays
          : 0;
      return DueReportRow(
        studentId: s.studentId,
        studentName: users[s.studentId] ?? s.studentId,
        courseId: s.courseId,
        courseName: courses[s.courseId] ?? s.courseId,
        paymentTypeCode: s.paymentTypeCode,
        forMonth: s.forMonth,
        status: s.status.name,
        amount: s.amount,
        paidAmount: s.paidAmount,
        remainingAmount: s.remainingAmount,
        dueDate: s.dueDate,
        overdueDays: overdue,
      );
    }).toList();
  }

  Future<StudentAnnualReport> getStudentAnnualReport({
    required String studentId,
    required int year,
  }) async {
    final resolved = await StudentRepository().resolveStudentUserId(studentId);
    if (resolved == null) {
      throw StateError('Student not found for: $studentId');
    }
    final start = DateTime(year, 1, 1);
    final end = DateTime(year + 1, 1, 1);
    final schedules = await _client
        .from(kTablePaymentSchedule)
        .select()
        .eq('student_id', resolved)
        .gte('due_date', dateToSqlDate(start))
        .lt('due_date', dateToSqlDate(end))
        .order('due_date', ascending: false);
    final rows = (schedules as List<dynamic>)
        .map((e) => PaymentScheduleModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    double totalDue = 0;
    double totalPaid = 0;
    double totalRemain = 0;
    final courseIds = rows.map((e) => e.courseId).toSet().toList();
    final coursesRaw = courseIds.isEmpty
        ? <dynamic>[]
        : await _client.from(kTableCourses).select('id, name').inFilter('id', courseIds);
    final courses = <String, String>{};
    for (final raw in coursesRaw) {
      final m = Map<String, dynamic>.from(raw);
      courses[m['id'] as String] = m['name'] as String? ?? 'Course';
    }
    final out = <DueReportRow>[];
    for (final s in rows) {
      totalDue += s.amount;
      totalPaid += s.paidAmount;
      totalRemain += s.remainingAmount;
      out.add(
        DueReportRow(
          studentId: s.studentId,
          studentName: '',
          courseId: s.courseId,
          courseName: courses[s.courseId] ?? s.courseId,
          paymentTypeCode: s.paymentTypeCode,
          forMonth: s.forMonth,
          status: s.status.name,
          amount: s.amount,
          paidAmount: s.paidAmount,
          remainingAmount: s.remainingAmount,
          dueDate: s.dueDate,
          overdueDays: 0,
        ),
      );
    }
    return StudentAnnualReport(
      studentId: studentId,
      year: year,
      totalDue: double.parse(totalDue.toStringAsFixed(2)),
      totalPaid: double.parse(totalPaid.toStringAsFixed(2)),
      totalRemaining: double.parse(totalRemain.toStringAsFixed(2)),
      rows: out,
    );
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
