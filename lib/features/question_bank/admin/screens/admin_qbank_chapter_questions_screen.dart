import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../features/admin/widgets/admin_responsive_scaffold.dart';
import '../../../../shared/models/qbank_models.dart';
import '../../repositories/qbank_repository.dart';

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
  /// Bumps list keys so paginated MCQ/CQ lists reload (replaces provider invalidation).
  int _listGeneration = 0;

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
            if (ok == true) setState(() => _listGeneration++);
          },
          icon: const Icon(Icons.upload_file),
        ),
        IconButton(
          tooltip: 'রিফ্রেশ',
          onPressed: () => setState(() => _listGeneration++),
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
                _McqList(
                  key: ValueKey('mcq-${widget.chapterId}-$_difficulty-$_listGeneration'),
                  chapterId: widget.chapterId,
                  difficulty: _difficulty,
                  textFilter: _searchCtrl.text.trim(),
                  onReloadRequested: () => setState(() => _listGeneration++),
                ),
                _CqList(
                  key: ValueKey('cq-${widget.chapterId}-$_difficulty-$_listGeneration'),
                  chapterId: widget.chapterId,
                  difficulty: _difficulty,
                  textFilter: _searchCtrl.text.trim(),
                  onReloadRequested: () => setState(() => _listGeneration++),
                ),
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
                  if (value == true) setState(() => _listGeneration++);
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
                  if (value == true) setState(() => _listGeneration++);
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}

const int _kAdminQbankPageSize = 50;

class _McqList extends ConsumerStatefulWidget {
  const _McqList({
    super.key,
    required this.chapterId,
    required this.difficulty,
    required this.textFilter,
    required this.onReloadRequested,
  });

  final String chapterId;
  final String? difficulty;
  final String textFilter;
  final VoidCallback onReloadRequested;

  @override
  ConsumerState<_McqList> createState() => _McqListState();
}

class _McqListState extends ConsumerState<_McqList> {
  final _scroll = ScrollController();
  final _repo = QBankRepository();
  var _items = <QbankMcq>[];
  var _offset = 0;
  var _loading = true;
  var _loadingMore = false;
  var _hasMore = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _loadFirst();
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _loadingMore || _loading || _error != null) return;
    final p = _scroll.position;
    if (!p.hasPixels) return;
    if (p.pixels > p.maxScrollExtent - 320) {
      _loadMore();
    }
  }

  Future<void> _loadFirst() async {
    setState(() {
      _loading = true;
      _error = null;
      _items = [];
      _offset = 0;
      _hasMore = true;
    });
    try {
      final batch = await _repo.getMcqQuestions(
        chapterId: widget.chapterId,
        difficulty: widget.difficulty,
        limit: _kAdminQbankPageSize,
        offset: 0,
      );
      if (!mounted) return;
      setState(() {
        _items = batch;
        _offset = batch.length;
        _hasMore = batch.length >= _kAdminQbankPageSize;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final batch = await _repo.getMcqQuestions(
        chapterId: widget.chapterId,
        difficulty: widget.difficulty,
        limit: _kAdminQbankPageSize,
        offset: _offset,
      );
      if (!mounted) return;
      setState(() {
        _items = [..._items, ...batch];
        _offset += batch.length;
        _hasMore = batch.length >= _kAdminQbankPageSize;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  List<QbankMcq> get _filtered => _items.where((q) {
        if (widget.textFilter.isEmpty) return true;
        final t = widget.textFilter.toLowerCase();
        return q.questionText.toLowerCase().contains(t);
      }).toList();

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text('MCQ load error: $_error'));
    }
    final filtered = _filtered;
    if (filtered.isEmpty) {
      return Center(child: Text('কোনো MCQ পাওয়া যায়নি', style: GoogleFonts.hindSiliguri()));
    }
    return ListView.separated(
      controller: _scroll,
      padding: const EdgeInsets.all(12),
      itemBuilder: (context, i) {
        if (i == filtered.length && _loadingMore) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
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
                    '/admin/qbank/chapter/${widget.chapterId}/edit-mcq/${q.id}',
                  );
                  if (ok == true) widget.onReloadRequested();
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
                    await _repo.deleteMcq(q.id);
                    widget.onReloadRequested();
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
      itemCount: filtered.length + (_loadingMore ? 1 : 0),
    );
  }
}

class _CqList extends ConsumerStatefulWidget {
  const _CqList({
    super.key,
    required this.chapterId,
    required this.difficulty,
    required this.textFilter,
    required this.onReloadRequested,
  });

  final String chapterId;
  final String? difficulty;
  final String textFilter;
  final VoidCallback onReloadRequested;

  @override
  ConsumerState<_CqList> createState() => _CqListState();
}

class _CqListState extends ConsumerState<_CqList> {
  final _scroll = ScrollController();
  final _repo = QBankRepository();
  var _items = <QbankCq>[];
  var _offset = 0;
  var _loading = true;
  var _loadingMore = false;
  var _hasMore = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _loadFirst();
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _loadingMore || _loading || _error != null) return;
    final p = _scroll.position;
    if (!p.hasPixels) return;
    if (p.pixels > p.maxScrollExtent - 320) {
      _loadMore();
    }
  }

  Future<void> _loadFirst() async {
    setState(() {
      _loading = true;
      _error = null;
      _items = [];
      _offset = 0;
      _hasMore = true;
    });
    try {
      final batch = await _repo.getCqQuestions(
        chapterId: widget.chapterId,
        difficulty: widget.difficulty,
        limit: _kAdminQbankPageSize,
        offset: 0,
      );
      if (!mounted) return;
      setState(() {
        _items = batch;
        _offset = batch.length;
        _hasMore = batch.length >= _kAdminQbankPageSize;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final batch = await _repo.getCqQuestions(
        chapterId: widget.chapterId,
        difficulty: widget.difficulty,
        limit: _kAdminQbankPageSize,
        offset: _offset,
      );
      if (!mounted) return;
      setState(() {
        _items = [..._items, ...batch];
        _offset += batch.length;
        _hasMore = batch.length >= _kAdminQbankPageSize;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  List<QbankCq> get _filtered => _items.where((q) {
        if (widget.textFilter.isEmpty) return true;
        final t = widget.textFilter.toLowerCase();
        return q.stemText.toLowerCase().contains(t) ||
            q.gaText.toLowerCase().contains(t) ||
            q.ghaText.toLowerCase().contains(t);
      }).toList();

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text('CQ load error: $_error'));
    }
    final filtered = _filtered;
    if (filtered.isEmpty) {
      return Center(child: Text('কোনো CQ পাওয়া যায়নি', style: GoogleFonts.hindSiliguri()));
    }
    return ListView.separated(
      controller: _scroll,
      padding: const EdgeInsets.all(12),
      itemBuilder: (context, i) {
        if (i == filtered.length && _loadingMore) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
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
                    '/admin/qbank/chapter/${widget.chapterId}/edit-cq/${q.id}',
                  );
                  if (ok == true) widget.onReloadRequested();
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
                    await _repo.deleteCq(q.id);
                    widget.onReloadRequested();
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
      itemCount: filtered.length + (_loadingMore ? 1 : 0),
    );
  }
}
