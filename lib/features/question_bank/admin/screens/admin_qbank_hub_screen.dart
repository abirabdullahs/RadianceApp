import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../features/admin/widgets/admin_responsive_scaffold.dart';
import '../../providers/qbank_providers.dart';
import '../../repositories/qbank_repository.dart';
import '../../../../shared/models/qbank_models.dart';

class AdminQBankHubScreen extends ConsumerStatefulWidget {
  const AdminQBankHubScreen({super.key});

  @override
  ConsumerState<AdminQBankHubScreen> createState() => _AdminQBankHubScreenState();
}

class _AdminQBankHubScreenState extends ConsumerState<AdminQBankHubScreen> {
  String? _selectedSessionId;

  @override
  Widget build(BuildContext context) {
    final sessionsAsync = ref.watch(qbankSessionsProvider);

    return AdminResponsiveScaffold(
      title: Text('প্রশ্নব্যাংক', style: GoogleFonts.hindSiliguri()),
      actions: [
        IconButton(
          tooltip: 'রিফ্রেশ',
          onPressed: () => ref.invalidate(qbankSessionsProvider),
          icon: const Icon(Icons.refresh),
        ),
      ],
      body: sessionsAsync.when(
        data: (sessions) {
          if (sessions.isEmpty) {
            return Center(
              child: Text('কোনো সেশন পাওয়া যায়নি', style: GoogleFonts.hindSiliguri()),
            );
          }
          _selectedSessionId ??= sessions.first.id;
          final selected = sessions.firstWhere(
            (s) => s.id == _selectedSessionId,
            orElse: () => sessions.first,
          );
          return _HubBody(
            sessions: sessions,
            selectedSession: selected,
            onSessionChanged: (v) => setState(() => _selectedSessionId = v),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text('লোড করা যায়নি: $e', style: GoogleFonts.hindSiliguri()),
          ),
        ),
      ),
    );
  }
}

class _HubBody extends ConsumerWidget {
  const _HubBody({
    required this.sessions,
    required this.selectedSession,
    required this.onSessionChanged,
  });

  final List<QbankSession> sessions;
  final QbankSession selectedSession;
  final ValueChanged<String?> onSessionChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjectsAsync = ref.watch(qbankSubjectsProvider(selectedSession.id));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(qbankSessionsProvider);
        ref.invalidate(qbankSubjectsProvider(selectedSession.id));
        await ref.read(qbankSubjectsProvider(selectedSession.id).future);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: selectedSession.id,
                  decoration: InputDecoration(
                    labelText: 'সেশন',
                    labelStyle: GoogleFonts.hindSiliguri(),
                    border: const OutlineInputBorder(),
                  ),
                  items: sessions
                      .map(
                        (s) => DropdownMenuItem<String>(
                          value: s.id,
                          child: Text('${s.nameBn} (${s.name})', style: GoogleFonts.hindSiliguri()),
                        ),
                      )
                      .toList(),
                  onChanged: onSessionChanged,
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () => _showAddSubjectDialog(context, ref),
                icon: const Icon(Icons.add),
                label: Text('বিষয় যোগ', style: GoogleFonts.hindSiliguri()),
              ),
            ],
          ),
          const SizedBox(height: 16),
          subjectsAsync.when(
            data: (subjects) {
              if (subjects.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('এই সেশনে কোনো বিষয় নেই', style: GoogleFonts.hindSiliguri()),
                  ),
                );
              }
              return Column(
                children: subjects.map((s) => _SubjectTile(subject: s)).toList(),
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(12),
              child: Text('বিষয় লোড হয়নি: $e', style: GoogleFonts.hindSiliguri()),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddSubjectDialog(BuildContext context, WidgetRef ref) async {
    final nameCtl = TextEditingController();
    final nameBnCtl = TextEditingController();
    final orderCtl = TextEditingController(text: '0');
    final formKey = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('বিষয় যোগ করুন', style: GoogleFonts.hindSiliguri()),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtl,
                decoration: const InputDecoration(labelText: 'Name (EN)'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: nameBnCtl,
                decoration: InputDecoration(labelText: 'বাংলা নাম', labelStyle: GoogleFonts.hindSiliguri()),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: orderCtl,
                decoration: const InputDecoration(labelText: 'Display order'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              try {
                await QBankRepository().addSubject(
                  sessionId: selectedSession.id,
                  name: nameCtl.text,
                  nameBn: nameBnCtl.text,
                  displayOrder: int.tryParse(orderCtl.text.trim()) ?? 0,
                );
                if (ctx.mounted) Navigator.pop(ctx, true);
              } catch (e) {
                if (!ctx.mounted) return;
                ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Failed: $e')));
              }
            },
            child: Text('Save', style: GoogleFonts.nunito()),
          ),
        ],
      ),
    );
    nameCtl.dispose();
    nameBnCtl.dispose();
    orderCtl.dispose();
    if (ok == true) {
      ref.invalidate(qbankSubjectsProvider(selectedSession.id));
    }
  }
}

