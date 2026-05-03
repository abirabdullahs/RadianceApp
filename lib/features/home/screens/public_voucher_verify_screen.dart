import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/supabase_client.dart';

class PublicVoucherVerifyScreen extends StatefulWidget {
  const PublicVoucherVerifyScreen({super.key, this.initialVoucher});

  final String? initialVoucher;

  @override
  State<PublicVoucherVerifyScreen> createState() =>
      _PublicVoucherVerifyScreenState();
}

class _PublicVoucherVerifyScreenState extends State<PublicVoucherVerifyScreen> {
  late final TextEditingController _voucherCtrl;
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _voucherCtrl = TextEditingController(text: widget.initialVoucher ?? '');
    final v = _voucherCtrl.text.trim();
    if (v.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _lookup());
    }
  }

  @override
  void dispose() {
    _voucherCtrl.dispose();
    super.dispose();
  }

  Future<void> _lookup() async {
    final voucher = _voucherCtrl.text.trim();
    if (voucher.isEmpty) {
      setState(() {
        _error = 'Enter voucher number';
        _data = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final out = await supabaseClient.rpc(
        'public_get_voucher_by_no',
        params: {'p_voucher_no': voucher},
      );
      final map = out is Map ? Map<String, dynamic>.from(out) : null;
      final success = map?['success'] == true;
      if (!success) {
        setState(() {
          _data = null;
          _error = 'Voucher not found';
        });
      } else {
        setState(() {
          _data = map;
          _error = null;
        });
      }
    } catch (e) {
      setState(() {
        _data = null;
        _error = '$e';
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = ((_data?['items'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final first = items.isEmpty ? null : items.first;
    final totalPaid = items.fold<double>(
      0,
      (p, e) => p + ((e['amount_paid'] as num?)?.toDouble() ?? 0),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('Voucher Verification', style: GoogleFonts.nunito()),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _voucherCtrl,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _lookup(),
            decoration: InputDecoration(
              labelText: 'Voucher No',
              hintText: 'RCC-VCH-...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: _loading ? null : _lookup,
            icon: const Icon(Icons.verified_outlined),
            label: Text(_loading ? 'Checking...' : 'Verify'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: GoogleFonts.nunito(color: Colors.red)),
          ],
          if (first != null) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Valid Voucher',
                      style: GoogleFonts.nunito(
                        fontWeight: FontWeight.w800,
                        color: Colors.green.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Voucher: ${first['voucher_no'] ?? '-'}',
                        style: GoogleFonts.nunito()),
                    Text('Student: ${first['student_name'] ?? '-'}',
                        style: GoogleFonts.nunito()),
                    Text('Student ID: ${first['student_code'] ?? '-'}',
                        style: GoogleFonts.nunito()),
                    Text('Course: ${first['course_name'] ?? '-'}',
                        style: GoogleFonts.nunito()),
                    Text('Items: ${items.length}', style: GoogleFonts.nunito()),
                    Text(
                      'Total Paid: ${totalPaid.toStringAsFixed(2)}',
                      style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
