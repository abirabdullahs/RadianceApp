import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/theme.dart';
import '../../../../core/student_id_display.dart';
import '../../widgets/admin_responsive_scaffold.dart';
import '../../../../shared/models/course_model.dart';
import '../../../../shared/models/payment_ledger_model.dart';
import '../../../../shared/models/payment_model.dart';
import '../../../../shared/models/user_model.dart';
import '../../courses/providers/courses_provider.dart';
import '../../courses/repositories/course_repository.dart';
import '../../students/repositories/student_repository.dart';
import '../providers/payment_providers.dart';

/// কোর্স + বিলিং মাস ফিল্টার (`null` = সব)।
class PaymentHubFilters {
  const PaymentHubFilters({this.courseId, this.month});

  final String? courseId;
  /// First day of calendar month, or `null` = সব মাস।
  final DateTime? month;
}

final paymentHubFiltersProvider =
    StateProvider<PaymentHubFilters>((ref) => const PaymentHubFilters());

final filteredPaymentsProvider =
    FutureProvider.autoDispose<List<PaymentLedgerModel>>((ref) async {
  final f = ref.watch(paymentHubFiltersProvider);
  return ref.read(paymentRepositoryProvider).getPaymentLedger(
        courseId: f.courseId,
        month: f.month,
      );
});

final filteredDuesEnrichedProvider =
    FutureProvider.autoDispose<List<_DueRow>>((ref) async {
  final f = ref.watch(paymentHubFiltersProvider);
  if (f.courseId == null || f.month == null) return const <_DueRow>[];

  final month = DateTime(f.month!.year, f.month!.month, 1);
  final paymentRepo = ref.read(paymentRepositoryProvider);
  final studentRepo = StudentRepository();
  final courseRepo = CourseRepository();

  // Students enrolled in this course (only active + currently active profile).
  final students = (await studentRepo.getStudents(courseId: f.courseId))
      .where((s) => s.isActive)
      .toList();
  if (students.isEmpty) return const <_DueRow>[];

  // Anyone who has at least one monthly-like ledger entry in selected month is "paid".
  final paidMonthly = await paymentRepo.getPaymentLedger(
    courseId: f.courseId,
    month: month,
    paymentTypeCode: 'monthly',
  );
  final paidMonthlyFee = await paymentRepo.getPaymentLedger(
    courseId: f.courseId,
    month: month,
    paymentTypeCode: 'monthly_fee',
  );
  final paidTuition = await paymentRepo.getPaymentLedger(
    courseId: f.courseId,
    month: month,
    paymentTypeCode: 'tuition',
  );
  final paidIds = <String>{
    ...paidMonthly.map((e) => e.studentId),
    ...paidMonthlyFee.map((e) => e.studentId),
    ...paidTuition.map((e) => e.studentId),
  };

  String courseName = f.courseId!;
  double courseMonthlyFee = 0;
  try {
    final c = await courseRepo.getCourseById(f.courseId!);
    courseName = c.name;
    courseMonthlyFee = c.monthlyFee;
  } catch (_) {}

  final notPaid = students.where((s) => !paidIds.contains(s.id)).toList();
  notPaid.sort((a, b) => a.fullNameBn.compareTo(b.fullNameBn));

  final sRepo = StudentRepository();
  final rows = <_DueRow>[];
  for (final s in notPaid) {
    var name = s.fullNameBn;
    var phone = '';
    var sid = s.id;
    try {
      final u = await sRepo.getStudentById(s.id);
      name = u.fullNameBn;
      phone = u.phone;
      sid = u.id;
    } catch (_) {}
    rows.add(
      _DueRow(
        studentId: sid,
        studentName: name,
        studentPhone: phone,
        courseName: courseName,
        monthlyAmount: courseMonthlyFee,
        month: month,
      ),
    );
  }
  return rows;
});

class _DueRow {
  const _DueRow({
    required this.studentId,
    required this.studentName,
    required this.studentPhone,
    required this.courseName,
    required this.monthlyAmount,
    required this.month,
  });

  final String studentId;
  final String studentName;
  final String studentPhone;
  final String courseName;
  final double monthlyAmount;
  final DateTime month;
}

/// Tabs: recent payments | open dues.
class AdminPaymentsScreen extends ConsumerStatefulWidget {
  const AdminPaymentsScreen({super.key});

