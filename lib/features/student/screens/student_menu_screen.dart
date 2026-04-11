import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/i18n/app_localizations.dart';
import '../widgets/student_drawer.dart';

class StudentMenuScreen extends StatelessWidget {
  const StudentMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('profile'), style: GoogleFonts.hindSiliguri()),
      ),
      body: const StudentMenuContent(closeFirst: false),
    );
  }
}
