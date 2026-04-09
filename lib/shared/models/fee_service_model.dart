/// `fee_services` — catalog for payment line (monthly fee, admission, etc.).
class FeeServiceModel {
  const FeeServiceModel({
    required this.id,
    required this.name,
    this.sortOrder = 0,
  });

  final String id;
  final String name;
  final int sortOrder;

  factory FeeServiceModel.fromJson(Map<String, dynamic> json) {
    return FeeServiceModel(
      id: json['id'] as String,
      name: json['name'] as String,
      sortOrder: json['sort_order'] as int? ?? 0,
    );
  }
}
