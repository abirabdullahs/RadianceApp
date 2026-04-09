import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme.dart';
import '../../../../shared/models/payment_due_model.dart';
import '../../../../shared/models/payment_model.dart';
import '../../courses/repositories/course_repository.dart';
import '../../students/repositories/student_repository.dart';
import '../providers/payment_providers.dart';

final _paymentsListProvider =
    FutureProvider.autoDispose<List<PaymentModel>>((ref) async {
  return ref.watch(paymentRepositoryProvider).getPayments();
});

final _duesEnrichedProvider =
    FutureProvider.autoDispose<List<_DueRow>>((ref) async {
  final dues = await ref.watch(paymentRepositoryProvider).getDues();
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
    return Scaffold(
      appBar: AppBar(
        title: Text('পেমেন্ট', style: GoogleFonts.hindSiliguri()),
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: 'লেনদেন', style: GoogleFonts.hindSiliguri()),
            Tab(text: 'বকেয়া', style: GoogleFonts.hindSiliguri()),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/admin/payments/add'),
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.add),
        label: Text('নতুন পেমেন্ট', style: GoogleFonts.hindSiliguri()),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [_PaymentsTab(), _DuesTab()],
      ),
    );
  }
}

class _PaymentsTab extends ConsumerWidget {
  const _PaymentsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_paymentsListProvider);
    final fmt = NumberFormat.currency(symbol: '৳', decimalDigits: 0);
    return async.when(
      data: (list) {
        if (list.isEmpty) {
          return Center(
            child: Text('কোনো পেমেন্ট নেই', style: GoogleFonts.hindSiliguri()),
          );
        }
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(_paymentsListProvider);
            await ref.read(_paymentsListProvider.future);
          },
          child: ListView.builder(
            itemCount: list.length,
            itemBuilder: (context, i) {
              final p = list[i];
              return ListTile(
                title: Text(fmt.format(p.amount), style: GoogleFonts.nunito()),
                subtitle: Text(
                  '${p.voucherNo} · ${DateFormat.yMMMd().format(p.paidAt ?? DateTime.now())}',
                  style: GoogleFonts.nunito(fontSize: 12),
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

class _DuesTab extends ConsumerWidget {
  const _DuesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_duesEnrichedProvider);
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
            ref.invalidate(_duesEnrichedProvider);
            await ref.read(_duesEnrichedProvider.future);
          },
          child: ListView.builder(
            itemCount: rows.length,
            itemBuilder: (context, i) {
              final r = rows[i];
              final d = r.due;
              return ListTile(
                title: Text(r.studentName, style: GoogleFonts.hindSiliguri()),
                subtitle: Text(
                  '${r.courseName} · ${DateFormat.yMM().format(d.forMonth)}',
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
