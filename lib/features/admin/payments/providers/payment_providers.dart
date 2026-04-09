import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/services/pdf_service.dart';
import '../../../../core/services/sms_service.dart';
import '../../students/repositories/student_repository.dart';
import '../repositories/payment_repository.dart';

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
