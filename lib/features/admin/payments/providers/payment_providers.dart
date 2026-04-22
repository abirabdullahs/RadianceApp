import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/pdf_service.dart';
import '../../../../core/services/payment_due_edge_service.dart';
import '../../../../core/services/sms_service.dart';
import '../../students/repositories/student_repository.dart';
import '../repositories/payment_repository.dart';
import '../services/payment_service.dart';
import '../services/payment_voucher_pdf_service.dart';

part 'payment_providers.g.dart';

@Riverpod(keepAlive: true)
PaymentRepository paymentRepository(PaymentRepositoryRef ref) {
  return PaymentRepository();
}

@Riverpod(keepAlive: true)
PdfService pdfService(PdfServiceRef ref) {
  return PdfService();
}

@Riverpod(keepAlive: true)
SmsService smsService(SmsServiceRef ref) {
  return SmsService();
}

@Riverpod(keepAlive: true)
StudentRepository studentRepositoryForPayments(StudentRepositoryForPaymentsRef ref) {
  return StudentRepository();
}

final paymentServiceProvider = Provider<PaymentService>((ref) {
  return PaymentService(repository: ref.read(paymentRepositoryProvider));
});

final paymentVoucherPdfServiceProvider = Provider<PaymentVoucherPdfService>((ref) {
  return PaymentVoucherPdfService(
    pdfService: ref.read(pdfServiceProvider),
  );
});

final paymentDueEdgeServiceProvider = Provider<PaymentDueEdgeService>((ref) {
  return PaymentDueEdgeService();
});
