import '../../../../shared/models/advance_balance_model.dart';
import '../../../../shared/models/payment_ledger_model.dart';
import '../../../../shared/models/payment_schedule_model.dart';
import '../repositories/payment_repository.dart';

class PaymentRecordRequest {
  const PaymentRecordRequest({
    required this.studentId,
    required this.courseId,
    required this.paymentTypeId,
    required this.paymentTypeCode,
    this.forMonth,
    required this.amountDue,
    required this.amountPaid,
    this.discountAmount = 0,
    this.fineAmount = 0,
    required this.paymentMethod,
    this.transactionRef,
    this.note,
    this.description,
    this.paidAt,
    this.createdBy,
    this.dueDate,
  });

  final String studentId;
  final String courseId;
  final String paymentTypeId;
  final String paymentTypeCode;
  final DateTime? forMonth;
  final double amountDue;
  final double amountPaid;
  final double discountAmount;
  final double fineAmount;
  final String paymentMethod;
  final String? transactionRef;
  final String? note;
  final String? description;
  final DateTime? paidAt;
  final String? createdBy;
  final DateTime? dueDate;
}

class PaymentRecordResult {
  const PaymentRecordResult({
    required this.ledger,
    required this.schedule,
    this.advanceBalance,
    required this.netDue,
    required this.newAdvanceAmount,
  });

  final PaymentLedgerModel ledger;
  final PaymentScheduleModel schedule;
  final AdvanceBalanceModel? advanceBalance;
  final double netDue;
  final double newAdvanceAmount;
}

class MultiPaymentRecordResult {
  const MultiPaymentRecordResult({
    required this.items,
    required this.totalNetDue,
    required this.totalPaid,
    required this.totalAdvanceAdded,
  });

  final List<PaymentRecordResult> items;
  final double totalNetDue;
  final double totalPaid;
  final double totalAdvanceAdded;
}

class PaymentService {
  PaymentService({required PaymentRepository repository}) : _repository = repository;

  final PaymentRepository _repository;

  Future<PaymentRecordResult> recordPayment(PaymentRecordRequest request) async {
    final netDue = _to2(request.amountDue - request.discountAmount + request.fineAmount);
    if (request.amountDue < 0 || request.discountAmount < 0 || request.fineAmount < 0) {
      throw ArgumentError('Amounts cannot be negative');
    }
    if (request.amountPaid < 0) {
      throw ArgumentError('amountPaid cannot be negative');
    }
    if (netDue < 0) {
      throw ArgumentError('Net due cannot be negative after discount/fine');
    }

    final status = _deriveLedgerStatus(netDue: netDue, amountPaid: request.amountPaid);
    final ledger = await _repository.addPaymentLedger(
      PaymentLedgerModel(
        id: '',
        voucherNo: '',
        studentId: request.studentId,
        courseId: request.courseId,
        paymentTypeId: request.paymentTypeId,
        paymentTypeCode: request.paymentTypeCode,
        forMonth: request.forMonth == null
            ? null
            : DateTime(request.forMonth!.year, request.forMonth!.month, 1),
        amountDue: request.amountDue,
        amountPaid: request.amountPaid,
        discountAmount: request.discountAmount,
        fineAmount: request.fineAmount,
        paymentMethod: request.paymentMethod,
        transactionRef: request.transactionRef,
        status: status,
        note: request.note,
        description: request.description,
        paidAt: request.paidAt ?? DateTime.now(),
        createdBy: request.createdBy,
      ),
    );

    final prevSchedule = await _repository.getScheduleTarget(
      studentId: request.studentId,
      courseId: request.courseId,
      paymentTypeId: request.paymentTypeId,
      forMonth: request.forMonth,
    );
    final baseAmount = prevSchedule?.amount ?? request.amountDue;
    final nextPaid = _to2((prevSchedule?.paidAmount ?? 0) + request.amountPaid);
    final nextStatus = _deriveScheduleStatus(baseAmount: baseAmount, paidAmount: nextPaid);
    final schedule = await _repository.upsertPaymentSchedule(
      id: prevSchedule?.id,
      studentId: request.studentId,
      courseId: request.courseId,
      paymentTypeId: request.paymentTypeId,
      paymentTypeCode: request.paymentTypeCode,
      forMonth: request.forMonth,
      dueDate: request.dueDate ?? prevSchedule?.dueDate ?? DateTime.now(),
      amount: baseAmount,
      status: nextStatus,
      paidAmount: nextPaid,
      note: request.note ?? prevSchedule?.note,
    );

    final newAdvanceAmount = _to2(request.amountPaid - netDue);
    AdvanceBalanceModel? advanceBalance;
    if (newAdvanceAmount > 0) {
      final current = await _repository.getAdvanceBalance(
        studentId: request.studentId,
        courseId: request.courseId,
      );
      final nextBalance = _to2((current?.balance ?? 0) + newAdvanceAmount);
      advanceBalance = await _repository.upsertAdvanceBalance(
        studentId: request.studentId,
        courseId: request.courseId,
        balance: nextBalance,
      );
    }

    return PaymentRecordResult(
      ledger: ledger,
      schedule: schedule,
      advanceBalance: advanceBalance,
      netDue: netDue,
      newAdvanceAmount: newAdvanceAmount > 0 ? newAdvanceAmount : 0,
    );
  }

  Future<MultiPaymentRecordResult> recordMultiFeePayments(
    List<PaymentRecordRequest> requests,
  ) async {
    if (requests.isEmpty) {
      throw ArgumentError('At least one payment request is required');
    }
    final items = <PaymentRecordResult>[];
    var totalNetDue = 0.0;
    var totalPaid = 0.0;
    var totalAdvanceAdded = 0.0;
    for (final req in requests) {
      final res = await recordPayment(req);
      items.add(res);
      totalNetDue += res.netDue;
      totalPaid += req.amountPaid;
      totalAdvanceAdded += res.newAdvanceAmount;
    }
    return MultiPaymentRecordResult(
      items: items,
      totalNetDue: _to2(totalNetDue),
      totalPaid: _to2(totalPaid),
      totalAdvanceAdded: _to2(totalAdvanceAdded),
    );
  }
}

LedgerPaymentStatus _deriveLedgerStatus({
  required double netDue,
  required double amountPaid,
}) {
  final paid = _to2(amountPaid);
  final due = _to2(netDue);
  if (due == 0) return LedgerPaymentStatus.waived;
  if (paid == due) return LedgerPaymentStatus.paid;
  if (paid > due) return LedgerPaymentStatus.advance;
  return LedgerPaymentStatus.partial;
}

PaymentScheduleStatus _deriveScheduleStatus({
  required double baseAmount,
  required double paidAmount,
}) {
  final due = _to2(baseAmount);
  final paid = _to2(paidAmount);
  if (due == 0) return PaymentScheduleStatus.waived;
  if (paid >= due) return PaymentScheduleStatus.paid;
  if (paid > 0) return PaymentScheduleStatus.partial;
  return PaymentScheduleStatus.pending;
}

double _to2(double n) => double.parse(n.toStringAsFixed(2));
