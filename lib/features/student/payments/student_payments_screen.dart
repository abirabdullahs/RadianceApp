import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/supabase_client.dart';
import '../../../shared/models/payment_due_model.dart';
import '../../../shared/models/payment_model.dart';
import '../../admin/payments/repositories/payment_repository.dart';

class StudentPaymentsScreen extends StatefulWidget {
  const StudentPaymentsScreen({super.key});

  @override
  State<StudentPaymentsScreen> createState() => _StudentPaymentsScreenState();
}

class _StudentPaymentsScreenState extends State<StudentPaymentsScreen> {
  late Future<_PayBundle> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_PayBundle> _load() async {
    final uid = supabaseClient.auth.currentUser!.id;
    final repo = PaymentRepository();
    final payments = await repo.getPayments(studentId: uid);
    final dues = await repo.getDues(studentId: uid);
    return _PayBundle(payments: payments, dues: dues);
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: '৳', decimalDigits: 0);
    return Scaffold(
      appBar: AppBar(
        title: Text('পেমেন্ট', style: GoogleFonts.hindSiliguri()),
      ),
      body: FutureBuilder<_PayBundle>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final b = snap.data!;
          final open = b.dues.where((d) => d.status == DueStatus.due).toList();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (open.isNotEmpty) ...[
                Text(
                  'বকেয়া',
                  style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                ...open.map(
                  (d) => Card(
                    child: ListTile(
                      title: Text(
                        fmt.format(d.amount),
                        style: GoogleFonts.nunito(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        DateFormat.yMMMM().format(d.forMonth),
                        style: GoogleFonts.hindSiliguri(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
              Text(
                'ইতিহাস',
                style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              if (b.payments.isEmpty)
                Text('কোনো পেমেন্ট নেই', style: GoogleFonts.hindSiliguri())
              else
                ...b.payments.map(
                  (p) => ListTile(
                    title: Text(fmt.format(p.amount), style: GoogleFonts.nunito()),
                    subtitle: Text(
                      '${p.voucherNo} · ${DateFormat.yMMMd().format(p.paidAt ?? DateTime.now())}',
                      style: GoogleFonts.nunito(fontSize: 12),
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
  const _PayBundle({required this.payments, required this.dues});

  final List<PaymentModel> payments;
  final List<PaymentDueModel> dues;
}
