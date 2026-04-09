/// `doubt_threads.status`
enum DoubtStatus {
  open,
  solved;

  static DoubtStatus fromJson(String? v) {
    return DoubtStatus.values.firstWhere(
      (e) => e.name == v,
      orElse: () => DoubtStatus.open,
    );
  }

  String toJson() => name;
}

class DoubtThreadModel {
  const DoubtThreadModel({
    required this.id,
    required this.studentId,
    required this.problemDescription,
    this.problemImageUrl,
    required this.status,
    this.solvedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String studentId;
  final String problemDescription;
  final String? problemImageUrl;
  final DoubtStatus status;
  final DateTime? solvedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory DoubtThreadModel.fromJson(Map<String, dynamic> json) {
    return DoubtThreadModel(
      id: json['id'] as String,
      studentId: json['student_id'] as String,
      problemDescription: json['problem_description'] as String? ?? '',
      problemImageUrl: json['problem_image_url'] as String?,
      status: DoubtStatus.fromJson(json['status'] as String?),
      solvedAt: _parse(json['solved_at']),
      createdAt: _parse(json['created_at']),
      updatedAt: _parse(json['updated_at']),
    );
  }

  static DateTime? _parse(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString());
  }
}
