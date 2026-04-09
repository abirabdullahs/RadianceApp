/// Matches `payment_dues` table (see `plan/03_database_roadmap.md`).
enum DueStatus {
  due,
  paid,
  partial,
  waived;

  static DueStatus fromJson(String value) {
    return DueStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => DueStatus.due,
    );
  }

  String toJson() => name;
}

class PaymentDueModel {
  const PaymentDueModel({
    required this.id,
    required this.studentId,
    required this.courseId,
    required this.forMonth,
    required this.amount,
    required this.status,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String studentId;
  final String courseId;

  /// First day of the billing month (DATE in DB).
  final DateTime forMonth;
  final double amount;
  final DueStatus status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory PaymentDueModel.fromJson(Map<String, dynamic> json) {
    return PaymentDueModel(
      id: json['id'] as String,
      studentId: json['student_id'] as String,
      courseId: json['course_id'] as String,
      forMonth: _parseDateRequired(json['for_month']),
      amount: _parseDouble(json['amount']),
      status: DueStatus.fromJson(json['status'] as String? ?? 'due'),
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'student_id': studentId,
      'course_id': courseId,
      'for_month': dateToSqlDate(forMonth),
      'amount': amount,
      'status': status.toJson(),
      'created_at': createdAt?.toUtc().toIso8601String(),
      'updated_at': updatedAt?.toUtc().toIso8601String(),
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

DateTime _parseDateRequired(dynamic value) {
  final dt = _parseDateTime(value);
  if (dt == null) {
    throw FormatException('for_month: expected date, got $value');
  }
  return DateTime.utc(dt.year, dt.month, dt.day);
}

/// SQL `DATE` string (YYYY-MM-DD) for Supabase filters and inserts.
String dateToSqlDate(DateTime d) {
  final u = DateTime.utc(d.year, d.month, d.day);
  return '${u.year.toString().padLeft(4, '0')}-'
      '${u.month.toString().padLeft(2, '0')}-'
      '${u.day.toString().padLeft(2, '0')}';
}
