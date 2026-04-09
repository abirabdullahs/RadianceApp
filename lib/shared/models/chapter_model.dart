/// Matches `chapters` table (see `plan/03_database_roadmap.md`).
class ChapterModel {
  const ChapterModel({
    required this.id,
    required this.subjectId,
    required this.name,
    this.description,
    required this.displayOrder,
    required this.isActive,
    this.createdAt,
  });

  final String id;
  final String subjectId;
  final String name;
  final String? description;
  final int displayOrder;
  final bool isActive;
  final DateTime? createdAt;

  factory ChapterModel.fromJson(Map<String, dynamic> json) {
    return ChapterModel(
      id: json['id'] as String,
      subjectId: json['subject_id'] as String,
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
      'subject_id': subjectId,
      'name': name,
      'description': description,
      'display_order': displayOrder,
      'is_active': isActive,
      'created_at': createdAt?.toUtc().toIso8601String(),
    };
  }

  ChapterModel copyWith({
    String? id,
    String? subjectId,
    String? name,
    String? description,
    int? displayOrder,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return ChapterModel(
      id: id ?? this.id,
      subjectId: subjectId ?? this.subjectId,
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
