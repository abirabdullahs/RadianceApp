import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../app/theme.dart';
import '../../../../shared/models/payment_report_models.dart';
import '../../courses/providers/courses_provider.dart';
import '../../widgets/admin_responsive_scaffold.dart';
import '../providers/payment_providers.dart';

class AdminPaymentReportsScreen extends ConsumerStatefulWidget {
  const AdminPaymentReportsScreen({super.key});

  @override
  ConsumerState<AdminPaymentReportsScreen> createState() =>
      _AdminPaymentReportsScreenState();
}

class _AdminPaymentReportsScreenState
    extends ConsumerState<AdminPaymentReportsScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month, 1);
  String? _courseId;
  bool _overdueOnly = false;
  final _studentIdCtrl = TextEditingController();
  int _year = DateTime.now().year;

  @override
  void dispose() {
    _studentIdCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _month,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2035, 12, 31),
      helpText: 'রিপোর্ট মাস',
    );
    if (picked == null) return;
    setState(() => _month = DateTime(picked.year, picked.month, 1));
  }

  Future<void> _shareTextCsv({
    required String filename,
    required List<String> headers,
    required List<List<String>> rows,
  }) async {
    final b = StringBuffer();
    b.writeln(headers.join(','));
    for (final row in rows) {
      b.writeln(row.map(_csvCell).join(','));
    }
    await SharePlus.instance.share(
      ShareParams(
        text: b.toString(),
        subject: filename,
      ),
    );
  }

  String _csvCell(String v) {
    final escaped = v.replaceAll('"', '""');
    return '"$escaped"';
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(paymentRepositoryProvider);
    final coursesAsync = ref.watch(coursesProvider);
    final monthlyFuture = repo.getMonthlyCollectionReport(month: _month, courseId: _courseId);
    final dueFuture = repo.getDueReport(month: _month, courseId: _courseId, overdueOnly: _overdueOnly);
    final annualFuture = _studentIdCtrl.text.trim().isEmpty
        ? null
        : repo.getStudentAnnualReport(studentId: _studentIdCtrl.text.trim(), year: _year);
    final fmt = NumberFormat.currency(symbol: '৳', decimalDigits: 0);

    return AdminResponsiveScaffold(
      title: Text('Payment Reports', style: GoogleFonts.hindSiliguri()),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickMonth,
                          icon: const Icon(Icons.calendar_month),
                          label: Text(DateFormat.yMMMM().format(_month), style: GoogleFonts.hindSiliguri()),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: coursesAsync.when(
                          data: (items) => DropdownButtonFormField<String?>(
                            isExpanded: true,
                            value: _courseId,
                            decoration: InputDecoration(
                              labelText: 'Course',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.cardRadius)),
                            ),
                            items: [
                              DropdownMenuItem<String?>(
                                value: null,
                                child: Text('সব কোর্স', style: GoogleFonts.hindSiliguri()),
                              ),
                              ...items.map(
                                (c) => DropdownMenuItem<String?>(
                                  value: c.course.id,
                                  child: Text(c.course.name, style: GoogleFonts.hindSiliguri()),
                                ),
                              ),
                            ],
                            onChanged: (v) => setState(() => _courseId = v),
                          ),
                          loading: () => const SizedBox(height: 48, child: LinearProgressIndicator()),
                          error: (e, _) => Text('$e'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _studentIdCtrl,
                          decoration: InputDecoration(
                            labelText: 'Student ID (UUID)',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.cardRadius)),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 120,
                        child: TextFormField(
                          initialValue: '$_year',
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Year',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.cardRadius)),
                          ),
                          onChanged: (v) {
                            final y = int.tryParse(v.trim());
                            if (y != null) setState(() => _year = y);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: Text('Overdue only', style: GoogleFonts.hindSiliguri()),
                    value: _overdueOnly,
                    onChanged: (v) => setState(() => _overdueOnly = v),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          FutureBuilder<MonthlyCollectionReport>(
            future: monthlyFuture,
            builder: (context, snap) {
              if (!snap.hasData) return const Card(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()));
              final r = snap.data!;
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text('Monthly Collection', style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.bold)),
                          ),
                          IconButton(
                            tooltip: 'Share CSV',
                            onPressed: () async {
                              await _shareTextCsv(
                                filename: 'monthly_collection_${DateFormat('yyyy_MM').format(_month)}.csv',
                                headers: const ['payment_type', 'collected', 'transactions', 'students'],
                                rows: r.breakdown
                                    .map((e) => [
                                          e.paymentTypeCode,
                                          e.collectedAmount.toStringAsFixed(2),
                                          e.transactionsCount.toString(),
                                          e.studentCount.toString(),
                                        ])
                                    .toList(),
                              );
                            },
                            icon: const Icon(Icons.ios_share_outlined),
                          ),
                        ],
                      ),
                      Text('মোট: ${fmt.format(r.totalCollected)} · Tx: ${r.totalTransactions}', style: GoogleFonts.nunito()),
                      const SizedBox(height: 8),
                      ...r.breakdown.map(
                        (b) => ListTile(
                          dense: true,
                          title: Text(b.paymentTypeCode, style: GoogleFonts.nunito(fontWeight: FontWeight.w600)),
                          subtitle: Text('Tx ${b.transactionsCount} · Students ${b.studentCount}', style: GoogleFonts.nunito(fontSize: 12)),
                          trailing: Text(fmt.format(b.collectedAmount), style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<DueReportRow>>(
            future: dueFuture,
            builder: (context, snap) {
              if (!snap.hasData) return const Card(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()));
              final rows = snap.data!;
              final total = rows.fold<double>(0, (a, b) => a + b.remainingAmount);
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text('Due Report', style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.bold)),
                          ),
                          IconButton(
                            tooltip: 'Share CSV',
                            onPressed: () async {
                              await _shareTextCsv(
                                filename: 'due_report_${DateFormat('yyyy_MM').format(_month)}.csv',
                                headers: const [
                                  'student_id',
                                  'student_name',
                                  'course',
                                  'type',
                                  'status',
                                  'due_date',
                                  'remaining',
                                  'overdue_days',
                                ],
                                rows: rows
                                    .map((d) => [
                                          d.studentId,
                                          d.studentName,
                                          d.courseName,
                                          d.paymentTypeCode,
                                          d.status,
                                          DateFormat('yyyy-MM-dd').format(d.dueDate),
                                          d.remainingAmount.toStringAsFixed(2),
                                          d.overdueDays.toString(),
                                        ])
                                    .toList(),
                              );
                            },
                            icon: const Icon(Icons.ios_share_outlined),
                          ),
                        ],
                      ),
                      Text('Rows ${rows.length} · Total due ${fmt.format(total)}', style: GoogleFonts.nunito()),
                      const SizedBox(height: 8),
                      ...rows.take(30).map(
                        (d) => ListTile(
                          dense: true,
                          title: Text('${d.studentName} · ${d.paymentTypeCode}', style: GoogleFonts.hindSiliguri()),
                          subtitle: Text('${d.courseName} · ${d.status} · overdue ${d.overdueDays}d', style: GoogleFonts.nunito(fontSize: 12)),
                          trailing: Text(fmt.format(d.remainingAmount), style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          if (annualFuture != null)
            FutureBuilder<StudentAnnualReport>(
              future: annualFuture,
              builder: (context, snap) {
                if (!snap.hasData) return const Card(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()));
                final r = snap.data!;
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text('Student Annual Report', style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.bold)),
                            ),
                            IconButton(
                              tooltip: 'Share CSV',
                              onPressed: () async {
                                await _shareTextCsv(
                                  filename: 'student_annual_${r.studentId}_${
                                      r.year
                                    }.csv',
                                  headers: const [
                                    'course',
                                    'type',
                                    'month',
                                    'status',
                                    'amount',
                                    'paid',
                                    'remaining',
                                  ],
                                  rows: r.rows
                                      .map((d) => [
                                            d.courseName,
                                            d.paymentTypeCode,
                                            d.forMonth == null
                                                ? ''
                                                : DateFormat('yyyy-MM').format(d.forMonth!),
                                            d.status,
                                            d.amount.toStringAsFixed(2),
                                            d.paidAmount.toStringAsFixed(2),
                                            d.remainingAmount.toStringAsFixed(2),
                                          ])
                                      .toList(),
                                );
                              },
                              icon: const Icon(Icons.ios_share_outlined),
                            ),
                          ],
                        ),
                        Text('Due ${fmt.format(r.totalDue)} · Paid ${fmt.format(r.totalPaid)} · Remaining ${fmt.format(r.totalRemaining)}', style: GoogleFonts.nunito()),
                        const SizedBox(height: 8),
                        ...r.rows.take(24).map(
                          (d) => ListTile(
                            dense: true,
                            title: Text('${d.paymentTypeCode} · ${d.forMonth == null ? '—' : DateFormat.yMMM().format(d.forMonth!)}', style: GoogleFonts.nunito()),
                            subtitle: Text('${d.courseName} · ${d.status}', style: GoogleFonts.hindSiliguri(fontSize: 12)),
                            trailing: Text(fmt.format(d.remainingAmount), style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
