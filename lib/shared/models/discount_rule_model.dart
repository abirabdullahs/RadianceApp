enum DiscountType {
  percentage,
  fixed;

  static DiscountType fromJson(String? value) {
    if (value == null || value.isEmpty) return DiscountType.percentage;
    return DiscountType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => DiscountType.percentage,
    );
  }

  String toJson() => name;
}

class DiscountRuleModel {
  const DiscountRuleModel({
    required this.id,
    required this.name,
    required this.nameBn,
    required this.discountType,
    required this.discountValue,
    required this.appliesTo,
    required this.isActive,
    this.createdAt,
  });

  final String id;
  final String name;
  final String nameBn;
  final DiscountType discountType;
  final double discountValue;
  final String appliesTo;
  final bool isActive;
  final DateTime? createdAt;

  factory DiscountRuleModel.fromJson(Map<String, dynamic> json) {
    return DiscountRuleModel(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      nameBn: json['name_bn'] as String? ?? '',
      discountType: DiscountType.fromJson(json['discount_type'] as String?),
      discountValue: _parseDouble(json['discount_value']),
      appliesTo: json['applies_to'] as String? ?? 'monthly',
      isActive: json['is_active'] as bool? ?? true,
      createdAt: _parseDateTime(json['created_at']),
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
