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
    this.voucherNo,
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
  final String? voucherNo;

  PaymentRecordRequest copyWith({
    String? studentId,
    String? courseId,
    String? paymentTypeId,
    String? paymentTypeCode,
    DateTime? forMonth,
    double? amountDue,
    double? amountPaid,
    double? discountAmount,
    double? fineAmount,
    String? paymentMethod,
    String? transactionRef,
    String? note,
    String? description,
    DateTime? paidAt,
    String? createdBy,
    DateTime? dueDate,
    String? voucherNo,
  }) {
    return PaymentRecordRequest(
      studentId: studentId ?? this.studentId,
      courseId: courseId ?? this.courseId,
      paymentTypeId: paymentTypeId ?? this.paymentTypeId,
      paymentTypeCode: paymentTypeCode ?? this.paymentTypeCode,
      forMonth: forMonth ?? this.forMonth,
      amountDue: amountDue ?? this.amountDue,
      amountPaid: amountPaid ?? this.amountPaid,
      discountAmount: discountAmount ?? this.discountAmount,
      fineAmount: fineAmount ?? this.fineAmount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      transactionRef: transactionRef ?? this.transactionRef,
      note: note ?? this.note,
      description: description ?? this.description,
      paidAt: paidAt ?? this.paidAt,
      createdBy: createdBy ?? this.createdBy,
      dueDate: dueDate ?? this.dueDate,
      voucherNo: voucherNo ?? this.voucherNo,
    );
  }
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
        voucherNo: request.voucherNo?.trim() ?? '',
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
    final dueDate = request.dueDate ?? prevSchedule?.dueDate ?? DateTime.now();
    final note = request.note ?? prevSchedule?.note;
    final PaymentScheduleModel schedule;
    if (prevSchedule == null) {
      schedule = await _repository.upsertPaymentSchedule(
        id: null,
        studentId: request.studentId,
        courseId: request.courseId,
        paymentTypeId: request.paymentTypeId,
        paymentTypeCode: request.paymentTypeCode,
        forMonth: request.forMonth,
        dueDate: dueDate,
        amount: baseAmount,
        status: nextStatus,
        paidAmount: nextPaid,
        note: note,
      );
    } else {
      schedule = await _repository.updatePaymentScheduleById(
        id: prevSchedule.id,
        dueDate: dueDate,
        amount: baseAmount,
        status: nextStatus,
        paidAmount: nextPaid,
        paymentTypeCode: request.paymentTypeCode,
        note: note,
      );
    }

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

  /// Replaces an existing recorded payment with a fully editable payload while
  /// keeping the same voucher number.
  Future<PaymentRecordResult> replaceRecordedPayment({
    required PaymentLedgerModel previous,
    required PaymentRecordRequest request,
  }) async {
    await deleteRecordedPayment(previous.id);
    return recordPayment(
      request.copyWith(
        voucherNo: previous.voucherNo,
        createdBy: previous.createdBy ?? request.createdBy,
      ),
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
    String sharedVoucherNo = '';
    for (final r in requests) {
      final candidate = r.voucherNo?.trim() ?? '';
      if (candidate.isNotEmpty) {
        sharedVoucherNo = candidate;
        break;
      }
    }
    for (final req in requests) {
      final effectiveReq = sharedVoucherNo.isEmpty
          ? req
          : req.copyWith(voucherNo: sharedVoucherNo);
      final res = await recordPayment(effectiveReq);
      if (sharedVoucherNo.isEmpty) {
        final generated = res.ledger.voucherNo.trim();
        if (generated.isNotEmpty) {
          sharedVoucherNo = generated;
        }
      }
      items.add(res);
      totalNetDue += res.netDue;
      totalPaid += effectiveReq.amountPaid;
      totalAdvanceAdded += res.newAdvanceAmount;
    }
    return MultiPaymentRecordResult(
      items: items,
      totalNetDue: _to2(totalNetDue),
      totalPaid: _to2(totalPaid),
      totalAdvanceAdded: _to2(totalAdvanceAdded),
    );
  }

  /// Updates a row in `payment_ledger` and reconciles `payment_schedule` + advance balance.
  Future<PaymentLedgerModel> updateRecordedPayment({
    required PaymentLedgerModel previous,
    required double amountDue,
    required double discountAmount,
    required double fineAmount,
    required double amountPaid,
    required String paymentMethod,
    required DateTime paidAt,
    String? note,
  }) async {
    final netDue = _to2(amountDue - discountAmount + fineAmount);
    final status = _deriveLedgerStatus(netDue: netDue, amountPaid: amountPaid);

    final updated = await _repository.updatePaymentLedgerRow(
      id: previous.id,
      amountDue: amountDue,
      discountAmount: discountAmount,
      fineAmount: fineAmount,
      amountPaid: amountPaid,
      paymentMethod: paymentMethod,
      status: status,
      note: note,
      paidAt: paidAt,
    );

    final schedule = await _repository.getScheduleTarget(
      studentId: previous.studentId,
      courseId: previous.courseId,
      paymentTypeId: previous.paymentTypeId,
      forMonth: previous.forMonth,
    );
    if (schedule != null) {
      final deltaPaid = _to2(amountPaid - previous.amountPaid);
      var newSchedulePaid = _to2(schedule.paidAmount + deltaPaid);
      if (newSchedulePaid < 0) newSchedulePaid = 0;
      final newStatus = _deriveScheduleStatus(
        baseAmount: schedule.amount,
        paidAmount: newSchedulePaid,
      );
      await _repository.updatePaymentScheduleById(
        id: schedule.id,
        dueDate: schedule.dueDate,
        amount: schedule.amount,
        status: newStatus,
        paidAmount: newSchedulePaid,
        paymentTypeCode: previous.paymentTypeCode,
        note: schedule.note,
      );
    }

    final oldNet = _to2(previous.amountDue - previous.discountAmount + previous.fineAmount);
    final oldExcess = _to2(previous.amountPaid - oldNet);
    final newExcess = _to2(amountPaid - netDue);
    final advanceDelta = _to2(newExcess - oldExcess);
    if (advanceDelta != 0) {
      final current = await _repository.getAdvanceBalance(
        studentId: previous.studentId,
        courseId: previous.courseId,
      );
      var next = _to2((current?.balance ?? 0) + advanceDelta);
      if (next < 0) next = 0;
      await _repository.upsertAdvanceBalance(
        studentId: previous.studentId,
        courseId: previous.courseId,
        balance: next,
      );
    }

    return updated;
  }

  /// Deletes a `payment_ledger` row and reverses schedule + advance effects from [recordPayment].
  Future<void> deleteRecordedPayment(String ledgerId) async {
    final ledger = await _repository.getPaymentLedgerById(ledgerId);
    if (ledger == null) return;

    final schedule = await _repository.getScheduleTarget(
      studentId: ledger.studentId,
      courseId: ledger.courseId,
      paymentTypeId: ledger.paymentTypeId,
      forMonth: ledger.forMonth,
    );

    final netDue = _to2(ledger.amountDue - ledger.discountAmount + ledger.fineAmount);
    final excess = _to2(ledger.amountPaid - netDue);

    if (schedule != null) {
      var newSchedulePaid = _to2(schedule.paidAmount - ledger.amountPaid);
      if (newSchedulePaid < 0) newSchedulePaid = 0;
      final newStatus = _deriveScheduleStatus(
        baseAmount: schedule.amount,
        paidAmount: newSchedulePaid,
      );
      await _repository.updatePaymentScheduleById(
        id: schedule.id,
        dueDate: schedule.dueDate,
        amount: schedule.amount,
        status: newStatus,
        paidAmount: newSchedulePaid,
        paymentTypeCode: ledger.paymentTypeCode,
        note: schedule.note,
      );
    }

    if (excess > 0) {
      final current = await _repository.getAdvanceBalance(
        studentId: ledger.studentId,
        courseId: ledger.courseId,
      );
      var next = _to2((current?.balance ?? 0) - excess);
      if (next < 0) next = 0;
      await _repository.upsertAdvanceBalance(
        studentId: ledger.studentId,
        courseId: ledger.courseId,
        balance: next,
      );
    }

    await _repository.deletePaymentLedgerById(ledgerId);
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
