import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/i18n/app_localizations.dart';
import '../../../core/supabase_client.dart';
import '../../../shared/models/payment_ledger_model.dart';
import '../../../shared/models/payment_model.dart';
import '../../../shared/models/payment_schedule_model.dart';
import '../../../shared/models/payment_settings_model.dart';
import '../../admin/payments/repositories/payment_repository.dart';
import '../../admin/courses/repositories/course_repository.dart';
import '../../admin/students/repositories/student_repository.dart';
import '../../../core/services/pdf_service.dart';
import '../widgets/student_drawer.dart';

class StudentPaymentsScreen extends StatefulWidget {
  const StudentPaymentsScreen({super.key});

  @override
  State<StudentPaymentsScreen> createState() => _StudentPaymentsScreenState();
}

class _StudentPaymentsScreenState extends State<StudentPaymentsScreen> {
  late Future<_PayBundle> _future;
  final _paymentRepo = PaymentRepository();
  final _studentRepo = StudentRepository();
  final _courseRepo = CourseRepository();
  final _pdfService = PdfService();

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_PayBundle> _load() async {
    final uid = supabaseClient.auth.currentUser!.id;
    final ledger = await _paymentRepo.getPaymentLedger(studentId: uid);
    final schedule = await _paymentRepo.getPaymentSchedule(studentId: uid);
    final settings = await _paymentRepo.getPaymentSettings();

    final courseIds = schedule.map((e) => e.courseId).toSet().toList();
    var advance = 0.0;
    for (final cid in courseIds) {
      final b = await _paymentRepo.getAdvanceBalance(studentId: uid, courseId: cid);
      advance += b?.balance ?? 0;
    }
    return _PayBundle(
      ledger: ledger,
      schedule: schedule,
      settings: settings,
      advanceAmount: double.parse(advance.toStringAsFixed(2)),
    );
  }

  Future<void> _showVoucher(PaymentLedgerModel p) async {
    try {
      final student = await _studentRepo.getStudentById(p.studentId);
      final course = await _courseRepo.getCourseById(p.courseId);
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
      final pdfBytes = await _pdfService.generateVoucherPdf(
        pm,
        student,
        course,
        serviceName: p.paymentTypeCode,
      );
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      await showModalBottomSheet<void>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.picture_as_pdf_outlined),
                title: Text(l10n.t('view_voucher'), style: GoogleFonts.hindSiliguri()),
                onTap: () async {
                  Navigator.pop(ctx);
                  await Printing.layoutPdf(
                    onLayout: (_) async => pdfBytes,
                    name: 'RCC-${p.voucherNo}.pdf',
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.share_outlined),
                title: Text(l10n.t('share_action'), style: GoogleFonts.hindSiliguri()),
                onTap: () async {
                  Navigator.pop(ctx);
                  await SharePlus.instance.share(
                    ShareParams(
                      files: [
                        XFile.fromData(
                          pdfBytes,
                          mimeType: 'application/pdf',
                          name: 'RCC-${p.voucherNo}.pdf',
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: '৳', decimalDigits: 0);
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      drawer: const StudentDrawer(),
      appBar: AppBar(
        leading: const AppBarDrawerLeading(),
        automaticallyImplyLeading: false,
        leadingWidth: leadingWidthForDrawer(context),
        title: Text(l10n.t('payments'), style: GoogleFonts.hindSiliguri()),
        actions: const [AppBarDrawerAction()],
      ),
      body: FutureBuilder<_PayBundle>(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  '${l10n.t('load_failed')}: ${snap.error}',
                  style: GoogleFonts.hindSiliguri(),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final b = snap.data!;
          final open = b.schedule
              .where((d) => d.status != PaymentScheduleStatus.paid && d.status != PaymentScheduleStatus.waived)
              .toList();
          final paidTotal = b.ledger.fold<double>(0, (a, e) => a + e.amountPaid);
          final dueTotal = open.fold<double>(
            0,
            (a, d) => a + (d.remainingAmount > 0 ? d.remainingAmount : d.amount),
          );
          final latestDue = open.isEmpty
              ? null
              : (open..sort((a, z) => a.dueDate.compareTo(z.dueDate))).first;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: _SummaryCard(label: l10n.t('pay_summary_paid'), value: fmt.format(paidTotal)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _SummaryCard(label: l10n.t('pay_summary_due'), value: fmt.format(dueTotal)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _SummaryCard(label: l10n.t('pay_summary_advance'), value: fmt.format(b.advanceAmount)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (latestDue != null) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.t('pay_due_alert_title'), style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        Text(
                          '${latestDue.paymentTypeCode} — ${latestDue.forMonth == null ? '—' : DateFormat.yMMMM().format(latestDue.forMonth!)}',
                          style: GoogleFonts.hindSiliguri(),
                        ),
                        Text(
                          '${l10n.t('amount_label')}: ${fmt.format(latestDue.remainingAmount > 0 ? latestDue.remainingAmount : latestDue.amount)}',
                          style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          '${l10n.t('due_date_label')}: ${DateFormat.yMMMd().format(latestDue.dueDate)}',
                          style: GoogleFonts.nunito(),
                        ),
                        const SizedBox(height: 8),
                        if (b.settings.acceptBkash && (b.settings.bkashNumber?.isNotEmpty ?? false))
                          Text('📱 bKash: ${b.settings.bkashNumber}', style: GoogleFonts.nunito()),
                        if (b.settings.acceptNagad && (b.settings.nagadNumber?.isNotEmpty ?? false))
                          Text('📱 Nagad: ${b.settings.nagadNumber}', style: GoogleFonts.nunito()),
                        if (b.settings.acceptCash)
                          Text(l10n.t('pay_cash_at_center'), style: GoogleFonts.hindSiliguri()),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (open.isNotEmpty) ...[
                Text(
                  l10n.t('dues_section'),
                  style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                ...open.map(
                  (d) => Card(
                    child: ListTile(
                      title: Text(
                        fmt.format(d.remainingAmount > 0 ? d.remainingAmount : d.amount),
                        style: GoogleFonts.nunito(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '${d.paymentTypeCode} · ${d.forMonth == null ? '—' : DateFormat.yMMMM().format(d.forMonth!)} · ${d.status.name}',
                        style: GoogleFonts.hindSiliguri(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
              Text(
                l10n.t('payment_history'),
                style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              if (b.ledger.isEmpty)
                Text(l10n.t('no_payments_yet'), style: GoogleFonts.hindSiliguri())
              else
                ...b.ledger.map(
                  (p) => ListTile(
                    title: Text(fmt.format(p.amountPaid), style: GoogleFonts.nunito()),
                    subtitle: Text(
                      '${p.paymentTypeCode} · ${p.voucherNo} · ${DateFormat.yMMMd().format(p.paidAt ?? DateTime.now())}',
                      style: GoogleFonts.nunito(fontSize: 12),
                    ),
                    onTap: () => _showVoucher(p),
                    trailing: Text(
                      p.status.name,
                      style: GoogleFonts.nunito(
                        color: p.status == LedgerPaymentStatus.paid
                            ? Colors.green
                            : p.status == LedgerPaymentStatus.partial
                                ? Colors.orange
                                : Colors.blue,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _PayBundle {
  const _PayBundle({
    required this.ledger,
    required this.schedule,
    required this.settings,
    required this.advanceAmount,
  });

  final List<PaymentLedgerModel> ledger;
  final List<PaymentScheduleModel> schedule;
  final PaymentSettingsModel settings;
  final double advanceAmount;
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: GoogleFonts.hindSiliguri(fontSize: 12)),
            const SizedBox(height: 4),
            Text(value, style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
