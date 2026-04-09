import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Question bank (browse) — placeholder until full Q-Bank ships.
class QBankScreen extends StatelessWidget {
  const QBankScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('প্রশ্ন ব্যাংক', style: GoogleFonts.hindSiliguri()),
      ),
      body: Center(
        child: Text(
          'শীঘ্রই আসছে',
          style: GoogleFonts.hindSiliguri(),
        ),
      ),
    );
  }
}
