/// Matches `subjects` table (see `plan/03_database_roadmap.md`).
class SubjectModel {
  const SubjectModel({
    required this.id,
    required this.courseId,
    required this.name,
    this.description,
    required this.displayOrder,
    required this.isActive,
    this.createdAt,
  });

  final String id;
  final String courseId;
  final String name;
  final String? description;
  final int displayOrder;
  final bool isActive;
  final DateTime? createdAt;

  factory SubjectModel.fromJson(Map<String, dynamic> json) {
    return SubjectModel(
      id: json['id'] as String,
      courseId: json['course_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      displayOrder: (json['display_order'] as num?)?.toInt() ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: _parseDateTime(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'course_id': courseId,
      'name': name,
      'description': description,
      'display_order': displayOrder,
      'is_active': isActive,
      'created_at': createdAt?.toUtc().toIso8601String(),
    };
  }

  SubjectModel copyWith({
    String? id,
    String? courseId,
    String? name,
    String? description,
    int? displayOrder,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return SubjectModel(
      id: id ?? this.id,
      courseId: courseId ?? this.courseId,
      name: name ?? this.name,
      description: description ?? this.description,
      displayOrder: displayOrder ?? this.displayOrder,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

DateTime? _parseDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}
