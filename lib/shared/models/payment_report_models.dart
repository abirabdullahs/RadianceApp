class MonthlyCollectionBreakdownRow {
  const MonthlyCollectionBreakdownRow({
    required this.paymentTypeCode,
    required this.collectedAmount,
    required this.transactionsCount,
    required this.studentCount,
  });

  final String paymentTypeCode;
  final double collectedAmount;
  final int transactionsCount;
  final int studentCount;
}

class MonthlyCollectionReport {
  const MonthlyCollectionReport({
    required this.month,
    required this.totalCollected,
    required this.totalTransactions,
    required this.breakdown,
  });

  final DateTime month;
  final double totalCollected;
  final int totalTransactions;
  final List<MonthlyCollectionBreakdownRow> breakdown;
}

class DueReportRow {
  const DueReportRow({
    required this.studentId,
    required this.studentName,
    required this.courseId,
    required this.courseName,
    required this.paymentTypeCode,
    required this.forMonth,
    required this.status,
    required this.amount,
    required this.paidAmount,
    required this.remainingAmount,
    required this.dueDate,
    required this.overdueDays,
  });

  final String studentId;
  final String studentName;
  final String courseId;
  final String courseName;
  final String paymentTypeCode;
  final DateTime? forMonth;
  final String status;
  final double amount;
  final double paidAmount;
  final double remainingAmount;
  final DateTime dueDate;
  final int overdueDays;
}

class StudentAnnualReport {
  const StudentAnnualReport({
    required this.studentId,
    required this.year,
    required this.totalDue,
    required this.totalPaid,
    required this.totalRemaining,
    required this.rows,
  });

  final String studentId;
  final int year;
  final double totalDue;
  final double totalPaid;
  final double totalRemaining;
  final List<DueReportRow> rows;
}
