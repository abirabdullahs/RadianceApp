/// `suggestions` row when tied to a chapter ([chapterId]) — MD in [content], PDF in [pdfUrl].
class ChapterSuggestionModel {
  const ChapterSuggestionModel({
    required this.id,
    required this.title,
    this.content,
    this.type,
    this.imageUrl,
    this.videoUrl,
    this.pdfUrl,
    this.courseId,
    this.chapterId,
    this.isPublished,
    this.likesCount,
    this.createdBy,
    this.createdAt,
  });

  final String id;
  final String title;
  final String? content;
  final String? type;
  final String? imageUrl;
  final String? videoUrl;
  final String? pdfUrl;
  final String? courseId;
  final String? chapterId;
  final bool? isPublished;
  final int? likesCount;
  final String? createdBy;
  final DateTime? createdAt;

  factory ChapterSuggestionModel.fromJson(Map<String, dynamic> json) {
    return ChapterSuggestionModel(
      id: json['id'] as String,
      title: json['title'] as String,
      content: json['content'] as String?,
      type: json['type'] as String?,
      imageUrl: json['image_url'] as String?,
      videoUrl: json['video_url'] as String?,
      pdfUrl: json['pdf_url'] as String?,
      courseId: json['course_id'] as String?,
      chapterId: json['chapter_id'] as String?,
      isPublished: json['is_published'] as bool?,
      likesCount: (json['likes_count'] as num?)?.toInt(),
      createdBy: json['created_by'] as String?,
      createdAt: _parseDateTime(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'content': content,
      'type': type ?? 'tip',
      'image_url': imageUrl,
      'video_url': videoUrl,
      'pdf_url': pdfUrl,
      'course_id': courseId,
      'chapter_id': chapterId,
      'is_published': isPublished ?? true,
      'likes_count': likesCount,
      'created_by': createdBy,
      'created_at': createdAt?.toUtc().toIso8601String(),
    };
  }
}

DateTime? _parseDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}
