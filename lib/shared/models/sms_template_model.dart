class SmsTemplateModel {
  const SmsTemplateModel({
    required this.id,
    required this.templateKey,
    required this.name,
    required this.body,
    required this.isActive,
  });

  final String id;
  final String templateKey;
  final String name;
  final String body;
  final bool isActive;

  factory SmsTemplateModel.fromJson(Map<String, dynamic> json) {
    return SmsTemplateModel(
      id: json['id'] as String,
      templateKey: json['template_key'] as String? ?? '',
      name: json['name'] as String? ?? '',
      body: json['body'] as String? ?? '',
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}
