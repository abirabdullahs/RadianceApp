enum LedgerPaymentStatus {
  paid,
  partial,
  advance,
  waived;

  static LedgerPaymentStatus fromJson(String? value) {
    if (value == null || value.isEmpty) return LedgerPaymentStatus.paid;
    return LedgerPaymentStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => LedgerPaymentStatus.paid,
    );
  }

  String toJson() => name;
}

class PaymentLedgerModel {
  const PaymentLedgerModel({
    required this.id,
    required this.voucherNo,
    required this.studentId,
    required this.courseId,
    required this.paymentTypeId,
    required this.paymentTypeCode,
    this.forMonth,
    required this.amountDue,
    required this.amountPaid,
    this.discountAmount = 0,
    this.fineAmount = 0,
    required this.paymentMethod,
    this.transactionRef,
    required this.status,
    this.note,
    this.description,
    this.paidAt,
    this.createdBy,
    this.createdAt,
  });

  final String id;
  final String voucherNo;
  final String studentId;
  final String courseId;
  final String paymentTypeId;
  final String paymentTypeCode;
  final DateTime? forMonth;
  final double amountDue;
  final double amountPaid;
  final double discountAmount;
  final double fineAmount;
  final String paymentMethod;
  final String? transactionRef;
  final LedgerPaymentStatus status;
  final String? note;
  final String? description;
  final DateTime? paidAt;
  final String? createdBy;
  final DateTime? createdAt;

  factory PaymentLedgerModel.fromJson(Map<String, dynamic> json) {
    return PaymentLedgerModel(
      id: json['id'] as String,
      voucherNo: json['voucher_no'] as String? ?? '',
      studentId: json['student_id'] as String,
      courseId: json['course_id'] as String,
      paymentTypeId: json['payment_type_id'] as String,
      paymentTypeCode: json['payment_type_code'] as String? ?? '',
      forMonth: _parseDateTime(json['for_month']),
      amountDue: _parseDouble(json['amount_due']),
      amountPaid: _parseDouble(json['amount_paid']),
      discountAmount: _parseDouble(json['discount_amount'] ?? 0),
      fineAmount: _parseDouble(json['fine_amount'] ?? 0),
      paymentMethod: json['payment_method'] as String? ?? 'cash',
      transactionRef: json['transaction_ref'] as String?,
      status: LedgerPaymentStatus.fromJson(json['status'] as String?),
      note: json['note'] as String?,
      description: json['description'] as String?,
      paidAt: _parseDateTime(json['paid_at']),
      createdBy: json['created_by'] as String?,
      createdAt: _parseDateTime(json['created_at']),
    );
  }

  Map<String, dynamic> toInsertJson() {
    return <String, dynamic>{
      if (voucherNo.trim().isNotEmpty) 'voucher_no': voucherNo.trim(),
      'student_id': studentId,
      'course_id': courseId,
      'payment_type_id': paymentTypeId,
      'payment_type_code': paymentTypeCode,
      if (forMonth != null) 'for_month': _dateToSqlDate(forMonth!),
      'amount_due': amountDue,
      'amount_paid': amountPaid,
      'discount_amount': discountAmount,
      'fine_amount': fineAmount,
      'payment_method': paymentMethod,
      'transaction_ref': transactionRef,
      'status': status.toJson(),
      'note': note,
      'description': description,
      'paid_at': paidAt?.toUtc().toIso8601String(),
      'created_by': createdBy,
    };
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

String _dateToSqlDate(DateTime d) {
  final u = DateTime.utc(d.year, d.month, d.day);
  return '${u.year.toString().padLeft(4, '0')}-'
      '${u.month.toString().padLeft(2, '0')}-'
      '${u.day.toString().padLeft(2, '0')}';
}
