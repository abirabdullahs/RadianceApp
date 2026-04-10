import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../widgets/admin_responsive_scaffold.dart';
import '../providers/payment_providers.dart';

class AdminPaymentSmsTemplatesScreen extends ConsumerStatefulWidget {
  const AdminPaymentSmsTemplatesScreen({super.key});

  @override
  ConsumerState<AdminPaymentSmsTemplatesScreen> createState() =>
      _AdminPaymentSmsTemplatesScreenState();
}

class _AdminPaymentSmsTemplatesScreenState
    extends ConsumerState<AdminPaymentSmsTemplatesScreen> {
  bool _loading = true;
  bool _saving = false;
  final _paymentCtrl = TextEditingController();
  final _dueCtrl = TextEditingController();
  bool _paymentActive = true;
  bool _dueActive = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _paymentCtrl.dispose();
    _dueCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final rows = await ref.read(smsServiceProvider).listTemplates();
    final byKey = {for (final r in rows) r.templateKey: r};
    final pay = byKey['payment_confirmation'];
    final due = byKey['due_reminder'];
    if (!mounted) return;
    setState(() {
      _paymentCtrl.text = pay?.body ??
          'প্রিয় {name}, {month} মাসের {type} ৳{amount} পরিশোধিত হয়েছে। ভাউচার: {voucher_no}। ধন্যবাদ — Radiance';
      _dueCtrl.text = due?.body ??
          'প্রিয় {name}, {month} মাসের {type} ৳{amount} এখনও বকেয়া আছে। দ্রুত পরিশোধ করুন। — Radiance Coaching Center';
      _paymentActive = pay?.isActive ?? true;
      _dueActive = due?.isActive ?? true;
      _loading = false;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(smsServiceProvider).upsertTemplate(
            templateKey: 'payment_confirmation',
            name: 'Payment confirmation',
            body: _paymentCtrl.text.trim(),
            isActive: _paymentActive,
          );
      await ref.read(smsServiceProvider).upsertTemplate(
            templateKey: 'due_reminder',
            name: 'Due reminder',
            body: _dueCtrl.text.trim(),
            isActive: _dueActive,
          );
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('SMS templates saved', style: GoogleFonts.hindSiliguri())),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminResponsiveScaffold(
      title: Text('Payment SMS Templates', style: GoogleFonts.hindSiliguri()),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Variables: {name}, {month}, {type}, {amount}, {voucher_no}',
                    style: GoogleFonts.nunito(fontSize: 12)),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: Text('Payment confirmation active', style: GoogleFonts.hindSiliguri()),
                  value: _paymentActive,
                  onChanged: (v) => setState(() => _paymentActive = v),
                ),
                TextField(
                  controller: _paymentCtrl,
                  minLines: 4,
                  maxLines: 6,
                  decoration: const InputDecoration(labelText: 'Payment confirmation template'),
                ),
                const SizedBox(height: 14),
                SwitchListTile(
                  title: Text('Due reminder active', style: GoogleFonts.hindSiliguri()),
                  value: _dueActive,
                  onChanged: (v) => setState(() => _dueActive = v),
                ),
                TextField(
                  controller: _dueCtrl,
                  minLines: 4,
                  maxLines: 6,
                  decoration: const InputDecoration(labelText: 'Due reminder template'),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Saving...' : 'Save templates', style: GoogleFonts.hindSiliguri()),
                ),
              ],
            ),
    );
  }
}
