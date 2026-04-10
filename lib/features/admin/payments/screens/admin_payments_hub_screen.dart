import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../../../../app/theme.dart';
import '../../widgets/admin_responsive_scaffold.dart';
import '../../../../shared/models/payment_ledger_model.dart';
import '../../../../shared/models/payment_model.dart';
import '../../../../shared/models/payment_schedule_model.dart';
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
  final dues = await ref.read(paymentRepositoryProvider).getPaymentSchedule(
        courseId: f.courseId,
        month: f.month,
        onlyOpen: true,
      );
  final open = dues;
  final sRepo = StudentRepository();
  final cRepo = CourseRepository();
  final rows = <_DueRow>[];
  for (final d in open) {
    var name = d.studentId;
    var phone = '';
    var cname = d.courseId;
    try {
      final u = await sRepo.getStudentById(d.studentId);
      name = u.fullNameBn;
      phone = u.phone;
    } catch (_) {}
    try {
      cname = (await cRepo.getCourseById(d.courseId)).name;
    } catch (_) {}
    rows.add(_DueRow(due: d, studentName: name, studentPhone: phone, courseName: cname));
  }
  return rows;
});

class _DueRow {
  const _DueRow({
    required this.due,
    required this.studentName,
    required this.studentPhone,
    required this.courseName,
  });

  final PaymentScheduleModel due;
  final String studentName;
  final String studentPhone;
  final String courseName;
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e', style: GoogleFonts.hindSiliguri())),
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

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(filteredPaymentsProvider);
    final fmt = NumberFormat.currency(symbol: '৳', decimalDigits: 0);
    final q = _voucherSearch.text.trim().toLowerCase();
    return async.when(
      data: (list) {
        final filtered = q.isEmpty ? list : list.where((p) => p.voucherNo.toLowerCase().contains(q)).toList();
        if (list.isEmpty) {
          return Center(
            child: Text('কোনো পেমেন্ট নেই', style: GoogleFonts.hindSiliguri()),
          );
        }
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _voucherSearch,
                decoration: InputDecoration(
                  labelText: 'ভাউচার নম্বর দিয়ে খুঁজুন',
                  hintText: 'যেমন RCC-2026-0001',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                  ),
                ),
                style: GoogleFonts.nunito(),
                onChanged: (_) => setState(() {}),
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
                    : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, i) {
                          final p = filtered[i];
                          return ListTile(
                            title: Text(
                              p.voucherNo,
                              style: GoogleFonts.nunito(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              '${p.paymentTypeCode} · ${fmt.format(p.amountPaid)} · ${DateFormat.yMMMd().format(p.paidAt ?? DateTime.now())}',
                              style: GoogleFonts.nunito(fontSize: 12),
                            ),
                            trailing: PopupMenuButton<String>(
                              onSelected: (v) async {
                                if (v == 'print') {
                                  await _printPayment(p);
                                }
                              },
                              itemBuilder: (ctx) => [
                                PopupMenuItem(
                                  value: 'print',
                                  child: Text('প্রিন্ট / PDF', style: GoogleFonts.hindSiliguri()),
                                ),
                              ],
                            ),
                          );
                        },
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

  Future<void> _sendReminder(BuildContext context, WidgetRef ref, _DueRow row) async {
    final d = row.due;
    final amount = d.remainingAmount > 0 ? d.remainingAmount : d.amount;
    final monthLabel = d.forMonth == null ? 'এই' : DateFormat.yMMMM().format(d.forMonth!);
    try {
      await ref.read(smsServiceProvider).notifyDueReminder(
            phone: row.studentPhone,
            studentName: row.studentName,
            monthLabel: monthLabel,
            feeTypeLabel: d.paymentTypeCode,
            amountLabel: amount.toStringAsFixed(0),
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('SMS reminder queued', style: GoogleFonts.hindSiliguri())),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _sendBulkReminder(
    BuildContext context,
    WidgetRef ref,
    List<_DueRow> rows,
  ) async {
    if (rows.isEmpty) return;
    var sent = 0;
    for (final r in rows) {
      if (r.studentPhone.isEmpty) continue;
      final d = r.due;
      final amount = d.remainingAmount > 0 ? d.remainingAmount : d.amount;
      final monthLabel =
          d.forMonth == null ? 'এই' : DateFormat.yMMMM().format(d.forMonth!);
      try {
        await ref.read(smsServiceProvider).notifyDueReminder(
              phone: r.studentPhone,
              studentName: r.studentName,
              monthLabel: monthLabel,
              feeTypeLabel: d.paymentTypeCode,
              amountLabel: amount.toStringAsFixed(0),
            );
        sent++;
      } catch (_) {}
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Bulk reminder queued: $sent/${rows.length}',
            style: GoogleFonts.hindSiliguri(),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(filteredDuesEnrichedProvider);
    final fmt = NumberFormat.currency(symbol: '৳', decimalDigits: 0);
    return async.when(
      data: (rows) {
        if (rows.isEmpty) {
          return Center(
            child: Text('কোনো বকেয়া নেই', style: GoogleFonts.hindSiliguri()),
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
                        'Total due: ${fmt.format(rows.fold<double>(0, (a, r) => a + (r.due.remainingAmount > 0 ? r.due.remainingAmount : r.due.amount)))}',
                        style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _sendBulkReminder(context, ref, rows),
                      icon: const Icon(Icons.sms),
                      label: Text('Bulk SMS', style: GoogleFonts.hindSiliguri()),
                    ),
                  ],
                ),
              ),
              ...List.generate(rows.length, (i) {
                final r = rows[i];
                final d = r.due;
                return ListTile(
                  title: Text(r.studentName, style: GoogleFonts.hindSiliguri()),
                  subtitle: Text(
                    '${r.courseName} · ${d.forMonth == null ? '—' : DateFormat.yMMMM().format(d.forMonth!)} · ${d.status.name}',
                    style: GoogleFonts.nunito(fontSize: 12),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        fmt.format(d.remainingAmount > 0 ? d.remainingAmount : d.amount),
                        style: GoogleFonts.nunito(fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        tooltip: 'SMS reminder',
                        icon: const Icon(Icons.sms_outlined),
                        onPressed: r.studentPhone.isEmpty
                            ? null
                            : () => _sendReminder(context, ref, r),
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
