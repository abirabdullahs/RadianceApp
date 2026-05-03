import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../admin/payments/providers/payment_providers.dart';

final publicPaymentSettingsProvider = FutureProvider((ref) {
  return ref.read(paymentRepositoryProvider).getPaymentSettings();
});

class PublicPaymentScreen extends ConsumerWidget {
  const PublicPaymentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncSettings = ref.watch(publicPaymentSettingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('পেমেন্ট তথ্য', style: GoogleFonts.hindSiliguri()),
      ),
      body: asyncSettings.when(
        data: (settings) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Radiance Coaching Center',
                style: GoogleFonts.hindSiliguri(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'অনলাইন পেমেন্টের জন্য নিচের নম্বর/মেথড ব্যবহার করুন।',
                style: GoogleFonts.hindSiliguri(),
              ),
              const SizedBox(height: 16),
              if (settings.acceptBkash &&
                  (settings.bkashNumber?.isNotEmpty ?? false))
                _methodCard('bKash', settings.bkashNumber!),
              if (settings.acceptNagad &&
                  (settings.nagadNumber?.isNotEmpty ?? false))
                _methodCard('Nagad', settings.nagadNumber!),
              if (settings.acceptBank &&
                  (settings.bankDetails?.isNotEmpty ?? false))
                _methodCard('Bank', settings.bankDetails!),
              if (settings.acceptCash)
                _methodCard('Cash', 'ক্যাশ পেমেন্ট সেন্টারে গ্রহণযোগ্য'),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'পেমেন্ট শেষে আপনার নাম, স্টুডেন্ট আইডি এবং ট্রানজেকশন আইডি সেন্টারে জানান।',
                    style: GoogleFonts.hindSiliguri(),
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'লোড করা যায়নি: $err',
              style: GoogleFonts.hindSiliguri(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _methodCard(String label, String value) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        title: Text(
          label,
          style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(value, style: GoogleFonts.nunito()),
      ),
    );
  }
}
