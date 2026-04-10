enum PaymentScheduleStatus {
  pending,
  paid,
  partial,
  overdue,
  waived;

  static PaymentScheduleStatus fromJson(String? value) {
    if (value == null || value.isEmpty) return PaymentScheduleStatus.pending;
    return PaymentScheduleStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => PaymentScheduleStatus.pending,
    );
  }

  String toJson() => name;
}

class PaymentScheduleModel {
  const PaymentScheduleModel({
    required this.id,
    required this.studentId,
    required this.courseId,
    required this.paymentTypeId,
    required this.paymentTypeCode,
    this.forMonth,
    required this.dueDate,
    required this.amount,
    required this.status,
    this.paidAmount = 0,
    this.remainingAmount = 0,
    this.note,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String studentId;
  final String courseId;
  final String paymentTypeId;
  final String paymentTypeCode;
  final DateTime? forMonth;
  final DateTime dueDate;
  final double amount;
  final PaymentScheduleStatus status;
  final double paidAmount;
  final double remainingAmount;
  final String? note;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory PaymentScheduleModel.fromJson(Map<String, dynamic> json) {
    return PaymentScheduleModel(
      id: json['id'] as String,
      studentId: json['student_id'] as String,
      courseId: json['course_id'] as String,
      paymentTypeId: json['payment_type_id'] as String,
      paymentTypeCode: json['payment_type_code'] as String? ?? '',
      forMonth: _parseDateTime(json['for_month']),
      dueDate: _parseDateRequired(json['due_date']),
      amount: _parseDouble(json['amount']),
      status: PaymentScheduleStatus.fromJson(json['status'] as String?),
      paidAmount: _parseDouble(json['paid_amount'] ?? 0),
      remainingAmount: _parseDouble(json['remaining_amount'] ?? 0),
      note: json['note'] as String?,
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
    );
  }
}

double _parseDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}

DateTime _parseDateRequired(dynamic value) {
  final dt = _parseDateTime(value);
  if (dt == null) {
    throw FormatException('Invalid date value: $value');
  }
  return DateTime.utc(dt.year, dt.month, dt.day);
}

DateTime? _parseDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}
