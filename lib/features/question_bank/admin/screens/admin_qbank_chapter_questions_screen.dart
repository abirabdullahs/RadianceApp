import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../features/admin/widgets/admin_responsive_scaffold.dart';
import '../../repositories/qbank_repository.dart';
import '../../providers/qbank_providers.dart';

class AdminQbankChapterQuestionsScreen extends ConsumerStatefulWidget {
  const AdminQbankChapterQuestionsScreen({
    super.key,
    required this.chapterId,
    this.chapterBn,
    this.subjectBn,
  });

  final String chapterId;
  final String? chapterBn;
  final String? subjectBn;

  @override
  ConsumerState<AdminQbankChapterQuestionsScreen> createState() =>
      _AdminQbankChapterQuestionsScreenState();
}

class _AdminQbankChapterQuestionsScreenState
    extends ConsumerState<AdminQbankChapterQuestionsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  String? _difficulty;
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chapter = widget.chapterBn ?? 'অধ্যায়';
    final subject = widget.subjectBn ?? '';
    return AdminResponsiveScaffold(
      title: Text('$chapter প্রশ্ন', style: GoogleFonts.hindSiliguri()),
      bottom: TabBar(
        controller: _tab,
        tabs: [
          Tab(text: 'MCQ', icon: const Icon(Icons.check_circle_outline)),
          Tab(text: 'CQ', icon: const Icon(Icons.menu_book_outlined)),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'JSON Import',
          onPressed: () async {
            final ok = await context.push('/admin/qbank/chapter/${widget.chapterId}/import-json');
            if (ok == true) {
              ref.invalidate(qbankMcqQuestionsProvider(_query));
              ref.invalidate(qbankCqQuestionsProvider(_query));
            }
          },
          icon: const Icon(Icons.upload_file),
        ),
        IconButton(
          tooltip: 'রিফ্রেশ',
          onPressed: () {
            ref.invalidate(qbankMcqQuestionsProvider(_query));
            ref.invalidate(qbankCqQuestionsProvider(_query));
          },
          icon: const Icon(Icons.refresh),
        ),
      ],
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    subject.isEmpty ? chapter : '$subject · $chapter',
                    style: GoogleFonts.hindSiliguri(fontSize: 14),
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<String?>(
                  value: _difficulty,
                  hint: Text('কঠিনতা', style: GoogleFonts.hindSiliguri()),
                  items: const [
                    DropdownMenuItem<String?>(value: null, child: Text('সব')),
                    DropdownMenuItem<String?>(value: 'easy', child: Text('সহজ')),
                    DropdownMenuItem<String?>(value: 'medium', child: Text('মধ্যম')),
                    DropdownMenuItem<String?>(value: 'hard', child: Text('কঠিন')),
                  ],
                  onChanged: (v) => setState(() => _difficulty = v),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'প্রশ্ন টেক্সট দিয়ে ফিল্টার',
                hintStyle: GoogleFonts.hindSiliguri(),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => setState(_searchCtrl.clear),
                ),
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _McqList(query: _query, textFilter: _searchCtrl.text.trim()),
                _CqList(query: _query, textFilter: _searchCtrl.text.trim()),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddTypeSheet(context),
        icon: const Icon(Icons.add),
        label: Text('প্রশ্ন যোগ', style: GoogleFonts.hindSiliguri()),
      ),
    );
  }

  QbankQuestionQuery get _query => QbankQuestionQuery(
        chapterId: widget.chapterId,
        difficulty: _difficulty,
      );

  void _showAddTypeSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.check_circle_outline),
              title: Text('নতুন MCQ', style: GoogleFonts.hindSiliguri()),
              onTap: () {
                Navigator.pop(context);
                context
                    .push('/admin/qbank/chapter/${widget.chapterId}/add-mcq')
                    .then((value) {
                  if (value == true) {
                    ref.invalidate(qbankMcqQuestionsProvider(_query));
                  }
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.menu_book_outlined),
              title: Text('নতুন CQ', style: GoogleFonts.hindSiliguri()),
              onTap: () {
                Navigator.pop(context);
                context
                    .push('/admin/qbank/chapter/${widget.chapterId}/add-cq')
                    .then((value) {
                  if (value == true) {
                    ref.invalidate(qbankCqQuestionsProvider(_query));
                  }
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _McqList extends ConsumerWidget {
  const _McqList({required this.query, required this.textFilter});

  final QbankQuestionQuery query;
  final String textFilter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(qbankMcqQuestionsProvider(query));
    return async.when(
      data: (items) {
        final filtered = items.where((q) {
          if (textFilter.isEmpty) return true;
          final t = textFilter.toLowerCase();
          return q.questionText.toLowerCase().contains(t);
        }).toList();
        if (filtered.isEmpty) {
          return Center(child: Text('কোনো MCQ পাওয়া যায়নি', style: GoogleFonts.hindSiliguri()));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemBuilder: (context, i) {
            final q = filtered[i];
            return Card(
              child: ListTile(
                title: Text(
                  q.questionText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.hindSiliguri(),
                ),
                subtitle: Text(
                  '${q.difficulty} · ${q.source ?? 'custom'} · ${q.boardYear ?? '-'}',
                  style: GoogleFonts.nunito(fontSize: 12),
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (v) async {
                    if (v == 'edit') {
                      final ok = await context.push(
                        '/admin/qbank/chapter/${query.chapterId}/edit-mcq/${q.id}',
                      );
                      if (ok == true) {
                        ref.invalidate(qbankMcqQuestionsProvider(query));
                      }
                    } else if (v == 'delete') {
                      final confirm = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('Delete'),
                              content: const Text('এই MCQ মুছবেন?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text('Cancel'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          ) ??
                          false;
                      if (confirm) {
                        await QBankRepository().deleteMcq(q.id);
                        ref.invalidate(qbankMcqQuestionsProvider(query));
                      }
                    } else if (v == 'preview' && context.mounted) {
                      await showDialog<void>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('MCQ Preview'),
                          content: SingleChildScrollView(
                            child: Text(
                              '${q.questionText}\n\nA) ${q.optionA}\nB) ${q.optionB}\nC) ${q.optionC}\nD) ${q.optionD}\n\nCorrect: ${q.correctOption}\n\n${q.explanation ?? ''}',
                              style: GoogleFonts.hindSiliguri(),
                            ),
                          ),
                        ),
                      );
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'preview', child: Text('Preview', style: GoogleFonts.hindSiliguri())),
                    PopupMenuItem(value: 'edit', child: Text('Edit', style: GoogleFonts.hindSiliguri())),
                    PopupMenuItem(value: 'delete', child: Text('Delete', style: GoogleFonts.hindSiliguri())),
                  ],
                ),
              ),
            );
          },
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemCount: filtered.length,
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('MCQ load error: $e')),
    );
  }
}

class _CqList extends ConsumerWidget {
  const _CqList({required this.query, required this.textFilter});

  final QbankQuestionQuery query;
  final String textFilter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(qbankCqQuestionsProvider(query));
    return async.when(
      data: (items) {
        final filtered = items.where((q) {
          if (textFilter.isEmpty) return true;
          final t = textFilter.toLowerCase();
          return q.stemText.toLowerCase().contains(t) ||
              q.gaText.toLowerCase().contains(t) ||
              q.ghaText.toLowerCase().contains(t);
        }).toList();
        if (filtered.isEmpty) {
          return Center(child: Text('কোনো CQ পাওয়া যায়নি', style: GoogleFonts.hindSiliguri()));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemBuilder: (context, i) {
            final q = filtered[i];
            return Card(
              child: ListTile(
                title: Text(
                  q.stemText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.hindSiliguri(),
                ),
                subtitle: Text(
                  '${q.difficulty} · ${q.source ?? 'custom'} · ${q.boardYear ?? '-'}',
                  style: GoogleFonts.nunito(fontSize: 12),
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (v) async {
                    if (v == 'edit') {
                      final ok = await context.push(
                        '/admin/qbank/chapter/${query.chapterId}/edit-cq/${q.id}',
                      );
                      if (ok == true) {
                        ref.invalidate(qbankCqQuestionsProvider(query));
                      }
                    } else if (v == 'delete') {
                      final confirm = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('Delete'),
                              content: const Text('এই CQ মুছবেন?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text('Cancel'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          ) ??
                          false;
                      if (confirm) {
                        await QBankRepository().deleteCq(q.id);
                        ref.invalidate(qbankCqQuestionsProvider(query));
                      }
                    } else if (v == 'preview' && context.mounted) {
                      await showDialog<void>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('CQ Preview'),
                          content: SingleChildScrollView(
                            child: Text(
                              'উদ্দীপক:\n${q.stemText}\n\nগ (${q.gaMarks}): ${q.gaText}\nউত্তর: ${q.gaAnswer ?? '-'}\n\nঘ (${q.ghaMarks}): ${q.ghaText}\nউত্তর: ${q.ghaAnswer ?? '-'}',
                              style: GoogleFonts.hindSiliguri(),
                            ),
                          ),
                        ),
                      );
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'preview', child: Text('Preview', style: GoogleFonts.hindSiliguri())),
                    PopupMenuItem(value: 'edit', child: Text('Edit', style: GoogleFonts.hindSiliguri())),
                    PopupMenuItem(value: 'delete', child: Text('Delete', style: GoogleFonts.hindSiliguri())),
                  ],
                ),
              ),
            );
          },
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemCount: filtered.length,
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('CQ load error: $e')),
    );
  }
}
