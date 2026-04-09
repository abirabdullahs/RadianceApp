import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../app/theme.dart';
import '../../../../core/supabase_client.dart';
import '../../../../shared/models/course_model.dart';
import '../../../../shared/models/enrollment_model.dart';
import '../../../../shared/models/payment_model.dart';
import '../../../../shared/models/user_model.dart';
import '../../courses/providers/courses_provider.dart';
import '../providers/payment_providers.dart';

/// Admin form: record a payment, PDF voucher, optional SMS log, share/print.
class AddPaymentScreen extends ConsumerStatefulWidget {
  const AddPaymentScreen({super.key});

  @override
  ConsumerState<AddPaymentScreen> createState() => _AddPaymentScreenState();
}

class _AddPaymentScreenState extends ConsumerState<AddPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _studentQuery = TextEditingController();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  final _monthDisplay = TextEditingController();
  final _paidDateDisplay = TextEditingController();

  Timer? _searchDebounce;
  List<UserModel> _studentSuggestions = [];
  UserModel? _student;

  List<CourseModel> _courseOptions = [];
  CourseModel? _selectedCourse;

  DateTime _billingMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _paymentDate = DateTime.now();

  PaymentMethod _paymentMethod = PaymentMethod.cash;

  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _syncMonthDisplay();
    _syncPaidDateDisplay();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _studentQuery.dispose();
    _amount.dispose();
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
      _selectedCourse = null;
      _courseOptions = [];
      _amount.clear();
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
        _selectedCourse = courses.first;
        _amount.text = courses.first.monthlyFee.toStringAsFixed(0);
      } else {
        _selectedCourse = null;
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

  String? _validateAmount(String? v) {
    if (v == null || v.trim().isEmpty) return 'পরিমাণ লিখুন';
    final n = double.tryParse(v.trim().replaceAll(',', ''));
    if (n == null || n <= 0) return 'সঠিক পরিমাণ দিন';
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_student == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('শিক্ষার্থী নির্বাচন করুন', style: GoogleFonts.hindSiliguri())),
      );
      return;
    }
    if (_selectedCourse == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('কোর্স নির্বাচন করুন', style: GoogleFonts.hindSiliguri())),
      );
      return;
    }

    final amount = double.parse(_amount.text.trim().replaceAll(',', ''));
    final payment = PaymentModel(
      id: '',
      voucherNo: '',
      studentId: _student!.id,
      courseId: _selectedCourse!.id,
      forMonth: _billingMonth,
      amount: amount,
      paymentMethod: _paymentMethod,
      status: PaymentStatus.paid,
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      paidAt: _paymentDate,
      createdBy: supabaseClient.auth.currentUser?.id,
    );

    setState(() => _submitting = true);
    try {
      final saved =
          await ref.read(paymentRepositoryProvider).addPayment(payment);
      final pdfBytes = await ref.read(pdfServiceProvider).generateVoucherPdf(
            saved,
            _student!,
            _selectedCourse!,
          );

      try {
        await ref.read(smsServiceProvider).notifyPaymentRecorded(
              phone: _student!.phone,
              voucherNo: saved.voucherNo,
              amountLabel: '৳${saved.amount.toStringAsFixed(0)}',
              courseName: _selectedCourse!.name,
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
                  'পেমেন্ট সফলভাবে যোগ হয়েছে ✅',
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
      appBar: AppBar(
        title: Text('নতুন পেমেন্ট', style: GoogleFonts.hindSiliguri()),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _submitting ? null : () => context.pop(),
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
                    enabled: !_submitting,
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
                      value: _selectedCourse,
                      decoration: _decoration('কোর্স'),
                      items: _courseOptions
                          .map(
                            (c) => DropdownMenuItem(
                              value: c,
                              child: Text(c.name, style: GoogleFonts.hindSiliguri()),
                            ),
                          )
                          .toList(),
                      onChanged: _submitting
                          ? null
                          : (c) {
                              setState(() {
                                _selectedCourse = c;
                                if (c != null) {
                                  _amount.text = c.monthlyFee.toStringAsFixed(0);
                                }
                              });
                            },
                    ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _monthDisplay,
                    readOnly: true,
                    enabled: !_submitting,
                    onTap: _submitting ? null : _pickBillingMonth,
                    decoration: _decoration('বিলিং মাস').copyWith(
                      suffixIcon: const Icon(Icons.calendar_month_outlined),
                    ),
                    style: GoogleFonts.nunito(),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _amount,
                    enabled: !_submitting,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: _decoration('পরিমাণ (৳)'),
                    style: GoogleFonts.nunito(),
                    validator: _validateAmount,
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
                    onPressed: _submitting ? null : _submit,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: AppTheme.primary,
                    ),
                    child: Text(
                      'সংরক্ষণ করুন',
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
          if (_submitting)
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
