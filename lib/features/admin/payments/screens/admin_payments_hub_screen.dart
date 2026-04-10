import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../../../../app/theme.dart';
import '../../widgets/admin_responsive_scaffold.dart';
import '../../../../shared/models/payment_due_model.dart';
import '../../../../shared/models/payment_model.dart';
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
    FutureProvider.autoDispose<List<PaymentModel>>((ref) async {
  final f = ref.watch(paymentHubFiltersProvider);
  return ref.read(paymentRepositoryProvider).getPayments(
        courseId: f.courseId,
        month: f.month,
      );
});

final filteredDuesEnrichedProvider =
    FutureProvider.autoDispose<List<_DueRow>>((ref) async {
  final f = ref.watch(paymentHubFiltersProvider);
  final dues = await ref.read(paymentRepositoryProvider).getDues(
        courseId: f.courseId,
        month: f.month,
      );
  final open = dues.where((d) => d.status == DueStatus.due).toList();
  final sRepo = StudentRepository();
  final cRepo = CourseRepository();
  final rows = <_DueRow>[];
  for (final d in open) {
    var name = d.studentId;
    var cname = d.courseId;
    try {
      name = (await sRepo.getStudentById(d.studentId)).fullNameBn;
    } catch (_) {}
    try {
      cname = (await cRepo.getCourseById(d.courseId)).name;
    } catch (_) {}
    rows.add(_DueRow(due: d, studentName: name, courseName: cname));
  }
  return rows;
});

class _DueRow {
  const _DueRow({
    required this.due,
    required this.studentName,
    required this.courseName,
  });

  final PaymentDueModel due;
  final String studentName;
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

  Future<void> _printPayment(PaymentModel p) async {
    try {
      final student =
          await ref.read(studentRepositoryForPaymentsProvider).getStudentById(p.studentId);
      final course = await ref.read(courseRepositoryProvider).getCourseById(p.courseId);
      String? serviceName;
      if (p.feeServiceId != null) {
        final svcs = await ref.read(paymentRepositoryProvider).listFeeServices();
        for (final s in svcs) {
          if (s.id == p.feeServiceId) {
            serviceName = s.name;
            break;
          }
        }
      }
      final pdfBytes = await ref.read(pdfServiceProvider).generateVoucherPdf(
            p,
            student,
            course,
            serviceName: serviceName,
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

  Future<void> _confirmDelete(PaymentModel p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('মুছে ফেলবেন?', style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w700)),
        content: Text(
          'ভাউচার ${p.voucherNo} — এই লেনদেন মুছে যাবে।',
          style: GoogleFonts.hindSiliguri(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('বাতিল', style: GoogleFonts.hindSiliguri()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('মুছুন', style: GoogleFonts.hindSiliguri()),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ref.read(paymentRepositoryProvider).deletePayment(p.id);
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
        final filtered = q.isEmpty
            ? list
            : list
                .where((p) => p.voucherNo.toLowerCase().contains(q))
                .toList();
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
                  hintText: 'যেমন RCC-VCH-2026-0001',
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
                              '${fmt.format(p.amount)} · ${DateFormat.yMMMd().format(p.paidAt ?? DateTime.now())}',
                              style: GoogleFonts.nunito(fontSize: 12),
                            ),
                            trailing: PopupMenuButton<String>(
                              onSelected: (v) async {
                                if (v == 'edit') {
                                  await context.push('/admin/payments/edit/${p.id}');
                                  if (mounted) ref.invalidate(filteredPaymentsProvider);
                                } else if (v == 'print') {
                                  await _printPayment(p);
                                } else if (v == 'delete') {
                                  await _confirmDelete(p);
                                }
                              },
                              itemBuilder: (ctx) => [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Text('সম্পাদনা', style: GoogleFonts.hindSiliguri()),
                                ),
                                PopupMenuItem(
                                  value: 'print',
                                  child: Text('প্রিন্ট / PDF', style: GoogleFonts.hindSiliguri()),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text(
                                    'মুছুন',
                                    style: GoogleFonts.hindSiliguri(
                                      color: Theme.of(ctx).colorScheme.error,
                                    ),
                                  ),
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
          child: ListView.builder(
            itemCount: rows.length,
            itemBuilder: (context, i) {
              final r = rows[i];
              final d = r.due;
              return ListTile(
                title: Text(r.studentName, style: GoogleFonts.hindSiliguri()),
                subtitle: Text(
                  '${r.courseName} · ${DateFormat.yMMMM().format(d.forMonth)}',
                  style: GoogleFonts.nunito(fontSize: 12),
                ),
                trailing: Text(
                  fmt.format(d.amount),
                  style: GoogleFonts.nunito(fontWeight: FontWeight.bold),
                ),
              );
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
    );
  }
}
