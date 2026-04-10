import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/theme.dart';
import '../../../../core/supabase_client.dart';
import '../../../../shared/models/discount_rule_model.dart';
import '../../../../shared/models/enrollment_model.dart';
import '../../../../shared/models/user_model.dart';
import '../../courses/providers/courses_provider.dart';
import '../../widgets/admin_responsive_scaffold.dart';
import '../providers/payment_providers.dart';

class AdminPaymentDiscountsScreen extends ConsumerStatefulWidget {
  const AdminPaymentDiscountsScreen({super.key});

  @override
  ConsumerState<AdminPaymentDiscountsScreen> createState() =>
      _AdminPaymentDiscountsScreenState();
}

class _AdminPaymentDiscountsScreenState
    extends ConsumerState<AdminPaymentDiscountsScreen> {
  final _searchCtrl = TextEditingController();
  List<UserModel> _suggestions = [];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _searchStudents(String q) async {
    final text = q.trim();
    if (text.length < 2) {
      setState(() => _suggestions = []);
      return;
    }
    final list = await ref.read(studentRepositoryForPaymentsProvider).getStudents(
          searchQuery: text,
        );
    if (!mounted) return;
    setState(() => _suggestions = list);
  }

  Future<void> _showAddRuleDialog() async {
    final nameCtrl = TextEditingController();
    final nameBnCtrl = TextEditingController();
    final valueCtrl = TextEditingController();
    final appliesCtrl = TextEditingController(text: 'monthly');
    DiscountType type = DiscountType.percentage;
    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setD) => AlertDialog(
            title: Text('নতুন ডিসকাউন্ট রুল', style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Rule Name (EN)')),
                  TextField(controller: nameBnCtrl, decoration: const InputDecoration(labelText: 'Rule Name (BN)')),
                  DropdownButtonFormField<DiscountType>(
                    value: type,
                    items: DiscountType.values
                        .map((e) => DropdownMenuItem(value: e, child: Text(e.name)))
                        .toList(),
                    onChanged: (v) => setD(() => type = v ?? DiscountType.percentage),
                    decoration: const InputDecoration(labelText: 'Discount Type'),
                  ),
                  TextField(
                    controller: valueCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Discount Value'),
                  ),
                  TextField(controller: appliesCtrl, decoration: const InputDecoration(labelText: 'Applies To (e.g. monthly/exam)')),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('বাতিল', style: GoogleFonts.hindSiliguri())),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text('সংরক্ষণ', style: GoogleFonts.hindSiliguri())),
            ],
          ),
        ),
      );
      if (ok != true) return;
      final value = double.tryParse(valueCtrl.text.trim()) ?? -1;
      if (nameCtrl.text.trim().isEmpty || nameBnCtrl.text.trim().isEmpty || value < 0) {
        throw Exception('তথ্য সঠিক নয়');
      }
      await ref.read(paymentRepositoryProvider).addDiscountRule(
            name: nameCtrl.text,
            nameBn: nameBnCtrl.text,
            discountType: type,
            discountValue: value,
            appliesTo: appliesCtrl.text.trim().isEmpty ? 'monthly' : appliesCtrl.text.trim(),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ডিসকাউন্ট রুল যোগ হয়েছে', style: GoogleFonts.hindSiliguri())),
      );
      setState(() {});
    } finally {
      nameCtrl.dispose();
      nameBnCtrl.dispose();
      valueCtrl.dispose();
      appliesCtrl.dispose();
    }
  }

  Future<void> _showAssignDialog(UserModel student) async {
    final repo = ref.read(paymentRepositoryProvider);
    final rules = await repo.listDiscountRules(activeOnly: true);
    final enrollments = await ref.read(studentRepositoryForPaymentsProvider).getStudentEnrollments(student.id);
    final active = enrollments.where((e) => e.status == EnrollmentStatus.active).toList();
    if (active.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('এই শিক্ষার্থীর active course নেই', style: GoogleFonts.hindSiliguri())),
      );
      return;
    }
    final courseRepo = ref.read(courseRepositoryProvider);
    final courseNames = <String, String>{};
    for (final e in active) {
      try {
        final c = await courseRepo.getCourseById(e.courseId);
        courseNames[e.courseId] = c.name;
      } catch (_) {
        courseNames[e.courseId] = e.courseId;
      }
    }
    if (!mounted) return;
    String courseId = active.first.courseId;
    String? ruleId = rules.isNotEmpty ? rules.first.id : null;
    final customCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    final appliesCtrl = TextEditingController(text: 'monthly');
    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setD) => AlertDialog(
            title: Text('ছাড় অ্যাসাইন করুন', style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(student.fullNameBn, style: GoogleFonts.hindSiliguri()),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: courseId,
                    items: active
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.courseId,
                            child: Text(courseNames[e.courseId] ?? e.courseId, style: GoogleFonts.hindSiliguri()),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setD(() => courseId = v ?? courseId),
                    decoration: const InputDecoration(labelText: 'Course'),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String?>(
                    value: ruleId,
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('Custom Amount')),
                      ...rules.map(
                        (r) => DropdownMenuItem<String?>(
                          value: r.id,
                          child: Text('${r.nameBn} (${r.discountValue})', style: GoogleFonts.hindSiliguri()),
                        ),
                      ),
                    ],
                    onChanged: (v) => setD(() => ruleId = v),
                    decoration: const InputDecoration(labelText: 'Rule'),
                  ),
                  if (ruleId == null) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: customCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Custom Amount'),
                    ),
                  ],
                  const SizedBox(height: 8),
                  TextField(controller: appliesCtrl, decoration: const InputDecoration(labelText: 'Applies To')),
                  const SizedBox(height: 8),
                  TextField(controller: reasonCtrl, decoration: const InputDecoration(labelText: 'Reason')),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('বাতিল', style: GoogleFonts.hindSiliguri())),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text('অ্যাসাইন', style: GoogleFonts.hindSiliguri())),
            ],
          ),
        ),
      );
      if (ok != true) return;
      await repo.assignStudentDiscount(
        studentId: student.id,
        courseId: courseId,
        discountRuleId: ruleId,
        customAmount: ruleId == null ? (double.tryParse(customCtrl.text.trim()) ?? 0) : null,
        customReason: reasonCtrl.text.trim().isEmpty ? null : reasonCtrl.text.trim(),
        appliesTo: appliesCtrl.text.trim().isEmpty ? 'monthly' : appliesCtrl.text.trim(),
        validFrom: DateTime.now(),
        createdBy: supabaseClient.auth.currentUser?.id,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ছাড় অ্যাসাইন হয়েছে', style: GoogleFonts.hindSiliguri())),
      );
    } finally {
      customCtrl.dispose();
      reasonCtrl.dispose();
      appliesCtrl.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminResponsiveScaffold(
      title: Text('Discount Management', style: GoogleFonts.hindSiliguri()),
      actions: [
        IconButton(
          onPressed: _showAddRuleDialog,
          icon: const Icon(Icons.add),
          tooltip: 'নতুন রুল',
        ),
      ],
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _searchCtrl,
              onChanged: _searchStudents,
              decoration: InputDecoration(
                labelText: 'শিক্ষার্থী খুঁজুন (নাম/ফোন)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.cardRadius)),
                prefixIcon: const Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _suggestions.isEmpty
                  ? Center(child: Text('শিক্ষার্থী নির্বাচন করে discount assign করুন', style: GoogleFonts.hindSiliguri()))
                  : ListView.builder(
                      itemCount: _suggestions.length,
                      itemBuilder: (context, i) {
                        final s = _suggestions[i];
                        return Card(
                          child: ListTile(
                            title: Text(s.fullNameBn, style: GoogleFonts.hindSiliguri()),
                            subtitle: Text(s.phone, style: GoogleFonts.nunito()),
                            trailing: FilledButton(
                              onPressed: () => _showAssignDialog(s),
                              child: Text('Assign', style: GoogleFonts.hindSiliguri()),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
