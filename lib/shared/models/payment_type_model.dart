class PaymentTypeModel {
  const PaymentTypeModel({
    required this.id,
    required this.name,
    required this.nameBn,
    required this.code,
    required this.isRecurring,
    this.defaultAmount,
    required this.isActive,
    required this.colorHex,
    this.createdAt,
  });

  final String id;
  final String name;
  final String nameBn;
  final String code;
  final bool isRecurring;
  final double? defaultAmount;
  final bool isActive;
  final String colorHex;
  final DateTime? createdAt;

  factory PaymentTypeModel.fromJson(Map<String, dynamic> json) {
    return PaymentTypeModel(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      nameBn: json['name_bn'] as String? ?? '',
      code: json['code'] as String? ?? '',
      isRecurring: json['is_recurring'] as bool? ?? false,
      defaultAmount: _parseNullableDouble(json['default_amount']),
      isActive: json['is_active'] as bool? ?? true,
      colorHex: json['color_hex'] as String? ?? '#1A3C6E',
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

DateTime? _parseDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}
