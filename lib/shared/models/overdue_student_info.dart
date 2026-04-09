import 'payment_due_model.dart';
import 'user_model.dart';

/// One open due row with resolved student and course name (admin lists).
class OverdueStudentInfo {
  const OverdueStudentInfo({
    required this.student,
    required this.due,
    required this.courseName,
  });

  final UserModel student;
  final PaymentDueModel due;
  final String courseName;

  /// Convenience: amount still due for this row (`payment_dues.amount`).
  double get dueAmount => due.amount;
}
