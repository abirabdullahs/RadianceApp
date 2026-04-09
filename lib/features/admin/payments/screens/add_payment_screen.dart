import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../app/theme.dart';
import '../../widgets/admin_drawer.dart';
import '../../../../core/supabase_client.dart';
import '../../../../shared/models/course_model.dart';
import '../../../../shared/models/enrollment_model.dart';
import '../../../../shared/models/fee_service_model.dart';
import '../../../../shared/models/payment_model.dart';
import '../../../../shared/models/user_model.dart';
import '../../courses/providers/courses_provider.dart';
import '../providers/payment_providers.dart';

/// Admin form: record a payment, PDF voucher, optional SMS log, share/print.
/// [editingPaymentId] set → load existing row (edit).
class AddPaymentScreen extends ConsumerStatefulWidget {
  const AddPaymentScreen({super.key, this.editingPaymentId});

  final String? editingPaymentId;

  @override
  ConsumerState<AddPaymentScreen> createState() => _AddPaymentScreenState();
}

class _AddPaymentScreenState extends ConsumerState<AddPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _studentQuery = TextEditingController();
  final _subtotal = TextEditingController();
  final _discount = TextEditingController(text: '0');
  final _note = TextEditingController();
  final _monthDisplay = TextEditingController();
  final _paidDateDisplay = TextEditingController();

  Timer? _searchDebounce;
  List<UserModel> _studentSuggestions = [];
  UserModel? _student;

  List<CourseModel> _courseOptions = [];
  String? _selectedCourseId;

  List<FeeServiceModel> _feeServices = [];
  String? _selectedFeeServiceId;

  PaymentModel? _existingPayment;
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

  FeeServiceModel? get _feeService {
    final id = _selectedFeeServiceId;
    if (id == null) return null;
    for (final s in _feeServices) {
      if (s.id == id) return s;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _syncMonthDisplay();
    _syncPaidDateDisplay();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadFeeServices();
      if (widget.editingPaymentId != null) {
        await _loadPaymentForEdit(widget.editingPaymentId!);
      }
    });
  }

  Future<void> _loadFeeServices() async {
    try {
      final list = await ref.read(paymentRepositoryProvider).listFeeServices();
      if (!mounted) return;
      setState(() => _feeServices = list);
    } catch (_) {
      if (mounted) setState(() => _feeServices = []);
    }
  }

  Future<void> _loadPaymentForEdit(String id) async {
    setState(() => _loadingEdit = true);
    try {
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
        _note.text = p.note ?? '';
        _paymentMethod = p.paymentMethod ?? PaymentMethod.cash;
        _selectedFeeServiceId = p.feeServiceId;
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

  Future<void> _addNewService() async {
    final nameCtrl = TextEditingController();
    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('নতুন সার্ভিস', style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w700)),
          content: TextField(
            controller: nameCtrl,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'নাম',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.cardRadius)),
            ),
            style: GoogleFonts.hindSiliguri(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('বাতিল', style: GoogleFonts.hindSiliguri()),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('যোগ করুন', style: GoogleFonts.hindSiliguri()),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
      final name = nameCtrl.text.trim();
      if (name.isEmpty) return;
      final s = await ref.read(paymentRepositoryProvider).addFeeService(name);
      if (!mounted) return;
      final merged = [..._feeServices, s]
        ..sort((a, b) => a.sortOrder != b.sortOrder
            ? a.sortOrder.compareTo(b.sortOrder)
            : a.name.compareTo(b.name));
      setState(() {
        _feeServices = merged;
        _selectedFeeServiceId = s.id;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('সার্ভিস যোগ হয়েছে', style: GoogleFonts.hindSiliguri())),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e', style: GoogleFonts.hindSiliguri())),
        );
      }
    } finally {
      nameCtrl.dispose();
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _studentQuery.dispose();
    _subtotal.dispose();
    _discount.dispose();
    _note.dispose();
    _monthDisplay.dispose();
    _paidDateDisplay.dispose();
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
    if (q.length < 2) {
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
      _selectedFeeServiceId = null;
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
      } else {
        _selectedCourseId = null;
      }
    });
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
    if (_feeService == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('সার্ভিস নির্বাচন করুন', style: GoogleFonts.hindSiliguri())),
      );
      return;
    }

    final subtotal = double.parse(_subtotal.text.trim().replaceAll(',', ''));
    final discount = double.tryParse(_discount.text.trim().replaceAll(',', '')) ?? 0;
    if (discount < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ছাড় ০ বা তার বেশি হতে হবে', style: GoogleFonts.hindSiliguri())),
      );
      return;
    }
    if (discount > subtotal) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ছাড় মোটের চেয়ে বেশি হতে পারে না', style: GoogleFonts.hindSiliguri())),
      );
      return;
    }
    final grand = double.parse((subtotal - discount).toStringAsFixed(2));
    if (grand <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('চূড়ান্ত পরিমাণ ০ এর উপরে হতে হবে', style: GoogleFonts.hindSiliguri())),
      );
      return;
    }

    final isEdit = _existingPayment != null;
    final paymentNew = PaymentModel(
      id: '',
      voucherNo: '',
      studentId: _student!.id,
      courseId: _course!.id,
      forMonth: _billingMonth,
      amount: grand,
      subtotal: subtotal,
      discount: discount,
      feeServiceId: _feeService!.id,
      paymentMethod: _paymentMethod,
      status: PaymentStatus.paid,
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      paidAt: _paymentDate,
      createdBy: supabaseClient.auth.currentUser?.id,
    );

    setState(() => _submitting = true);
    try {
      final PaymentModel saved;
      if (isEdit) {
        saved = await ref.read(paymentRepositoryProvider).updatePayment(
              _existingPayment!.copyWith(
                amount: grand,
                subtotal: subtotal,
                discount: discount,
                feeServiceId: _feeService!.id,
                paymentMethod: _paymentMethod,
                note: _note.text.trim().isEmpty ? null : _note.text.trim(),
                paidAt: _paymentDate,
              ),
            );
      } else {
        saved = await ref.read(paymentRepositoryProvider).addPayment(paymentNew);
      }
      final pdfBytes = await ref.read(pdfServiceProvider).generateVoucherPdf(
            saved,
            _student!,
            _course!,
            serviceName: _feeService!.name,
          );

      if (!isEdit) {
        try {
          await ref.read(smsServiceProvider).notifyPaymentRecorded(
                phone: _student!.phone,
                voucherNo: saved.voucherNo,
                amountLabel: '৳${saved.amount.toStringAsFixed(0)}',
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
                  isEdit ? 'পেমেন্ট হালনাগাদ হয়েছে ✅' : 'পেমেন্ট সফলভাবে যোগ হয়েছে ✅',
                  style: GoogleFonts.hindSiliguri(),
                ),
                const SizedBox(height: 12),
                SelectableText(
                  'ভাউচার নং: ${saved.voucherNo}',
                  style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w600),
                ),
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
                          name: 'RCC-${saved.voucherNo}.pdf',
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
                    name: 'RCC-${saved.voucherNo}.pdf',
                  );
                },
                child: Text('ভাউচার দেখুন', style: GoogleFonts.hindSiliguri()),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text('ঠিক আছে', style: GoogleFonts.hindSiliguri()),
              ),
            ],
          );
        },
      );
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

    return Scaffold(
      drawer: const AdminDrawer(),
      appBar: AppBar(
        leading: const AppBarDrawerLeading(),
        automaticallyImplyLeading: false,
        leadingWidth: leadingWidthForDrawer(context),
        title: Text(
          _existingPayment != null ? 'পেমেন্ট সম্পাদনা' : 'নতুন পেমেন্ট',
          style: GoogleFonts.hindSiliguri(),
        ),
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
                    enabled: !_submitting && !_loadingEdit && _existingPayment == null,
                    decoration: _decoration('নাম বা ফোন দিয়ে খুঁজুন').copyWith(
                      hintText: 'কমপক্ষে ২ অক্ষর',
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
                                subtitle: Text(u.phone, style: GoogleFonts.nunito()),
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
                      onChanged: (_submitting || _loadingEdit || _existingPayment != null)
                          ? null
                          : (c) {
                              setState(() {
                                _selectedCourseId = c?.id;
                                if (c != null) {
                                  _subtotal.text = c.monthlyFee.toStringAsFixed(0);
                                }
                              });
                            },
                    ),
                  const SizedBox(height: 16),
                  Text(
                    'সার্ভিস',
                    style: GoogleFonts.hindSiliguri(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<FeeServiceModel>(
                          value: _feeService,
                          decoration: _decoration('সার্ভিস নির্বাচন করুন'),
                          items: _feeServices
                              .map(
                                (s) => DropdownMenuItem<FeeServiceModel>(
                                  value: s,
                                  child: Text(s.name, style: GoogleFonts.hindSiliguri()),
                                ),
                              )
                              .toList(),
                          onChanged: _submitting || _loadingEdit
                              ? null
                              : (s) => setState(() => _selectedFeeServiceId = s?.id),
                          validator: (s) =>
                              s == null ? 'সার্ভিস নির্বাচন করুন' : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: OutlinedButton.icon(
                          onPressed: _submitting ? null : _addNewService,
                          icon: const Icon(Icons.add, size: 20),
                          label: Text('নতুন', style: GoogleFonts.hindSiliguri()),
                        ),
                      ),
                    ],
                  ),
                  if (_feeServices.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'সার্ভিস লোড হচ্ছে… অথবা «নতুন» দিয়ে যোগ করুন',
                        style: GoogleFonts.hindSiliguri(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _monthDisplay,
                    readOnly: true,
                    enabled: !_submitting && !_loadingEdit,
                    onTap: (_submitting || _loadingEdit || _existingPayment != null)
                        ? null
                        : _pickBillingMonth,
                    decoration: _decoration('বিলিং মাস').copyWith(
                      suffixIcon: const Icon(Icons.calendar_month_outlined),
                    ),
                    style: GoogleFonts.nunito(),
                  ),
                  const SizedBox(height: 16),
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
                  Text(
                    'পেমেন্টের মাধ্যম',
                    style: GoogleFonts.hindSiliguri(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SegmentedButton<PaymentMethod>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(
                          value: PaymentMethod.cash,
                          label: Text('Cash'),
                        ),
                        ButtonSegment(
                          value: PaymentMethod.bkash,
                          label: Text('bKash'),
                        ),
                        ButtonSegment(
                          value: PaymentMethod.nagad,
                          label: Text('Nagad'),
                        ),
                        ButtonSegment(
                          value: PaymentMethod.bank,
                          label: Text('Bank'),
                        ),
                      ],
                      selected: {_paymentMethod},
                      onSelectionChanged: _submitting
                          ? null
                          : (s) => setState(() => _paymentMethod = s.first),
                    ),
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
                      _existingPayment != null ? 'হালনাগাদ করুন' : 'সংরক্ষণ করুন',
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
