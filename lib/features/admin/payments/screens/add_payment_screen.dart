import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../app/theme.dart';
import '../../widgets/admin_responsive_scaffold.dart';
import '../../../../core/student_id_display.dart';
import '../../../../core/supabase_client.dart';
import '../../../../shared/models/course_model.dart';
import '../../../../shared/models/discount_rule_model.dart';
import '../../../../shared/models/enrollment_model.dart';
import '../../../../shared/models/payment_ledger_model.dart';
import '../../../../shared/models/payment_model.dart';
import '../../../../shared/models/payment_settings_model.dart';
import '../../../../shared/models/payment_type_model.dart';
import '../../../../shared/models/student_discount_model.dart';
import '../../../../shared/models/user_model.dart';
import '../../courses/providers/courses_provider.dart';
import '../providers/payment_providers.dart';
import '../services/payment_service.dart';

/// Admin form: record a payment, PDF voucher, optional SMS log, share/print.
/// [editingPaymentId] set → load existing row (edit).
class AddPaymentScreen extends ConsumerStatefulWidget {
  const AddPaymentScreen({
    super.key,
    this.editingPaymentId,
    this.initialStudentId,
  });

  final String? editingPaymentId;
  final String? initialStudentId;

  @override
  ConsumerState<AddPaymentScreen> createState() => _AddPaymentScreenState();
}

