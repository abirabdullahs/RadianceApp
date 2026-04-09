/// Matches `payments` table (see `plan/03_database_roadmap.md`).
enum PaymentMethod {
  cash,
  bkash,
  nagad,
  bank,
  other;

  static PaymentMethod? fromJson(String? value) {
    if (value == null || value.isEmpty) return null;
    return PaymentMethod.values.firstWhere(
      (e) => e.name == value,
      orElse: () => PaymentMethod.other,
    );
  }

  String toJson() => name;
}

enum PaymentStatus {
  paid,
  partial;

  static PaymentStatus fromJson(String value) {
    return PaymentStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => PaymentStatus.paid,
    );
  }

  String toJson() => name;
}

class PaymentModel {
  const PaymentModel({
    required this.id,
    required this.voucherNo,
    required this.studentId,
    required this.courseId,
    required this.forMonth,
    required this.amount,
    required this.subtotal,
    this.discount = 0,
    this.feeServiceId,
    this.paymentMethod,
    required this.status,
    this.note,
    this.paidAt,
    this.createdBy,
  });

  final String id;
  final String voucherNo;
  final String studentId;
  final String courseId;

  /// First day of the billing month (DATE in DB).
  final DateTime forMonth;

  /// Grand total (after discount).
  final double amount;

  /// Before discount (equals [amount] when discount is 0).
  final double subtotal;

  /// Taka discounted from subtotal.
  final double discount;

  /// Optional link to `fee_services`.
  final String? feeServiceId;
  final PaymentMethod? paymentMethod;
  final PaymentStatus status;
  final String? note;
  final DateTime? paidAt;
  final String? createdBy;

  factory PaymentModel.fromJson(Map<String, dynamic> json) {
    final amt = _parseDouble(json['amount']);
    final parsedSub =
        json['subtotal'] == null ? amt : _parseDouble(json['subtotal']);
    return PaymentModel(
      id: json['id'] as String,
      voucherNo: json['voucher_no'] as String,
      studentId: json['student_id'] as String,
      courseId: json['course_id'] as String,
      forMonth: _parseDateRequired(json['for_month']),
      amount: amt,
      subtotal: parsedSub,
      discount: _parseDouble(json['discount'] ?? 0),
      feeServiceId: json['fee_service_id'] as String?,
      paymentMethod: PaymentMethod.fromJson(json['payment_method'] as String?),
      status: PaymentStatus.fromJson(json['status'] as String? ?? 'paid'),
      note: json['note'] as String?,
      paidAt: _parseDateTime(json['paid_at']),
      createdBy: json['created_by'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'voucher_no': voucherNo,
      'student_id': studentId,
      'course_id': courseId,
      'for_month': _dateToSqlDate(forMonth),
      'amount': amount,
      'subtotal': subtotal,
      'discount': discount,
      if (feeServiceId != null) 'fee_service_id': feeServiceId,
      'payment_method': paymentMethod?.toJson(),
      'status': status.toJson(),
      'note': note,
      'paid_at': paidAt?.toUtc().toIso8601String(),
      'created_by': createdBy,
    };
  }

  PaymentModel copyWith({
    String? id,
    String? voucherNo,
    String? studentId,
    String? courseId,
    DateTime? forMonth,
    double? amount,
    double? subtotal,
    double? discount,
    String? feeServiceId,
    PaymentMethod? paymentMethod,
    PaymentStatus? status,
    String? note,
    DateTime? paidAt,
    String? createdBy,
  }) {
    return PaymentModel(
      id: id ?? this.id,
      voucherNo: voucherNo ?? this.voucherNo,
      studentId: studentId ?? this.studentId,
      courseId: courseId ?? this.courseId,
      forMonth: forMonth ?? this.forMonth,
      amount: amount ?? this.amount,
      subtotal: subtotal ?? this.subtotal,
      discount: discount ?? this.discount,
      feeServiceId: feeServiceId ?? this.feeServiceId,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      status: status ?? this.status,
      note: note ?? this.note,
      paidAt: paidAt ?? this.paidAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }
}

double _parseDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}

DateTime? _parseDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

DateTime _parseDateRequired(dynamic value) {
  final dt = _parseDateTime(value);
  if (dt == null) {
    throw FormatException('for_month: expected date, got $value');
  }
  return DateTime.utc(dt.year, dt.month, dt.day);
}

String _dateToSqlDate(DateTime d) {
  final u = DateTime.utc(d.year, d.month, d.day);
  return '${u.year.toString().padLeft(4, '0')}-'
      '${u.month.toString().padLeft(2, '0')}-'
      '${u.day.toString().padLeft(2, '0')}';
}