class _SubjectTile extends ConsumerWidget {
  const _SubjectTile({required this.subject});

  final QbankSubject subject;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chaptersAsync = ref.watch(qbankChaptersProvider(subject.id));
    final statsAsync = ref.watch(qbankChapterStatsProvider(subject.id));

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        title: Text(subject.nameBn, style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600)),
        subtitle: Text(subject.name, style: GoogleFonts.nunito(fontSize: 12)),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: [
          Row(
            children: [
              const Spacer(),
              TextButton.icon(
                onPressed: () => _showAddChapterDialog(context, ref),
                icon: const Icon(Icons.add, size: 18),
                label: Text('অধ্যায় যোগ', style: GoogleFonts.hindSiliguri()),
              ),
            ],
          ),
          chaptersAsync.when(
            data: (chapters) {
              if (chapters.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text('কোনো অধ্যায় নেই', style: GoogleFonts.hindSiliguri()),
                );
              }
              final stats = <String, QbankChapterStats>{
                for (final s in statsAsync.value ?? const <QbankChapterStats>[]) s.chapterId: s,
              };
              return Column(
                children: chapters.map((c) {
                  final st = stats[c.id];
                  final mcqCount = st?.mcqCount ?? 0;
                  final cqCount = st?.cqCount ?? 0;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(c.nameBn, style: GoogleFonts.hindSiliguri()),
                    subtitle: Text('MCQ: $mcqCount · CQ: $cqCount', style: GoogleFonts.nunito()),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      context.push(
                        '/admin/qbank/chapter/${c.id}'
                        '?chapterBn=${Uri.encodeComponent(c.nameBn)}'
                        '&subjectBn=${Uri.encodeComponent(subject.nameBn)}',
                      );
                    },
                  );
                }).toList(),
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: CircularProgressIndicator(),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(8),
              child: Text('অধ্যায় লোড হয়নি: $e', style: GoogleFonts.hindSiliguri()),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddChapterDialog(BuildContext context, WidgetRef ref) async {
    final nameCtl = TextEditingController();
    final nameBnCtl = TextEditingController();
    final orderCtl = TextEditingController(text: '0');
    final formKey = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('অধ্যায় যোগ করুন', style: GoogleFonts.hindSiliguri()),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtl,
                decoration: const InputDecoration(labelText: 'Name (EN)'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: nameBnCtl,
                decoration: InputDecoration(labelText: 'বাংলা নাম', labelStyle: GoogleFonts.hindSiliguri()),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: orderCtl,
                decoration: const InputDecoration(labelText: 'Display order'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              try {
                await QBankRepository().addChapter(
                  subjectId: subject.id,
                  name: nameCtl.text,
                  nameBn: nameBnCtl.text,
                  displayOrder: int.tryParse(orderCtl.text.trim()) ?? 0,
                );
                if (ctx.mounted) Navigator.pop(ctx, true);
              } catch (e) {
                if (!ctx.mounted) return;
                ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Failed: $e')));
              }
            },
            child: Text('Save', style: GoogleFonts.nunito()),
          ),
        ],
      ),
    );
    nameCtl.dispose();
    nameBnCtl.dispose();
    orderCtl.dispose();
    if (ok == true) {
      ref.invalidate(qbankChaptersProvider(subject.id));
      ref.invalidate(qbankChapterStatsProvider(subject.id));
    }
  }
}
