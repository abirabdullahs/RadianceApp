import 'dart:typed_data';

import '../../../../core/services/pdf_service.dart';
import '../../../../shared/models/payment_ledger_model.dart';
import '../../../../shared/models/payment_model.dart';
import '../../courses/repositories/course_repository.dart';
import '../../students/repositories/student_repository.dart';

class PaymentVoucherPdfService {
  PaymentVoucherPdfService({
    required PdfService pdfService,
    StudentRepository? studentRepository,
    CourseRepository? courseRepository,
  })  : _pdfService = pdfService,
        _studentRepository = studentRepository ?? StudentRepository(),
        _courseRepository = courseRepository ?? CourseRepository();

  final PdfService _pdfService;
  final StudentRepository _studentRepository;
  final CourseRepository _courseRepository;

  Future<Uint8List> buildBulkVoucherPdf(List<PaymentLedgerModel> rows) async {
    if (rows.isEmpty) {
      throw StateError('No selected payments to print');
    }
    final sorted = [...rows]
      ..sort(
        (a, b) => (a.paidAt ?? DateTime.now()).compareTo(b.paidAt ?? DateTime.now()),
      );
    final studentIds = sorted.map((e) => e.studentId).toSet();
    if (studentIds.length != 1) {
      throw StateError('Bulk voucher print only supports one student at a time');
    }

    final student = await _studentRepository.getStudentById(sorted.first.studentId);
    final courseIds = sorted.map((e) => e.courseId).toSet().toList();
    final firstCourse = await _courseRepository.getCourseById(sorted.first.courseId);
    final course = courseIds.length == 1
        ? firstCourse
        : firstCourse.copyWith(name: 'Multiple Courses');

    var totalPaid = 0.0;
    var totalDue = 0.0;
    var totalDiscount = 0.0;
    for (final r in sorted) {
      totalPaid += r.amountPaid;
      totalDue += r.amountDue;
      totalDiscount += r.discountAmount;
    }

    final lineItems = sorted.asMap().entries.map((entry) {
      final idx = entry.key;
      final x = entry.value;
      final charge = (x.amountPaid - (x.amountDue - x.discountAmount));
      return PaymentVoucherLineItem(
        serial: idx + 1,
        serviceName: x.paymentTypeCode,
        month: x.forMonth,
        amount: x.amountPaid,
        discount: x.discountAmount,
        serviceCharge: charge <= 0 ? 0 : charge,
        voucherNo: x.voucherNo,
      );
    }).toList();

    final payment = PaymentModel(
      id: sorted.first.id,
      voucherNo: '',
      studentId: sorted.first.studentId,
      courseId: sorted.first.courseId,
      forMonth: sorted.first.forMonth ?? DateTime.now(),
      amount: double.parse(totalPaid.toStringAsFixed(2)),
      subtotal: double.parse(totalDue.toStringAsFixed(2)),
      discount: double.parse(totalDiscount.toStringAsFixed(2)),
      paymentMethod: PaymentMethod.fromJson(sorted.first.paymentMethod),
      status: PaymentStatus.paid,
      note: sorted.first.note,
      paidAt: sorted.last.paidAt,
      createdBy: sorted.first.createdBy,
    );

    return _pdfService.generateVoucherPdf(
      payment,
      student,
      course,
      serviceName: 'Multiple Services',
      lineItems: lineItems,
      hideMainVoucherNo: true,
    );
  }
}