  @override
  ConsumerState<AdminPaymentsScreen> createState() =>
      _AdminPaymentsScreenState();
}

class _AdminPaymentsScreenState extends ConsumerState<AdminPaymentsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  Future<void> _runGenerateDues() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2035, 12, 31),
      helpText: 'যে মাসের Due generate করবেন',
    );
    if (picked == null || !mounted) return;
    final month = DateTime(picked.year, picked.month, 1);
    try {
      final out = await ref.read(paymentDueEdgeServiceProvider).generateMonthlyDues(
            month: month,
            force: false,
          );
      if (out == null) {
        throw Exception('No response from due generation function');
      }
      ref.invalidate(filteredDuesEnrichedProvider);
      ref.invalidate(filteredPaymentsProvider);
      if (!mounted) return;
      final result =
          out['result'] is Map ? Map<String, dynamic>.from(out['result'] as Map) : const <String, dynamic>{};
      final affected = (result['affected'] ?? 0).toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Due generation complete. affected: $affected',
            style: GoogleFonts.hindSiliguri(),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      var msg = '$e';
      if (e is PostgrestException) {
        msg = e.message;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg, style: GoogleFonts.hindSiliguri())),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AdminResponsiveScaffold(
      title: Text('পেমেন্ট', style: GoogleFonts.hindSiliguri()),
      actions: [
        IconButton(
          tooltip: 'Generate Monthly Dues',
          onPressed: _runGenerateDues,
          icon: const Icon(Icons.event_repeat),
        ),
        IconButton(
          tooltip: 'SMS templates',
          onPressed: () => context.push('/admin/payments/sms-templates'),
          icon: const Icon(Icons.sms_outlined),
        ),
        IconButton(
          tooltip: 'Settings',
          onPressed: () => context.push('/admin/payments/settings'),
          icon: const Icon(Icons.settings_outlined),
        ),
        IconButton(
          tooltip: 'Reports',
          onPressed: () => context.push('/admin/payments/reports'),
          icon: const Icon(Icons.assessment_outlined),
        ),
        IconButton(
          tooltip: 'Discount সেটিংস',
          onPressed: () => context.push('/admin/payments/discounts'),
          icon: const Icon(Icons.discount_outlined),
        ),
      ],
      bottom: TabBar(
        controller: _tabs,
        tabs: [
          Tab(child: Text('লেনদেন', style: GoogleFonts.hindSiliguri())),
          Tab(child: Text('বকেয়া', style: GoogleFonts.hindSiliguri())),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/admin/payments/add'),
        backgroundColor: context.themePrimary,
        icon: const Icon(Icons.add),
        label: Text('নতুন পেমেন্ট', style: GoogleFonts.hindSiliguri()),
      ),
      body: Column(
        children: [
          const _PaymentHubFilterBar(),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: const [_PaymentsTab(), _DuesTab()],
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentHubFilterBar extends ConsumerWidget {
  const _PaymentHubFilterBar();

  Future<void> _pickMonth(BuildContext context, WidgetRef ref) async {
    final f = ref.read(paymentHubFiltersProvider);
    final initial = f.month ?? DateTime(DateTime.now().year, DateTime.now().month, 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020, 1),
      lastDate: DateTime(2035, 12),
      helpText: 'বিলিং মাস',
    );
    if (picked == null) return;
    ref.read(paymentHubFiltersProvider.notifier).state = PaymentHubFilters(
      courseId: f.courseId,
      month: DateTime(picked.year, picked.month, 1),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = ref.watch(paymentHubFiltersProvider);
    final coursesAsync = ref.watch(coursesProvider);
    final scheme = Theme.of(context).colorScheme;

    String monthLabel() {
      if (f.month == null) return 'সব মাস';
      return DateFormat.yMMMM().format(f.month!);
    }

    return Material(
      elevation: 1,
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'ফিল্টার (কোর্স ও মাস অনুযায়ী)',
              style: GoogleFonts.hindSiliguri(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: scheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            coursesAsync.when(
              data: (items) {
                Widget courseDropdown() {
                  return DropdownButtonFormField<String?>(
                    isExpanded: true,
                    // ignore: deprecated_member_use
                    value: f.courseId,
                    decoration: InputDecoration(
                      labelText: 'কোর্স',
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                      ),
                    ),
                    selectedItemBuilder: (ctx) {
                      return [
                        Text(
                          'সব কোর্স',
                          style: GoogleFonts.hindSiliguri(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        ...items.map(
                          (e) => Text(
                            e.course.name,
                            style: GoogleFonts.hindSiliguri(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ];
                    },
                    items: [
                      DropdownMenuItem<String?>(
                        value: null,
                        child: Text('সব কোর্স', style: GoogleFonts.hindSiliguri()),
                      ),
                      ...items.map(
                        (e) => DropdownMenuItem<String?>(
                          value: e.course.id,
                          child: Text(
                            e.course.name,
                            style: GoogleFonts.hindSiliguri(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (id) {
                      ref.read(paymentHubFiltersProvider.notifier).state =
                          PaymentHubFilters(courseId: id, month: f.month);
                    },
                  );
                }

                Widget monthBtn() {
                  return OutlinedButton.icon(
                    onPressed: () => _pickMonth(context, ref),
                    icon: const Icon(Icons.calendar_month, size: 18),
                    label: Text(
                      monthLabel(),
                      style: GoogleFonts.hindSiliguri(fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }

                return LayoutBuilder(
                  builder: (context, c) {
                    final narrow = c.maxWidth < 520;
                    if (narrow) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          courseDropdown(),
                          const SizedBox(height: 10),
                          monthBtn(),
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: courseDropdown(),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: monthBtn(),
                        ),
                      ],
                    );
                  },
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('$e', style: GoogleFonts.hindSiliguri(fontSize: 12)),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (f.month != null)
                  ActionChip(
                    label: Text('মাস সরান', style: GoogleFonts.hindSiliguri(fontSize: 12)),
                    onPressed: () {
                      ref.read(paymentHubFiltersProvider.notifier).state =
                          PaymentHubFilters(courseId: f.courseId, month: null);
                    },
                  ),
                TextButton(
                  onPressed: () {
                    ref.read(paymentHubFiltersProvider.notifier).state =
                        const PaymentHubFilters();
                  },
                  child: Text('ফিল্টার রিসেট', style: GoogleFonts.hindSiliguri()),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentsTab extends ConsumerStatefulWidget {
  const _PaymentsTab();

  @override
  ConsumerState<_PaymentsTab> createState() => _PaymentsTabState();
}

class _PaymentsTabState extends ConsumerState<_PaymentsTab> {
  final _voucherSearch = TextEditingController();
  final Map<String, String> _displayStudentIds = <String, String>{};
  final Map<String, String> _studentNames = <String, String>{};
  final Set<String> _selectedPaymentIds = <String>{};
  String _displayIdsKey = '';

  @override
  void dispose() {
    _voucherSearch.dispose();
    super.dispose();
  }

  Future<void> _printPayment(PaymentLedgerModel p) async {
    try {
      final student =
          await ref.read(studentRepositoryForPaymentsProvider).getStudentById(p.studentId);
      final course = await ref.read(courseRepositoryProvider).getCourseById(p.courseId);
      final pm = PaymentModel(
        id: p.id,
        voucherNo: p.voucherNo,
        studentId: p.studentId,
        courseId: p.courseId,
        forMonth: p.forMonth ?? DateTime.now(),
        amount: p.amountPaid,
        subtotal: p.amountDue,
        discount: p.discountAmount,
        paymentMethod: PaymentMethod.fromJson(p.paymentMethod),
        status: p.status == LedgerPaymentStatus.partial
            ? PaymentStatus.partial
            : PaymentStatus.paid,
        note: p.note,
        paidAt: p.paidAt,
        createdBy: p.createdBy,
      );
      final pdfBytes = await ref.read(pdfServiceProvider).generateVoucherPdf(
            pm,
            student,
            course,
            serviceName: p.paymentTypeCode,
          );
      if (!mounted) return;
      await Printing.layoutPdf(
        onLayout: (_) async => pdfBytes,
        name: 'RCC-${p.voucherNo}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e', style: GoogleFonts.hindSiliguri())),
        );
      }
    }
  }

  bool _paymentMatchesQuery(PaymentLedgerModel p, String q) {
    if (q.isEmpty) return true;
    final v = q.toLowerCase().trim();
    final normQ = v.replaceAll(RegExp(r'\s'), '');
    final normStudent = p.studentId.toLowerCase().replaceAll(RegExp(r'\s'), '');
    final display = _displayStudentIds[p.studentId] ?? '';
    final normDisplay = display.toLowerCase().replaceAll(RegExp(r'\s'), '');
    if (p.voucherNo.toLowerCase().contains(v)) return true;
    if (display.isNotEmpty && display.toLowerCase().contains(v)) return true;
    if (normQ.isNotEmpty && normDisplay.contains(normQ)) return true;
    if (p.studentId.toLowerCase().contains(v)) return true;
    if (normQ.isNotEmpty && normStudent.contains(normQ)) return true;
    return false;
  }

  Future<void> _loadDisplayStudentIds(List<PaymentLedgerModel> list) async {
    final ids = list.map((e) => e.studentId).toSet().toList()..sort();
    final key = ids.join(',');
    if (key == _displayIdsKey) return;
    _displayIdsKey = key;
    if (ids.isEmpty) {
      if (mounted) setState(() => _displayStudentIds.clear());
      return;
    }
    try {
      final map =
          await ref.read(studentRepositoryForPaymentsProvider).getDisplayStudentIdsForUserIds(ids);
      if (!mounted) return;
      setState(() {
        _displayStudentIds
          ..clear()
          ..addAll(map);
      });
    } catch (_) {}

    try {
      final names =
          await ref.read(studentRepositoryForPaymentsProvider).getStudentNamesForUserIds(ids);
      if (!mounted) return;
      setState(() {
        _studentNames
          ..clear()
          ..addAll(names);
      });
    } catch (_) {}
  }

  Future<void> _showPaymentDetail(PaymentLedgerModel p) async {
    final fmt = NumberFormat.currency(symbol: '৳', decimalDigits: 0);
    final studentRepo = ref.read(studentRepositoryForPaymentsProvider);
    final courseRepo = ref.read(courseRepositoryProvider);
    UserModel? student;
    CourseModel? course;
    try {
      student = await studentRepo.getStudentById(p.studentId);
    } catch (_) {}
    try {
      course = await courseRepo.getCourseById(p.courseId);
    } catch (_) {}
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          p.voucherNo.isEmpty ? 'পেমেন্ট' : p.voucherNo,
          style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'শিক্ষার্থী: ${student?.fullNameBn ?? '—'}',
                style: GoogleFonts.hindSiliguri(),
              ),
              const SizedBox(height: 6),
              SelectableText(
                'Student ID: ${student != null ? displayStudentIdForUser(student) : '—'}',
                style: GoogleFonts.nunito(),
              ),
              const SizedBox(height: 6),
              Text(
                'কোর্স: ${course?.name ?? p.courseId}',
                style: GoogleFonts.hindSiliguri(),
              ),
              const SizedBox(height: 6),
              Text('ফি ধরন: ${p.paymentTypeCode}', style: GoogleFonts.hindSiliguri()),
              const SizedBox(height: 6),
              Text(
                'বিলিং মাস: ${p.forMonth == null ? '—' : DateFormat.yMMMM().format(p.forMonth!)}',
                style: GoogleFonts.hindSiliguri(),
              ),
              const SizedBox(height: 6),
              Text('পরিশোধিত: ${fmt.format(p.amountPaid)}', style: GoogleFonts.nunito()),
              Text(
                'নির্ধারিত / ছাড়: ${fmt.format(p.amountDue)} / ${fmt.format(p.discountAmount)}',
                style: GoogleFonts.nunito(fontSize: 12),
              ),
              const SizedBox(height: 6),
              Text('স্ট্যাটাস: ${p.status.name}', style: GoogleFonts.hindSiliguri()),
              if (p.note != null && p.note!.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('নোট: ${p.note}', style: GoogleFonts.hindSiliguri()),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('বন্ধ', style: GoogleFonts.hindSiliguri()),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _printPayment(p);
            },
            child: Text('প্রিন্ট', style: GoogleFonts.hindSiliguri()),
          ),
        ],
      ),
    );
  }

  Future<void> _printSelectedPayments(List<PaymentLedgerModel> rows) async {
    if (rows.isEmpty) return;
    try {
      final pdfBytes = await ref.read(paymentVoucherPdfServiceProvider).buildBulkVoucherPdf(
            rows,
          );
      if (!mounted) return;
      await Printing.layoutPdf(
        onLayout: (_) async => pdfBytes,
        name: 'RCC-bulk-voucher.pdf',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e', style: GoogleFonts.hindSiliguri())),
      );
    }
  }

  Future<void> _confirmDelete(PaymentLedgerModel p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'মুছে ফেলবেন?',
          style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'ভাউচার ${p.voucherNo.isEmpty ? p.id.substring(0, 8) : p.voucherNo} — এই লেনদেন মুছে ফেলা হবে।',
          style: GoogleFonts.hindSiliguri(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('না', style: GoogleFonts.hindSiliguri()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('হ্যাঁ, মুছুন', style: GoogleFonts.hindSiliguri()),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ref.read(paymentServiceProvider).deleteRecordedPayment(p.id);
      ref.invalidate(filteredPaymentsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('মুছে ফেলা হয়েছে', style: GoogleFonts.hindSiliguri())),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e', style: GoogleFonts.hindSiliguri())),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(filteredPaymentsProvider);
    final fmt = NumberFormat.currency(symbol: '৳', decimalDigits: 0);
    final q = _voucherSearch.text.trim().toLowerCase();
    return async.when(
      data: (list) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          unawaited(_loadDisplayStudentIds(list));
        });
        final filtered =
            q.isEmpty ? list : list.where((p) => _paymentMatchesQuery(p, q)).toList();
        final validIds = filtered.map((e) => e.id).toSet();
        _selectedPaymentIds.removeWhere((id) => !validIds.contains(id));
        final selectedRows =
            filtered.where((p) => _selectedPaymentIds.contains(p.id)).toList();
        final voucherCounts = <String, int>{};
        for (final p in filtered) {
          final key = p.voucherNo.trim();
          if (key.isEmpty) continue;
          voucherCounts[key] = (voucherCounts[key] ?? 0) + 1;
        }
        if (list.isEmpty) {
          return Center(
            child: Text('কোনো পেমেন্ট নেই', style: GoogleFonts.hindSiliguri()),
          );
        }
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                children: [
                  TextField(
                    controller: _voucherSearch,
                    decoration: InputDecoration(
                      labelText: 'ভাউচার বা স্টুডেন্ট আইডি',
                      hintText: 'ভাউচার নম্বর অথবা শেষ ৯ ডিজিট',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                      ),
                    ),
                    style: GoogleFonts.nunito(),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        'Selected: ${selectedRows.length}',
                        style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: _selectedPaymentIds.isEmpty
                            ? null
                            : () => setState(() => _selectedPaymentIds.clear()),
                        child: Text('Clear', style: GoogleFonts.nunito()),
                      ),
                      const Spacer(),
                      FilledButton.icon(
                        onPressed: selectedRows.isEmpty
                            ? null
                            : () => _printSelectedPayments(selectedRows),
                        icon: const Icon(Icons.picture_as_pdf_outlined),
                        label: Text('Print Selected', style: GoogleFonts.nunito()),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(filteredPaymentsProvider);
                  await ref.read(filteredPaymentsProvider.future);
                },
                child: filtered.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: Center(
                              child: Text(
                                'কোনো মিল নেই',
                                style: GoogleFonts.hindSiliguri(),
                              ),
                            ),
                          ),
                        ],
                      )
                    : SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('Name')),
                              DataColumn(label: Text('Month')),
                              DataColumn(label: Text('TK')),
                              DataColumn(label: Text('Voucher No')),
                              DataColumn(label: Text('Voucher Group')),
                              DataColumn(label: Text('Student ID')),
                              DataColumn(label: Text('Date')),
                              DataColumn(label: Text('Actions')),
                            ],
                            rows: filtered.map((p) {
                              final name = _studentNames[p.studentId] ?? '—';
                              final month = p.forMonth == null
                                  ? '—'
                                  : DateFormat('MMM-yyyy').format(p.forMonth!);
                              final voucherRaw = p.voucherNo.isEmpty
                                  ? '(loading)'
                                  : p.voucherNo;
                              final itemCount = voucherCounts[p.voucherNo.trim()] ?? 1;
                              final sid = _displayStudentIds[p.studentId] ?? p.studentId;
                              final date = DateFormat.yMMMd()
                                  .format(p.paidAt ?? DateTime.now());
                              return DataRow(
                                selected: _selectedPaymentIds.contains(p.id),
                                onSelectChanged: (checked) {
                                  setState(() {
                                    if (checked == true) {
                                      _selectedPaymentIds.add(p.id);
                                    } else {
                                      _selectedPaymentIds.remove(p.id);
                                    }
                                  });
                                },
                                cells: [
                                  DataCell(Text(name, style: GoogleFonts.hindSiliguri())),
                                  DataCell(Text(month, style: GoogleFonts.nunito())),
                                  DataCell(Text(fmt.format(p.amountPaid), style: GoogleFonts.nunito())),
                                  DataCell(Text(voucherRaw, style: GoogleFonts.nunito())),
                                  DataCell(
                                    itemCount > 1
                                        ? Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  voucherRaw,
                                                  style: GoogleFonts.nunito(),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 6,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .primary
                                                      .withValues(alpha: 0.12),
                                                  borderRadius: BorderRadius.circular(999),
                                                ),
                                                child: Text(
                                                  '$itemCount items',
                                                  style: GoogleFonts.nunito(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w700,
                                                    color: Theme.of(context).colorScheme.primary,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          )
                                        : Text('Single', style: GoogleFonts.nunito()),
                                  ),
                                  DataCell(SelectableText(sid, style: GoogleFonts.nunito(fontSize: 12))),
                                  DataCell(Text(date, style: GoogleFonts.nunito())),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          tooltip: 'Detail',
                                          onPressed: () => _showPaymentDetail(p),
                                          icon: const Icon(Icons.visibility_outlined, size: 18),
                                        ),
                                        IconButton(
                                          tooltip: 'Edit',
                                          onPressed: () async {
                                            if (!context.mounted) return;
                                            await context.push('/admin/payments/edit/${p.id}');
                                            if (context.mounted) {
                                              ref.invalidate(filteredPaymentsProvider);
                                            }
                                          },
                                          icon: const Icon(Icons.edit_outlined, size: 18),
                                        ),
                                        IconButton(
                                          tooltip: 'Print',
                                          onPressed: () => _printPayment(p),
                                          icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                                        ),
                                        IconButton(
                                          tooltip: 'Delete',
                                          onPressed: () => _confirmDelete(p),
                                          icon: const Icon(Icons.delete_outline, size: 18),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
    );
  }
}

class _DuesTab extends ConsumerWidget {
  const _DuesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(filteredDuesEnrichedProvider);
    final filters = ref.watch(paymentHubFiltersProvider);
    final fmt = NumberFormat.currency(symbol: '৳', decimalDigits: 0);
    return async.when(
      data: (rows) {
        if (filters.courseId == null || filters.month == null) {
          return Center(
            child: Text(
              'বকেয়া দেখার জন্য কোর্স এবং মাস নির্বাচন করুন',
              style: GoogleFonts.hindSiliguri(),
              textAlign: TextAlign.center,
            ),
          );
        }
        if (rows.isEmpty) {
          return Center(
            child: Text('এই কোর্স/মাসে সবাই Monthly payment করেছে', style: GoogleFonts.hindSiliguri()),
          );
        }
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(filteredDuesEnrichedProvider);
            await ref.read(filteredDuesEnrichedProvider.future);
          },
          child: ListView(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Monthly না দেয়া শিক্ষার্থী: ${rows.length} জন',
                        style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
              ...List.generate(rows.length, (i) {
                final r = rows[i];
                return ListTile(
                  leading: CircleAvatar(
                    radius: 14,
                    child: Text('${i + 1}', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
                  ),
                  title: Text(r.studentName, style: GoogleFonts.hindSiliguri()),
                  subtitle: Text(
                    '${r.courseName} · ${DateFormat.yMMMM().format(r.month)}',
                    style: GoogleFonts.nunito(fontSize: 12),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        fmt.format(r.monthlyAmount),
                        style: GoogleFonts.nunito(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 4),
                      OutlinedButton(
                        onPressed: () => context.push('/admin/payments/add', extra: r.studentId),
                        child: Text('Clear Payment', style: GoogleFonts.nunito(fontSize: 12)),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
    );
  }
}
