import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/theme.dart';

/// Placeholder until full admin course editor exists.
class AdminCourseDetailScreen extends StatelessWidget {
  const AdminCourseDetailScreen({super.key, required this.courseId});

  final String courseId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'কোর্স',
          style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'কোর্স আইডি: $courseId\n(বিস্তারিত শীঘ্রই)',
            textAlign: TextAlign.center,
            style: GoogleFonts.hindSiliguri(
              fontSize: 16,
              color: AppTheme.primary,
            ),
          ),
        ),
      ),
    );
  }
}
