/// Matches `questions` table.
class QuestionModel {
  const QuestionModel({
    required this.id,
    required this.examId,
    required this.questionText,
    this.imageUrl,
    required this.optionA,
    required this.optionB,
    required this.optionC,
    required this.optionD,
    required this.correctOption,
    this.marks = 1,
    this.explanation,
    this.displayOrder = 0,
  });

  final String id;
  final String examId;
  final String questionText;
  final String? imageUrl;
  final String optionA;
  final String optionB;
  final String optionC;
  final String optionD;
  final String correctOption;
  final double marks;
  final String? explanation;
  final int displayOrder;

  factory QuestionModel.fromJson(Map<String, dynamic> json) {
    return QuestionModel(
      id: json['id'] as String,
      examId: json['exam_id'] as String,
      questionText: json['question_text'] as String,
      imageUrl: json['image_url'] as String?,
      optionA: json['option_a'] as String,
      optionB: json['option_b'] as String,
      optionC: json['option_c'] as String,
      optionD: json['option_d'] as String,
      correctOption: (json['correct_option'] as String? ?? 'A').trim(),
      marks: _parseDouble(json['marks']) ?? 1,
      explanation: json['explanation'] as String?,
      displayOrder: (json['display_order'] as num?)?.toInt() ?? 0,
    );
  }
}

double? _parseDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}
