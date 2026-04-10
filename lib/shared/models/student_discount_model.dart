class StudentDiscountModel {
  const StudentDiscountModel({
    required this.id,
    required this.studentId,
    required this.courseId,
    this.discountRuleId,
    this.customAmount,
    this.customReason,
    required this.appliesTo,
    required this.validFrom,
    this.validUntil,
    required this.isActive,
    this.createdBy,
    this.createdAt,
  });

  final String id;
  final String studentId;
  final String courseId;
  final String? discountRuleId;
  final double? customAmount;
  final String? customReason;
  final String appliesTo;
  final DateTime validFrom;
  final DateTime? validUntil;
  final bool isActive;
  final String? createdBy;
  final DateTime? createdAt;

  factory StudentDiscountModel.fromJson(Map<String, dynamic> json) {
    return StudentDiscountModel(
      id: json['id'] as String,
      studentId: json['student_id'] as String,
      courseId: json['course_id'] as String,
      discountRuleId: json['discount_rule_id'] as String?,
      customAmount: _parseNullableDouble(json['custom_amount']),
      customReason: json['custom_reason'] as String?,
      appliesTo: json['applies_to'] as String? ?? 'monthly',
      validFrom: _parseDateRequired(json['valid_from']),
      validUntil: _parseDateTime(json['valid_until']),
      isActive: json['is_active'] as bool? ?? true,
      createdBy: json['created_by'] as String?,
      createdAt: _parseDateTime(json['created_at']),
    );
  }
}

double? _parseNullableDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
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
