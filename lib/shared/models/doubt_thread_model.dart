/// `doubt_threads.status`
enum DoubtStatus {
  open,
  inProgress,
  meetingScheduled,
  solved;

  static DoubtStatus fromJson(String? v) {
    switch (v) {
      case 'in_progress':
        return DoubtStatus.inProgress;
      case 'meeting_scheduled':
        return DoubtStatus.meetingScheduled;
      case 'solved':
        return DoubtStatus.solved;
      case 'open':
      default:
        return DoubtStatus.open;
    }
  }

  String toJson() {
    switch (this) {
      case DoubtStatus.open:
        return 'open';
      case DoubtStatus.inProgress:
        return 'in_progress';
      case DoubtStatus.meetingScheduled:
        return 'meeting_scheduled';
      case DoubtStatus.solved:
        return 'solved';
    }
  }
}

class DoubtThreadModel {
  const DoubtThreadModel({
    required this.id,
    required this.studentId,
    this.courseId,
    this.subject,
    this.chapter,
    required this.title,
    required this.problemDescription,
    this.problemImageUrl,
    this.resolutionType,
    this.meetingLink,
    this.meetingTime,
    this.meetingNote,
    this.solvedBy,
    required this.status,
    this.solvedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String studentId;
  final String? courseId;
  final String? subject;
  final String? chapter;
  final String title;
  final String problemDescription;
  final String? problemImageUrl;
  final String? resolutionType;
  final String? meetingLink;
  final DateTime? meetingTime;
  final String? meetingNote;
  final String? solvedBy;
  final DoubtStatus status;
  final DateTime? solvedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory DoubtThreadModel.fromJson(Map<String, dynamic> json) {
    return DoubtThreadModel(
      id: json['id'] as String,
      studentId: json['student_id'] as String,
      courseId: json['course_id'] as String?,
      subject: json['subject'] as String?,
      chapter: json['chapter'] as String?,
      title: (json['title'] as String?)?.trim().isNotEmpty == true
          ? (json['title'] as String).trim()
          : ((json['description'] as String?) ?? ''),
      problemDescription: json['description'] as String? ?? '',
      problemImageUrl: json['image_url'] as String?,
      resolutionType: json['resolution_type'] as String?,
      meetingLink: json['meeting_link'] as String?,
      meetingTime: _parse(json['meeting_time']),
      meetingNote: json['meeting_note'] as String?,
      solvedBy: json['solved_by'] as String?,
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
