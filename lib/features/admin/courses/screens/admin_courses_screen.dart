import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../app/theme.dart';
import '../providers/courses_provider.dart';
import '../widgets/add_course_sheet.dart';
import '../widgets/course_card.dart';

/// Admin course list: grid, filters, search, FAB add course.
class AdminCoursesScreen extends ConsumerStatefulWidget {
  const AdminCoursesScreen({super.key});

  @override
  ConsumerState<AdminCoursesScreen> createState() =>
      _AdminCoursesScreenState();
}

class _AdminCoursesScreenState extends ConsumerState<AdminCoursesScreen> {
  final _searchController = TextEditingController();
  bool _searchOpen = false;
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<CourseListItem> _applySearch(List<CourseListItem> items) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return items;
    return items
        .where((e) => e.course.name.toLowerCase().contains(q))
        .toList();
  }

  Future<void> _openAddSheet() async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => const AddCourseSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final coursesAsync = ref.watch(coursesProvider);
    final filter = ref.read(coursesProvider.notifier).filter;

    return Scaffold(
      backgroundColor: scheme.surface,
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddSheet,
        backgroundColor: AppTheme.accent,
        foregroundColor: const Color(0xFF1A1204),
        child: const Icon(Icons.add),
      ),
      appBar: AppBar(
        title: Text(
          'কোর্স ব্যবস্থাপনা',
          style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'খুঁজুন',
            onPressed: () {
              setState(() {
                _searchOpen = !_searchOpen;
                if (!_searchOpen) {
                  _query = '';
                  _searchController.clear();
                }
              });
            },
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_searchOpen)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'কোর্সের নাম খুঁজুন…',
                  hintStyle: GoogleFonts.hindSiliguri(),
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                        ),
                  filled: true,
                  fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                ),
                style: GoogleFonts.hindSiliguri(),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChip(
                    label: 'সব',
                    selected: filter == CourseListFilter.all,
                    onTap: () => ref
                        .read(coursesProvider.notifier)
                        .setFilter(CourseListFilter.all),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'সক্রিয়',
                    selected: filter == CourseListFilter.active,
                    onTap: () => ref
                        .read(coursesProvider.notifier)
                        .setFilter(CourseListFilter.active),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'নিষ্ক্রিয়',
                    selected: filter == CourseListFilter.inactive,
                    onTap: () => ref
                        .read(coursesProvider.notifier)
                        .setFilter(CourseListFilter.inactive),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: coursesAsync.when(
              loading: () => _ShimmerCourseGrid(scheme: scheme),
              error: (e, st) => _ErrorBody(
                message: e.toString(),
                onRetry: () =>
                    ref.read(coursesProvider.notifier).refresh(),
              ),
              data: (items) {
                final visible = _applySearch(items);
                if (items.isEmpty) {
                  return _EmptyBody(
                    icon: Icons.menu_book_outlined,
                    title: 'এখনও কোনো কোর্স নেই',
                    subtitle: 'নিচের + বাটনে নতুন কোর্স যোগ করুন',
                  );
                }
                if (visible.isEmpty) {
                  return _EmptyBody(
                    icon: Icons.search_off_rounded,
                    title: 'কোনো কোর্স মেলেনি',
                    subtitle: 'অন্য কীওয়ার্ড দিয়ে খুঁজুন',
                  );
                }
                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.72,
                  ),
                  itemCount: visible.length,
                  itemBuilder: (context, i) {
                    final item = visible[i];
                    return CourseCard(
                      item: item,
                      onTap: () => context.push(
                        '/admin/courses/${item.course.id}',
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FilterChip(
      label: Text(
        label,
        style: GoogleFonts.hindSiliguri(
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppTheme.primary.withValues(alpha: 0.2),
      checkmarkColor: AppTheme.primary,
      labelStyle: TextStyle(
        color: selected ? AppTheme.primary : scheme.onSurface,
      ),
    );
  }
}

class _ShimmerCourseGrid extends StatelessWidget {
  const _ShimmerCourseGrid({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: scheme.surfaceContainerHighest,
      highlightColor: scheme.surface,
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.72,
        ),
        itemCount: 6,
        itemBuilder: (context, index) => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          ),
        ),
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: scheme.error),
            const SizedBox(height: 16),
            Text(
              'ডাটা লোড হয়নি',
              style: GoogleFonts.hindSiliguri(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.hindSiliguri(
                fontSize: 14,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(
                'আবার চেষ্টা',
                style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyBody extends StatelessWidget {
  const _EmptyBody({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: scheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.hindSiliguri(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.hindSiliguri(
                fontSize: 14,
                height: 1.4,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
