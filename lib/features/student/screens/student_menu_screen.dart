import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../widgets/student_drawer.dart';

class StudentMenuScreen extends StatelessWidget {
  const StudentMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('মেনু', style: GoogleFonts.hindSiliguri()),
      ),
      body: const StudentMenuContent(closeFirst: false),
    );
  }
}
