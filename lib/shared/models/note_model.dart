/// Matches `notes` table — materials under a chapter (PDF, text, **lecture**, etc.).
class NoteModel {
  const NoteModel({
    required this.id,
    required this.chapterId,
    required this.title,
    this.description,
    required this.type,
    this.fileUrl,
    this.youtubeUrl,
    this.externalUrl,
    this.textContent,
    this.content,
    this.fileSizeKb,
    this.durationSeconds,
    this.thumbnailUrl,
    this.isPublished,
    this.displayOrder,
    this.viewCount,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String chapterId;
  final String title;
  final String? description;
  /// `lecture` = markdown in [content], optional video URL in [fileUrl].
  final String type;
  final String? fileUrl;
  final String? youtubeUrl;
  final String? externalUrl;
  final String? textContent;
  final String? content;
  final int? fileSizeKb;
  final int? durationSeconds;
  final String? thumbnailUrl;
  final bool? isPublished;
  final int? displayOrder;
  final int? viewCount;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory NoteModel.fromJson(Map<String, dynamic> json) {
    return NoteModel(
      id: json['id'] as String,
      chapterId: json['chapter_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      type: json['type'] as String? ?? 'text',
      fileUrl: json['file_url'] as String?,
      youtubeUrl: json['youtube_url'] as String?,
      externalUrl: json['external_url'] as String?,
      textContent: json['text_content'] as String?,
      content: json['content'] as String?,
      fileSizeKb: (json['file_size_kb'] as num?)?.toInt(),
      durationSeconds: (json['duration_seconds'] as num?)?.toInt(),
      thumbnailUrl: json['thumbnail_url'] as String?,
      isPublished: json['is_published'] as bool?,
      displayOrder: (json['display_order'] as num?)?.toInt(),
      viewCount: (json['view_count'] as num?)?.toInt(),
      createdBy: json['created_by'] as String?,
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'chapter_id': chapterId,
      'title': title,
      'description': description,
      'type': type,
      'file_url': fileUrl,
      'youtube_url': youtubeUrl,
      'external_url': externalUrl,
      'text_content': textContent,
      'content': content,
      'file_size_kb': fileSizeKb,
      'duration_seconds': durationSeconds,
      'thumbnail_url': thumbnailUrl,
      'is_published': isPublished,
      'display_order': displayOrder,
      'view_count': viewCount,
      'created_by': createdBy,
      'created_at': createdAt?.toUtc().toIso8601String(),
      'updated_at': updatedAt?.toUtc().toIso8601String(),
    };
  }

  NoteModel copyWith({
    String? id,
    String? chapterId,
    String? title,
    String? description,
    String? type,
    String? fileUrl,
    String? youtubeUrl,
    String? externalUrl,
    String? textContent,
    String? content,
    int? fileSizeKb,
    int? durationSeconds,
    String? thumbnailUrl,
    bool? isPublished,
    int? displayOrder,
    int? viewCount,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return NoteModel(
      id: id ?? this.id,
      chapterId: chapterId ?? this.chapterId,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      fileUrl: fileUrl ?? this.fileUrl,
      youtubeUrl: youtubeUrl ?? this.youtubeUrl,
      externalUrl: externalUrl ?? this.externalUrl,
      textContent: textContent ?? this.textContent,
      content: content ?? this.content,
      fileSizeKb: fileSizeKb ?? this.fileSizeKb,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      isPublished: isPublished ?? this.isPublished,
      displayOrder: displayOrder ?? this.displayOrder,
      viewCount: viewCount ?? this.viewCount,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

DateTime? _parseDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}