class _AddPaymentScreenState extends ConsumerState<AddPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _studentQuery = TextEditingController();
  final _subtotal = TextEditingController();
  final _discount = TextEditingController(text: '0');
  final _paidAmount = TextEditingController();
  final _note = TextEditingController();
  final _monthDisplay = TextEditingController();
  final _paidDateDisplay = TextEditingController();
  final _transactionRef = TextEditingController();

  Timer? _searchDebounce;
  List<UserModel> _studentSuggestions = [];
  UserModel? _student;

  List<CourseModel> _courseOptions = [];
  String? _selectedCourseId;

  List<PaymentTypeModel> _paymentTypes = [];
  PaymentSettingsModel _paymentSettings = const PaymentSettingsModel();
  final List<_FeeItemState> _feeItems = [];

  PaymentModel? _existingPayment;
  /// Set when editing a row from `payment_ledger` (current payment flow).
  PaymentLedgerModel? _existingLedger;
  bool _loadingEdit = false;

  DateTime _billingMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _paymentDate = DateTime.now();

  PaymentMethod _paymentMethod = PaymentMethod.cash;

  bool _submitting = false;

  CourseModel? get _course {
    final id = _selectedCourseId;
    if (id == null) return null;
    for (final c in _courseOptions) {
      if (c.id == id) return c;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _syncMonthDisplay();
    _syncPaidDateDisplay();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadPaymentSettings();
      await _loadPaymentTypes();
      if (widget.editingPaymentId != null) {
        await _loadPaymentForEdit(widget.editingPaymentId!);
      } else if (widget.initialStudentId != null &&
          widget.initialStudentId!.isNotEmpty) {
        await _prefillInitialStudent(widget.initialStudentId!);
      }
    });
  }

  Future<void> _prefillInitialStudent(String studentId) async {
    try {
      final repo = ref.read(studentRepositoryForPaymentsProvider);
      final uid = await repo.resolveStudentUserId(studentId) ?? studentId;
      final student = await repo.getStudentById(uid);
      if (!mounted) return;
      await _selectStudent(student);
    } catch (_) {
      // Ignore prefill failures; manual student search remains available.
    }
  }

  Future<void> _loadPaymentSettings() async {
    try {
      final settings = await ref.read(paymentRepositoryProvider).getPaymentSettings();
      if (!mounted) return;
      setState(() {
        _paymentSettings = settings;
        final allowed = _paymentSettings.allowedMethods();
        if (!allowed.contains(_paymentMethod)) {
          _paymentMethod = allowed.first;
        }
      });
    } catch (_) {}
  }

  Future<void> _loadPaymentTypes() async {
    try {
      final list = await ref.read(paymentRepositoryProvider).listPaymentTypes();
      if (!mounted) return;
      setState(() {
        _paymentTypes = list;
        if (_feeItems.isEmpty &&
            _existingLedger == null &&
            _existingPayment == null &&
            _paymentTypes.isNotEmpty) {
          final firstType = _paymentTypes.first;
          final defaultAmt = _paymentSettings.defaultAmountForCode(
            firstType.code,
            fallback: firstType.defaultAmount ?? 0,
          );
          _feeItems.add(
            _FeeItemState(
              paymentTypeId: firstType.id,
              amountDueCtrl: TextEditingController(
                text: defaultAmt.toStringAsFixed(2),
              ),
              amountPaidCtrl: TextEditingController(
                text: defaultAmt.toStringAsFixed(2),
              ),
            ),
          );
        }
      });
    } catch (_) {
      if (mounted) setState(() => _paymentTypes = []);
    }
  }

  Future<void> _loadPaymentForEdit(String id) async {
    setState(() => _loadingEdit = true);
    try {
      final ledger = await ref.read(paymentRepositoryProvider).getPaymentLedgerById(id);
      if (!mounted) return;
      if (ledger != null) {
        final studentRepo = ref.read(studentRepositoryForPaymentsProvider);
        final courseRepo = ref.read(courseRepositoryProvider);
        final student = await studentRepo.getStudentById(ledger.studentId);
        final enrollments = await studentRepo.getStudentEnrollments(student.id);
        final active = enrollments.where((e) => e.status == EnrollmentStatus.active).toList();
        final courses = <CourseModel>[];
        for (final e in active) {
          try {
            courses.add(await courseRepo.getCourseById(e.courseId));
          } catch (_) {}
        }
        if (!courses.any((c) => c.id == ledger.courseId)) {
          try {
            courses.add(await courseRepo.getCourseById(ledger.courseId));
          } catch (_) {}
        }
        if (!mounted) return;
        final paid = ledger.paidAt ?? DateTime.now();
        final billMonth = ledger.forMonth ?? DateTime(paid.year, paid.month, 1);
        setState(() {
          _existingLedger = ledger;
          _existingPayment = null;
          _student = student;
          _studentQuery.text = student.fullNameBn;
          _courseOptions = courses;
          _selectedCourseId = ledger.courseId;
          _billingMonth = billMonth;
          _syncMonthDisplay();
          _paymentDate = paid;
          _syncPaidDateDisplay();
          _subtotal.text = ledger.amountDue.toStringAsFixed(2);
          _discount.text = ledger.discountAmount.toStringAsFixed(2);
        _paidAmount.text = ledger.amountPaid.toStringAsFixed(2);
          _note.text = ledger.note ?? '';
          _paymentMethod = PaymentMethod.fromJson(ledger.paymentMethod) ?? PaymentMethod.cash;
          _loadingEdit = false;
        });
        return;
      }

      final p = await ref.read(paymentRepositoryProvider).getPaymentById(id);
      if (!mounted) return;
      if (p == null) {
        setState(() => _loadingEdit = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('পেমেন্ট পাওয়া যায়নি', style: GoogleFonts.hindSiliguri())),
        );
        return;
      }
      final studentRepo = ref.read(studentRepositoryForPaymentsProvider);
      final courseRepo = ref.read(courseRepositoryProvider);
      final student = await studentRepo.getStudentById(p.studentId);
      final enrollments = await studentRepo.getStudentEnrollments(student.id);
      final active = enrollments.where((e) => e.status == EnrollmentStatus.active).toList();
      final courses = <CourseModel>[];
      for (final e in active) {
        try {
          courses.add(await courseRepo.getCourseById(e.courseId));
        } catch (_) {}
      }
      if (!courses.any((c) => c.id == p.courseId)) {
        try {
          courses.add(await courseRepo.getCourseById(p.courseId));
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _existingLedger = null;
        _existingPayment = p;
        _student = student;
        _studentQuery.text = student.fullNameBn;
        _courseOptions = courses;
        _selectedCourseId = p.courseId;
        _billingMonth = p.forMonth;
        _syncMonthDisplay();
        _paymentDate = p.paidAt ?? DateTime.now();
        _syncPaidDateDisplay();
        _subtotal.text = p.subtotal.toStringAsFixed(2);
        _discount.text = p.discount.toStringAsFixed(2);
        _paidAmount.text = p.amount.toStringAsFixed(2);
        _note.text = p.note ?? '';
        _paymentMethod = p.paymentMethod ?? PaymentMethod.cash;
        _loadingEdit = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loadingEdit = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e', style: GoogleFonts.hindSiliguri())),
        );
      }
    }
  }

  void _addFeeItem() {
    if (_paymentTypes.isEmpty) return;
    final firstType = _paymentTypes.first;
    final defaultAmt = _paymentSettings.defaultAmountForCode(
      firstType.code,
      fallback: firstType.defaultAmount ?? 0,
    );
    setState(() {
      _feeItems.add(
        _FeeItemState(
          paymentTypeId: firstType.id,
          amountDueCtrl: TextEditingController(
            text: defaultAmt.toStringAsFixed(2),
          ),
          amountPaidCtrl: TextEditingController(
            text: defaultAmt.toStringAsFixed(2),
          ),
        ),
      );
    });
    _autoApplyStudentDiscounts();
  }

  void _removeFeeItem(int index) {
    if (_feeItems.length <= 1) return;
    final item = _feeItems.removeAt(index);
    item.dispose();
    setState(() {});
  }

  PaymentTypeModel? _typeById(String id) {
    for (final t in _paymentTypes) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// Pushes the selected course's fee (e.g. `monthlyFee`) into fee items that
  /// match monthly / tuition payment types. Called from the course selector
  /// and when a single active enrollment auto-picks a course.
  void _applyCourseFeeToItems(CourseModel course) {
    if (_feeItems.isEmpty) return;
    final amt = course.monthlyFee.toStringAsFixed(2);
    for (final item in _feeItems) {
      final t = _typeById(item.paymentTypeId);
      if (t == null) continue;
      final code = t.code.toLowerCase();
      if (code == 'monthly' || code == 'tuition' || code == 'monthly_fee') {
        item.amountDueCtrl.text = amt;
        item.amountPaidCtrl.text = amt;
      }
    }
  }

  double _parseNum(String raw) => double.tryParse(raw.trim().replaceAll(',', '')) ?? 0;

  double _multiGrandTotal() {
    var sum = 0.0;
    for (final item in _feeItems) {
      final due = _parseNum(item.amountDueCtrl.text);
      final dis = _parseNum(item.discountCtrl.text);
      final fine = _parseNum(item.fineCtrl.text);
      sum += (due - dis + fine);
    }
    return double.parse(sum.toStringAsFixed(2));
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _studentQuery.dispose();
    _subtotal.dispose();
    _discount.dispose();
    _paidAmount.dispose();
    _note.dispose();
    _monthDisplay.dispose();
    _paidDateDisplay.dispose();
    _transactionRef.dispose();
    for (final item in _feeItems) {
      item.dispose();
    }
    super.dispose();
  }

  void _syncMonthDisplay() {
    final d = _billingMonth;
    _monthDisplay.text =
        '${d.year}-${d.month.toString().padLeft(2, '0')}';
  }

  void _syncPaidDateDisplay() {
    final d = _paymentDate;
    _paidDateDisplay.text =
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  void _scheduleStudentSearch(String query) {
    _searchDebounce?.cancel();
    final q = query.trim();
    final digitsOnly = RegExp(r'^\d+$').hasMatch(q);
    if (q.isEmpty) {
      setState(() => _studentSuggestions = []);
      return;
    }
    if (digitsOnly) {
      if (q.length != 9) {
        setState(() => _studentSuggestions = []);
        return;
      }
    } else if (q.length < 2) {
      setState(() => _studentSuggestions = []);
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 320), () async {
      final repo = ref.read(studentRepositoryForPaymentsProvider);
      try {
        final list = await repo.getStudents(searchQuery: q);
        if (!mounted) return;
        setState(() => _studentSuggestions = list);
      } catch (_) {
        if (!mounted) return;
        setState(() => _studentSuggestions = []);
      }
    });
  }

  Future<void> _selectStudent(UserModel u) async {
    _searchDebounce?.cancel();
    setState(() {
      _student = u;
      _studentSuggestions = [];
      _studentQuery.text = u.fullNameBn;
      _selectedCourseId = null;
      _courseOptions = [];
      _subtotal.clear();
      _discount.text = '0';
    });

    final studentRepo = ref.read(studentRepositoryForPaymentsProvider);
    final courseRepo = ref.read(courseRepositoryProvider);
    final enrollments = await studentRepo.getStudentEnrollments(u.id);
    final active = enrollments
        .where((e) => e.status == EnrollmentStatus.active)
        .toList();

    if (!mounted) return;

    if (active.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'এই শিক্ষার্থীর কোনো সক্রিয় ভর্তি নেই।',
              style: GoogleFonts.hindSiliguri(),
            ),
          ),
        );
      }
      return;
    }

    final courses = <CourseModel>[];
    for (final e in active) {
      try {
        final c = await courseRepo.getCourseById(e.courseId);
        courses.add(c);
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {
      _courseOptions = courses;
      if (courses.length == 1) {
        _selectedCourseId = courses.first.id;
        _subtotal.text = courses.first.monthlyFee.toStringAsFixed(0);
        _applyCourseFeeToItems(courses.first);
      } else {
        _selectedCourseId = null;
      }
    });
    await _autoApplyStudentDiscounts();
  }

  bool _appliesToMatches(String appliesTo, PaymentTypeModel type) {
    final a = appliesTo.trim().toLowerCase();
    if (a.isEmpty) return false;
    if (a == type.code.toLowerCase()) return true;
    if (a == 'monthly' && type.code.toLowerCase() == 'monthly') return true;
    return false;
  }

  double _resolveDiscountAmount({
    required _FeeItemState item,
    required PaymentTypeModel type,
    required List<StudentDiscountModel> studentDiscounts,
    required Map<String, DiscountRuleModel> rulesById,
  }) {
    final due = _parseNum(item.amountDueCtrl.text);
    for (final sd in studentDiscounts) {
      if (!_appliesToMatches(sd.appliesTo, type)) continue;
      if (sd.customAmount != null) {
        return sd.customAmount! > due ? due : sd.customAmount!;
      }
      final rid = sd.discountRuleId;
      if (rid == null) continue;
      final rule = rulesById[rid];
      if (rule == null) continue;
      if (rule.discountType == DiscountType.fixed) {
        return rule.discountValue > due ? due : rule.discountValue;
      }
      final pct = rule.discountValue / 100;
      final calc = due * pct;
      return calc > due ? due : calc;
    }
    return 0;
  }

  Future<void> _autoApplyStudentDiscounts() async {
    if (_student == null || _course == null || _feeItems.isEmpty) return;
    try {
      final repo = ref.read(paymentRepositoryProvider);
      final sds = await repo.getStudentDiscounts(
        studentId: _student!.id,
        courseId: _course!.id,
        onlyActive: true,
      );
      if (sds.isEmpty) return;
      final rules = await repo.listDiscountRules(activeOnly: true);
      final rulesById = <String, DiscountRuleModel>{
        for (final r in rules) r.id: r,
      };
      if (!mounted) return;
      setState(() {
        for (final item in _feeItems) {
          final type = _typeById(item.paymentTypeId);
          if (type == null) continue;
          final current = _parseNum(item.discountCtrl.text);
          if (current > 0) continue;
          final d = _resolveDiscountAmount(
            item: item,
            type: type,
            studentDiscounts: sds,
            rulesById: rulesById,
          );
          if (d > 0) {
            item.discountCtrl.text = d.toStringAsFixed(2);
          }
        }
      });
    } catch (_) {}
  }

  Future<void> _pickBillingMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _billingMonth,
      firstDate: DateTime(2020, 1),
      lastDate: DateTime(2035, 12),
      helpText: 'বিলিং মাস নির্বাচন করুন',
      initialEntryMode: DatePickerEntryMode.calendar,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _billingMonth = DateTime(picked.year, picked.month, 1);
      _syncMonthDisplay();
    });
  }

  Future<void> _pickPaidDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(_paymentDate.year, _paymentDate.month, _paymentDate.day),
      firstDate: DateTime(2020, 1),
      lastDate: DateTime(now.year + 1, 12, 31),
      helpText: 'পেমেন্টের তারিখ',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _paymentDate = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _paymentDate.hour,
        _paymentDate.minute,
      );
      _syncPaidDateDisplay();
    });
  }

  String? _validateSubtotal(String? v) {
    if (v == null || v.trim().isEmpty) return 'মোট পরিমাণ লিখুন';
    final n = double.tryParse(v.trim().replaceAll(',', ''));
    if (n == null || n <= 0) return 'সঠিক পরিমাণ দিন';
    return null;
  }

  double _parseGrandTotal() {
    final s = double.tryParse(_subtotal.text.trim().replaceAll(',', '')) ?? 0;
    final d = double.tryParse(_discount.text.trim().replaceAll(',', '')) ?? 0;
    return double.parse((s - d).toStringAsFixed(2));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_student == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('শিক্ষার্থী নির্বাচন করুন', style: GoogleFonts.hindSiliguri())),
      );
      return;
    }
    if (_course == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('কোর্স নির্বাচন করুন', style: GoogleFonts.hindSiliguri())),
      );
      return;
    }
    final isEdit = _existingLedger != null || _existingPayment != null;

    setState(() => _submitting = true);
    try {
      PaymentModel? saved;
      double notifyAmount = 0;
      String successVoucher = '';
      if (_existingLedger != null) {
        final subtotal = _parseNum(_subtotal.text);
        final discount = _parseNum(_discount.text);
        final paidAmount = _parseNum(_paidAmount.text);
        if (paidAmount <= 0) {
          throw Exception('পরিশোধিত পরিমাণ ০ এর উপরে হতে হবে');
        }
        final updated = await ref.read(paymentServiceProvider).updateRecordedPayment(
              previous: _existingLedger!,
              amountDue: subtotal,
              discountAmount: discount,
              fineAmount: _existingLedger!.fineAmount,
              amountPaid: paidAmount,
              paymentMethod: _paymentMethod.toJson(),
              paidAt: _paymentDate,
              note: _note.text.trim().isEmpty ? null : _note.text.trim(),
            );
        notifyAmount = paidAmount;
        successVoucher = updated.voucherNo;
        saved = PaymentModel(
          id: updated.id,
          voucherNo: updated.voucherNo,
          studentId: updated.studentId,
          courseId: updated.courseId,
          forMonth: updated.forMonth ?? _billingMonth,
          amount: updated.amountPaid,
          subtotal: updated.amountDue,
          discount: updated.discountAmount,
          paymentMethod: PaymentMethod.fromJson(updated.paymentMethod),
          status: updated.status == LedgerPaymentStatus.partial
              ? PaymentStatus.partial
              : PaymentStatus.paid,
          note: updated.note,
          paidAt: updated.paidAt,
          createdBy: updated.createdBy,
        );
      } else if (_existingPayment != null) {
        final subtotal = _parseNum(_subtotal.text);
        final discount = _parseNum(_discount.text);
        final paidAmount = _parseNum(_paidAmount.text);
        if (paidAmount <= 0) {
          throw Exception('পরিশোধিত পরিমাণ ০ এর উপরে হতে হবে');
        }
        saved = await ref.read(paymentRepositoryProvider).updatePayment(
              _existingPayment!.copyWith(
                amount: paidAmount,
                subtotal: subtotal,
                discount: discount,
                paymentMethod: _paymentMethod,
                note: _note.text.trim().isEmpty ? null : _note.text.trim(),
                paidAt: _paymentDate,
              ),
            );
        notifyAmount = paidAmount;
        successVoucher = saved.voucherNo;
      } else {
        if (_feeItems.isEmpty) {
          throw Exception('কমপক্ষে ১টি ফি যোগ করুন');
        }
        final reqs = <PaymentRecordRequest>[];
        for (final item in _feeItems) {
          final t = _typeById(item.paymentTypeId);
          if (t == null) {
            throw Exception('ফি ধরন নির্বাচন করুন');
          }
          final due = _parseNum(item.amountDueCtrl.text);
          final paid = _parseNum(item.amountPaidCtrl.text);
          final discount = _parseNum(item.discountCtrl.text);
          final fine = _parseNum(item.fineCtrl.text);
          if (due <= 0) {
            throw Exception('নির্ধারিত পরিমাণ ০ এর বেশি হতে হবে');
          }
          if (paid < 0) {
            throw Exception('পরিশোধিত পরিমাণ সঠিক নয়');
          }
          if (discount < 0 || discount > due) {
            throw Exception('ছাড় সঠিক নয়');
          }
          reqs.add(
            PaymentRecordRequest(
              studentId: _student!.id,
              courseId: _course!.id,
              paymentTypeId: t.id,
              paymentTypeCode: t.code,
              forMonth: t.isRecurring ? _billingMonth : null,
              amountDue: due,
              amountPaid: paid,
              discountAmount: discount,
              fineAmount: fine,
              paymentMethod: _paymentMethod.toJson(),
              transactionRef: _transactionRef.text.trim().isEmpty ? null : _transactionRef.text.trim(),
              note: _note.text.trim().isEmpty ? null : _note.text.trim(),
              description: item.descriptionCtrl.text.trim().isEmpty ? null : item.descriptionCtrl.text.trim(),
              paidAt: _paymentDate,
              createdBy: supabaseClient.auth.currentUser?.id,
              dueDate: DateTime(
                _billingMonth.year,
                _billingMonth.month,
                _paymentSettings.dueDayOfMonth,
              ),
            ),
          );
        }
        final multi = await ref.read(paymentServiceProvider).recordMultiFeePayments(reqs);
        if (multi.items.isEmpty) {
          throw Exception('লেনদেন তৈরি হয়নি');
        }
        notifyAmount = multi.totalPaid;
        successVoucher = multi.items.first.ledger.voucherNo;
        final first = multi.items.first;
        final firstType = _typeById(first.ledger.paymentTypeId);
        saved = PaymentModel(
          id: first.ledger.id,
          voucherNo: first.ledger.voucherNo,
          studentId: first.ledger.studentId,
          courseId: first.ledger.courseId,
          forMonth: _billingMonth,
          amount: first.ledger.amountPaid,
          subtotal: first.ledger.amountDue,
          discount: first.ledger.discountAmount,
          paymentMethod: PaymentMethod.fromJson(first.ledger.paymentMethod),
          status: first.ledger.status == LedgerPaymentStatus.partial ? PaymentStatus.partial : PaymentStatus.paid,
          note: first.ledger.note,
          paidAt: first.ledger.paidAt,
          createdBy: first.ledger.createdBy,
        );

        final pdfBytes = await ref.read(pdfServiceProvider).generateVoucherPdf(
              saved,
              _student!,
              _course!,
              serviceName: firstType?.nameBn ?? firstType?.name ?? 'Payment',
            );
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: Text('পেমেন্ট সফল', style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('মোট আইটেম: ${multi.items.length}', style: GoogleFonts.hindSiliguri()),
                const SizedBox(height: 8),
                SelectableText('প্রথম ভাউচার: $successVoucher', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  await SharePlus.instance.share(
                    ShareParams(
                      files: [
                        XFile.fromData(
                          pdfBytes,
                          mimeType: 'application/pdf',
                          name: 'RCC-$successVoucher.pdf',
                        ),
                      ],
                    ),
                  );
                },
                child: Text('শেয়ার করুন', style: GoogleFonts.hindSiliguri()),
              ),
              FilledButton(
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  await Printing.layoutPdf(
                    onLayout: (_) async => pdfBytes,
                    name: 'RCC-$successVoucher.pdf',
                  );
                },
                child: Text('ভাউচার দেখুন', style: GoogleFonts.hindSiliguri()),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text('ঠিক আছে', style: GoogleFonts.hindSiliguri()),
              ),
            ],
          ),
        );
      }

      if (!isEdit) {
        try {
          await ref.read(smsServiceProvider).notifyPaymentRecorded(
                phone: _student!.phone,
                voucherNo: successVoucher,
                amountLabel: '৳${notifyAmount.toStringAsFixed(0)}',
                courseName: _course!.name,
                studentName: _student!.fullNameBn,
              );
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'SMS লগ সংরক্ষণ করা যায়নি।',
                  style: GoogleFonts.hindSiliguri(),
                ),
              ),
            );
          }
        }
      }

      if (!mounted) return;
      setState(() => _submitting = false);

      if (isEdit) {
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) {
            return AlertDialog(
              title: Text(
                'সফল',
                style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'পেমেন্ট হালনাগাদ হয়েছে ✅',
                    style: GoogleFonts.hindSiliguri(),
                  ),
                  const SizedBox(height: 12),
                  SelectableText(
                    'ভাউচার নং: ${saved!.voucherNo}',
                    style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text('ঠিক আছে', style: GoogleFonts.hindSiliguri()),
                ),
              ],
            );
          },
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    }
  }

  InputDecoration _decoration(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.cardRadius)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AdminResponsiveScaffold(
      title: Text(
        (_existingLedger != null || _existingPayment != null)
            ? 'পেমেন্ট সম্পাদনা'
            : 'নতুন পেমেন্ট',
        style: GoogleFonts.hindSiliguri(),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'শিক্ষার্থী',
                    style: GoogleFonts.hindSiliguri(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _studentQuery,
                    enabled: !_submitting &&
                        !_loadingEdit &&
                        _existingLedger == null &&
                        _existingPayment == null,
                    decoration: _decoration('নাম, ফোন বা শেষ ৯ ডিজিট').copyWith(
                      hintText: 'নাম / ফোন (২+ অক্ষর) অথবা ৯ ডিজিট আইডি',
                      suffixIcon: _student != null
                          ? Icon(Icons.check_circle, color: theme.colorScheme.primary)
                          : null,
                    ),
                    style: GoogleFonts.hindSiliguri(),
                    onChanged: _scheduleStudentSearch,
                  ),
                  if (_studentSuggestions.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Material(
                        elevation: 3,
                        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 220),
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: _studentSuggestions.length,
                            separatorBuilder: (_, _) => const Divider(height: 1),
                            itemBuilder: (context, i) {
                              final u = _studentSuggestions[i];
                              return ListTile(
                                title: Text(
                                  u.fullNameBn,
                                  style: GoogleFonts.hindSiliguri(),
                                ),
                                subtitle: Text(
                                  '${displayStudentIdForUser(u)} · ${u.phone}',
                                  style: GoogleFonts.nunito(fontSize: 12),
                                ),
                                onTap: _submitting ? null : () => _selectStudent(u),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  Text(
                    'কোর্স',
                    style: GoogleFonts.hindSiliguri(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_courseOptions.isEmpty)
                    Text(
                      _student == null
                          ? 'প্রথমে শিক্ষার্থী নির্বাচন করুন'
                          : 'কোনো সক্রিয় কোর্স নেই',
                      style: GoogleFonts.hindSiliguri(color: theme.hintColor),
                    )
                  else if (_courseOptions.length == 1)
                    InputDecorator(
                      decoration: _decoration('কোর্স'),
                      child: Text(
                        _courseOptions.first.name,
                        style: GoogleFonts.hindSiliguri(),
                      ),
                    )
                  else
                    DropdownButtonFormField<CourseModel>(
                      // ignore: deprecated_member_use — controlled selection via setState
                      value: _course,
                      decoration: _decoration('কোর্স'),
                      items: _courseOptions
                          .map(
                            (c) => DropdownMenuItem(
                              value: c,
                              child: Text(c.name, style: GoogleFonts.hindSiliguri()),
                            ),
                          )
                          .toList(),
                      onChanged: (_submitting ||
                              _loadingEdit ||
                              _existingLedger != null ||
                              _existingPayment != null)
                          ? null
                          : (c) {
                              setState(() {
                                _selectedCourseId = c?.id;
                                if (c != null) {
                                  _subtotal.text =
                                      c.monthlyFee.toStringAsFixed(0);
                                  _applyCourseFeeToItems(c);
                                }
                              });
                              _autoApplyStudentDiscounts();
                            },
                    ),
                  const SizedBox(height: 16),
                  if (_existingLedger == null && _existingPayment == null) ...[
                    Text(
                      'ফি আইটেম (একসাথে একাধিক)',
                      style: GoogleFonts.hindSiliguri(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_paymentTypes.isEmpty)
                      Text('ফি ধরন লোড হচ্ছে...', style: GoogleFonts.hindSiliguri(color: theme.hintColor))
                    else
                      ...List.generate(_feeItems.length, (i) {
                        final item = _feeItems[i];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: DropdownButtonFormField<String>(
                                        value: item.paymentTypeId,
                                        decoration: _decoration('ফি ধরন'),
                                        items: _paymentTypes
                                            .map(
                                              (t) => DropdownMenuItem<String>(
                                                value: t.id,
                                                child: Text(t.nameBn, style: GoogleFonts.hindSiliguri()),
                                              ),
                                            )
                                            .toList(),
                                        onChanged: _submitting
                                            ? null
                                            : (v) {
                                                setState(() {
                                                  item.paymentTypeId = v ?? item.paymentTypeId;
                                                  final t = _typeById(item.paymentTypeId);
                                                  final c = _course;
                                                  if (t != null) {
                                                    final code = t.code.toLowerCase();
                                                    if ((code == 'monthly' ||
                                                            code == 'tuition' ||
                                                            code == 'monthly_fee') &&
                                                        c != null) {
                                                      final amt = c.monthlyFee
                                                          .toStringAsFixed(2);
                                                      item.amountDueCtrl.text = amt;
                                                      item.amountPaidCtrl.text = amt;
                                                    } else {
                                                      final defAmt = _paymentSettings
                                                          .defaultAmountForCode(
                                                        t.code,
                                                        fallback:
                                                            t.defaultAmount ?? 0,
                                                      );
                                                      if (defAmt > 0) {
                                                        item.amountDueCtrl.text =
                                                            defAmt.toStringAsFixed(2);
                                                        item.amountPaidCtrl.text =
                                                            defAmt.toStringAsFixed(2);
                                                      }
                                                    }
                                                  }
                                                });
                                                _autoApplyStudentDiscounts();
                                              },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      onPressed: _submitting ? null : () => _removeFeeItem(i),
                                      icon: const Icon(Icons.delete_outline),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: item.descriptionCtrl,
                                  decoration: _decoration('বিবরণ (ঐচ্ছিক)'),
                                  style: GoogleFonts.hindSiliguri(),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: item.amountDueCtrl,
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        decoration: _decoration('নির্ধারিত'),
                                        style: GoogleFonts.nunito(),
                                        onChanged: (_) => setState(() {}),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextFormField(
                                        controller: item.discountCtrl,
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        decoration: _decoration('ছাড়'),
                                        style: GoogleFonts.nunito(),
                                        onChanged: (_) => setState(() {}),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: item.fineCtrl,
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        decoration: _decoration('জরিমানা'),
                                        style: GoogleFonts.nunito(),
                                        onChanged: (_) => setState(() {}),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextFormField(
                                        controller: item.amountPaidCtrl,
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        decoration: _decoration('পরিশোধিত'),
                                        style: GoogleFonts.nunito(),
                                        onChanged: (_) => setState(() {}),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: _submitting ? null : _addFeeItem,
                        icon: const Icon(Icons.add),
                        label: Text('আরও ফি যোগ করুন', style: GoogleFonts.hindSiliguri()),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'মোট নেট: ৳ ${_multiGrandTotal().toStringAsFixed(2)}',
                        style: GoogleFonts.nunito(fontWeight: FontWeight.w700, color: theme.colorScheme.primary),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextFormField(
                    controller: _monthDisplay,
                    readOnly: true,
                    enabled: !_submitting && !_loadingEdit,
                    onTap: (_submitting ||
                            _loadingEdit ||
                            _existingLedger != null ||
                            _existingPayment != null)
                        ? null
                        : _pickBillingMonth,
                    decoration: _decoration('বিলিং মাস').copyWith(
                      suffixIcon: const Icon(Icons.calendar_month_outlined),
                    ),
                    style: GoogleFonts.nunito(),
                  ),
                  const SizedBox(height: 16),
                  if (_existingLedger != null || _existingPayment != null) ...[
                    TextFormField(
                      controller: _subtotal,
                      enabled: !_submitting,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: _decoration('মোট / সাবটোটাল (৳)'),
                      style: GoogleFonts.nunito(),
                      validator: _validateSubtotal,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _discount,
                      enabled: !_submitting,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: _decoration('ছাড় (৳)'),
                      style: GoogleFonts.nunito(),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _paidAmount,
                      enabled: !_submitting,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: _decoration('পরিশোধিত (৳)'),
                      style: GoogleFonts.nunito(),
                      validator: (v) {
                        final n = _parseNum(v ?? '');
                        if (n <= 0) return 'সঠিক পরিশোধিত পরিমাণ দিন';
                        return null;
                      },
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'চূড়ান্ত: ৳ ${_parseGrandTotal().toStringAsFixed(2)}',
                        style: GoogleFonts.nunito(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Text(
                    'পেমেন্টের মাধ্যম',
                    style: GoogleFonts.hindSiliguri(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Builder(
                    builder: (context) {
                      final allowed = _paymentSettings.allowedMethods();
                      final segments = allowed
                          .map(
                            (m) => ButtonSegment<PaymentMethod>(
                              value: m,
                              label: Text(
                                switch (m) {
                                  PaymentMethod.cash => 'Cash',
                                  PaymentMethod.bkash => 'bKash',
                                  PaymentMethod.nagad => 'Nagad',
                                  PaymentMethod.bank => 'Bank',
                                  PaymentMethod.other => 'Other',
                                },
                              ),
                            ),
                          )
                          .toList();
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SegmentedButton<PaymentMethod>(
                          showSelectedIcon: false,
                          segments: segments,
                          selected: {_paymentMethod},
                          onSelectionChanged: _submitting
                              ? null
                              : (s) => setState(() => _paymentMethod = s.first),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _transactionRef,
                    enabled: !_submitting,
                    decoration: _decoration('ট্রানজেকশন রেফ (bKash/Nagad/Bank)'),
                    style: GoogleFonts.nunito(),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _paidDateDisplay,
                    readOnly: true,
                    enabled: !_submitting,
                    onTap: _submitting ? null : _pickPaidDate,
                    decoration: _decoration('পেমেন্টের তারিখ').copyWith(
                      suffixIcon: const Icon(Icons.event_outlined),
                    ),
                    style: GoogleFonts.nunito(),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _note,
                    enabled: !_submitting,
                    maxLines: 2,
                    decoration: _decoration('নোট (ঐচ্ছিক)'),
                    style: GoogleFonts.hindSiliguri(),
                  ),
                  const SizedBox(height: 28),
                  FilledButton(
                    onPressed: (_submitting || _loadingEdit) ? null : _submit,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: context.themePrimary,
                    ),
                    child: Text(
                      (_existingLedger != null || _existingPayment != null)
                          ? 'হালনাগাদ করুন'
                          : 'সংরক্ষণ করুন',
                      style: GoogleFonts.hindSiliguri(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          if (_submitting || _loadingEdit)
            const ColoredBox(
              color: Color(0x66000000),
              child: Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FeeItemState {
  _FeeItemState({
    required this.paymentTypeId,
    TextEditingController? amountDueCtrl,
    TextEditingController? discountCtrl,
    TextEditingController? fineCtrl,
    TextEditingController? amountPaidCtrl,
    TextEditingController? descriptionCtrl,
  })  : amountDueCtrl = amountDueCtrl ?? TextEditingController(),
        discountCtrl = discountCtrl ?? TextEditingController(text: '0'),
        fineCtrl = fineCtrl ?? TextEditingController(text: '0'),
        amountPaidCtrl = amountPaidCtrl ?? TextEditingController(),
        descriptionCtrl = descriptionCtrl ?? TextEditingController();

  String paymentTypeId;
  final TextEditingController amountDueCtrl;
  final TextEditingController discountCtrl;
  final TextEditingController fineCtrl;
  final TextEditingController amountPaidCtrl;
  final TextEditingController descriptionCtrl;

  void dispose() {
    amountDueCtrl.dispose();
    discountCtrl.dispose();
    fineCtrl.dispose();
    amountPaidCtrl.dispose();
    descriptionCtrl.dispose();
  }
}
