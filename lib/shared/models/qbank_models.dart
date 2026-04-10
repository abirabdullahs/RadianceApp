class QbankSession {
  const QbankSession({
    required this.id,
    required this.name,
    required this.nameBn,
    required this.displayOrder,
    required this.isActive,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String nameBn;
  final int displayOrder;
  final bool isActive;
  final DateTime createdAt;

  factory QbankSession.fromJson(Map<String, dynamic> json) {
    return QbankSession(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      nameBn: json['name_bn'] as String? ?? '',
      displayOrder: (json['display_order'] as num?)?.toInt() ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class QbankSubject {
  const QbankSubject({
    required this.id,
    required this.sessionId,
    required this.name,
    required this.nameBn,
    required this.displayOrder,
    required this.isActive,
    required this.createdAt,
  });

  final String id;
  final String sessionId;
  final String name;
  final String nameBn;
  final int displayOrder;
  final bool isActive;
  final DateTime createdAt;

  factory QbankSubject.fromJson(Map<String, dynamic> json) {
    return QbankSubject(
      id: json['id'] as String,
      sessionId: json['session_id'] as String,
      name: json['name'] as String? ?? '',
      nameBn: json['name_bn'] as String? ?? '',
      displayOrder: (json['display_order'] as num?)?.toInt() ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class QbankChapter {
  const QbankChapter({
    required this.id,
    required this.subjectId,
    required this.name,
    required this.nameBn,
    required this.displayOrder,
    required this.isActive,
    required this.createdAt,
  });

  final String id;
  final String subjectId;
  final String name;
  final String nameBn;
  final int displayOrder;
  final bool isActive;
  final DateTime createdAt;

  factory QbankChapter.fromJson(Map<String, dynamic> json) {
    return QbankChapter(
      id: json['id'] as String,
      subjectId: json['subject_id'] as String,
      name: json['name'] as String? ?? '',
      nameBn: json['name_bn'] as String? ?? '',
      displayOrder: (json['display_order'] as num?)?.toInt() ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class QbankMcq {
  const QbankMcq({
    required this.id,
    required this.chapterId,
    required this.questionText,
    this.imageUrl,
    required this.optionA,
    required this.optionB,
    required this.optionC,
    required this.optionD,
    required this.correctOption,
    this.explanation,
    this.explanationImageUrl,
    required this.difficulty,
    this.source,
    this.boardYear,
    this.boardName,
    required this.tags,
    required this.isPublished,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String chapterId;
  final String questionText;
  final String? imageUrl;
  final String optionA;
  final String optionB;
  final String optionC;
  final String optionD;
  final String correctOption;
  final String? explanation;
  final String? explanationImageUrl;
  final String difficulty;
  final String? source;
  final int? boardYear;
  final String? boardName;
  final List<String> tags;
  final bool isPublished;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory QbankMcq.fromJson(Map<String, dynamic> json) {
    return QbankMcq(
      id: json['id'] as String,
      chapterId: json['chapter_id'] as String,
      questionText: json['question_text'] as String? ?? '',
      imageUrl: json['image_url'] as String?,
      optionA: json['option_a'] as String? ?? '',
      optionB: json['option_b'] as String? ?? '',
      optionC: json['option_c'] as String? ?? '',
      optionD: json['option_d'] as String? ?? '',
      correctOption: (json['correct_option'] as String? ?? 'A').toUpperCase(),
      explanation: json['explanation'] as String?,
      explanationImageUrl: json['explanation_image_url'] as String?,
      difficulty: json['difficulty'] as String? ?? 'medium',
      source: json['source'] as String?,
      boardYear: (json['board_year'] as num?)?.toInt(),
      boardName: json['board_name'] as String?,
      tags: _asStringList(json['tags']),
      isPublished: json['is_published'] as bool? ?? true,
      createdBy: json['created_by'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'chapter_id': chapterId,
      'question_text': questionText,
      'image_url': imageUrl,
      'option_a': optionA,
      'option_b': optionB,
      'option_c': optionC,
      'option_d': optionD,
      'correct_option': correctOption,
      'explanation': explanation,
      'explanation_image_url': explanationImageUrl,
      'difficulty': difficulty,
      'source': source,
      'board_year': boardYear,
      'board_name': boardName,
      'tags': tags,
      'is_published': isPublished,
      'created_by': createdBy,
    };
  }
}

class QbankCq {
  const QbankCq({
    required this.id,
    required this.chapterId,
    required this.stemText,
    this.stemImageUrl,
    required this.gaText,
    this.gaImageUrl,
    this.gaAnswer,
    required this.gaMarks,
    required this.ghaText,
    this.ghaImageUrl,
    this.ghaAnswer,
    required this.ghaMarks,
    required this.difficulty,
    this.source,
    this.boardYear,
    this.boardName,
    required this.tags,
    required this.isPublished,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String chapterId;
  final String stemText;
  final String? stemImageUrl;
  final String gaText;
  final String? gaImageUrl;
  final String? gaAnswer;
  final int gaMarks;
  final String ghaText;
  final String? ghaImageUrl;
  final String? ghaAnswer;
  final int ghaMarks;
  final String difficulty;
  final String? source;
  final int? boardYear;
  final String? boardName;
  final List<String> tags;
  final bool isPublished;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory QbankCq.fromJson(Map<String, dynamic> json) {
    return QbankCq(
      id: json['id'] as String,
      chapterId: json['chapter_id'] as String,
      stemText: json['stem_text'] as String? ?? '',
      stemImageUrl: json['stem_image_url'] as String?,
      gaText: json['ga_text'] as String? ?? '',
      gaImageUrl: json['ga_image_url'] as String?,
      gaAnswer: json['ga_answer'] as String?,
      gaMarks: (json['ga_marks'] as num?)?.toInt() ?? 3,
      ghaText: json['gha_text'] as String? ?? '',
      ghaImageUrl: json['gha_image_url'] as String?,
      ghaAnswer: json['gha_answer'] as String?,
      ghaMarks: (json['gha_marks'] as num?)?.toInt() ?? 4,
      difficulty: json['difficulty'] as String? ?? 'medium',
      source: json['source'] as String?,
      boardYear: (json['board_year'] as num?)?.toInt(),
      boardName: json['board_name'] as String?,
      tags: _asStringList(json['tags']),
      isPublished: json['is_published'] as bool? ?? true,
      createdBy: json['created_by'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'chapter_id': chapterId,
      'stem_text': stemText,
      'stem_image_url': stemImageUrl,
      'ga_text': gaText,
      'ga_image_url': gaImageUrl,
      'ga_answer': gaAnswer,
      'ga_marks': gaMarks,
      'gha_text': ghaText,
      'gha_image_url': ghaImageUrl,
      'gha_answer': ghaAnswer,
      'gha_marks': ghaMarks,
      'difficulty': difficulty,
      'source': source,
      'board_year': boardYear,
      'board_name': boardName,
      'tags': tags,
      'is_published': isPublished,
      'created_by': createdBy,
    };
  }
}

class QbankChapterStats {
  const QbankChapterStats({
    required this.chapterId,
    required this.subjectId,
    required this.mcqCount,
    required this.cqCount,
  });

  final String chapterId;
  final String subjectId;
  final int mcqCount;
  final int cqCount;

  factory QbankChapterStats.fromJson(Map<String, dynamic> json) {
    return QbankChapterStats(
      chapterId: json['chapter_id'] as String,
      subjectId: json['subject_id'] as String,
      mcqCount: (json['mcq_count'] as num?)?.toInt() ?? 0,
      cqCount: (json['cq_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class QbankBookmarkItem {
  const QbankBookmarkItem({
    required this.id,
    required this.studentId,
    required this.questionType,
    required this.questionId,
    this.note,
    required this.createdAt,
  });

  final String id;
  final String studentId;
  final String questionType;
  final String questionId;
  final String? note;
  final DateTime createdAt;

  factory QbankBookmarkItem.fromJson(Map<String, dynamic> json) {
    return QbankBookmarkItem(
      id: json['id'] as String,
      studentId: json['student_id'] as String,
      questionType: json['question_type'] as String,
      questionId: json['question_id'] as String,
      note: json['note'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class QbankBookmarkView {
  const QbankBookmarkView({
    required this.bookmark,
    required this.previewText,
  });

  final QbankBookmarkItem bookmark;
  final String previewText;
}

class QbankPracticeSessionView {
  const QbankPracticeSessionView({
    required this.id,
    required this.chapterId,
    required this.questionType,
    required this.totalQuestions,
    required this.correctAnswers,
    required this.startedAt,
    required this.completedAt,
  });

  final String id;
  final String? chapterId;
  final String questionType;
  final int totalQuestions;
  final int correctAnswers;
  final DateTime startedAt;
  final DateTime? completedAt;

  factory QbankPracticeSessionView.fromJson(Map<String, dynamic> json) {
    return QbankPracticeSessionView(
      id: json['id'] as String,
      chapterId: json['chapter_id'] as String?,
      questionType: json['question_type'] as String? ?? 'mcq',
      totalQuestions: (json['total_questions'] as num?)?.toInt() ?? 0,
      correctAnswers: (json['correct_answers'] as num?)?.toInt() ?? 0,
      startedAt: DateTime.tryParse(json['started_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      completedAt: DateTime.tryParse(json['completed_at'] as String? ?? ''),
    );
  }
}

class QbankSearchResult {
  const QbankSearchResult({
    required this.questionType,
    required this.questionId,
    required this.chapterId,
    required this.subjectId,
    required this.sessionId,
    required this.previewText,
    required this.difficulty,
    this.source,
    this.boardYear,
    this.boardName,
  });

  final String questionType;
  final String questionId;
  final String chapterId;
  final String subjectId;
  final String sessionId;
  final String previewText;
  final String difficulty;
  final String? source;
  final int? boardYear;
  final String? boardName;

  factory QbankSearchResult.fromJson(Map<String, dynamic> json) {
    return QbankSearchResult(
      questionType: json['question_type'] as String? ?? 'mcq',
      questionId: json['question_id'] as String,
      chapterId: json['chapter_id'] as String,
      subjectId: json['subject_id'] as String,
      sessionId: json['session_id'] as String,
      previewText: json['preview_text'] as String? ?? '',
      difficulty: json['difficulty'] as String? ?? 'medium',
      source: json['source'] as String?,
      boardYear: (json['board_year'] as num?)?.toInt(),
      boardName: json['board_name'] as String?,
    );
  }
}

List<String> _asStringList(dynamic value) {
  if (value is List) {
    return value.map((e) => e.toString()).toList();
  }
  return const <String>[];
}
