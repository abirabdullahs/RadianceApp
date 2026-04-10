import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/widgets/theme_picker_sheet.dart';
import '../../auth/providers/auth_provider.dart' show signInProvider;
import 'admin_drawer.dart';

/// At this width and above: [NavigationRail] + no drawer.
const double kAdminWideBreakpoint = 900;

/// At this width and above: extended [NavigationRail] with text labels.
const double kAdminRailExtendedBreakpoint = 1100;

/// Max content width on wide layouts (centered).
const double kAdminMaxContentWidth = 1400;

/// Grid columns for admin course cards by available width.
int adminCourseGridCrossAxisCount(double width) {
  if (width >= 1200) return 4;
  if (width >= 800) return 3;
  return 2;
}

/// Selected index for [NavigationRail] from current [path] (longest prefix wins).
int adminNavIndexForPath(String path) {
  if (path == '/admin' || path == '/admin/') return 0;
  const prefixes = <String, int>{
    '/admin/courses': 1,
    '/admin/students': 2,
    '/admin/payments': 3,
    '/admin/attendance': 4,
    '/admin/exams': 5,
    '/admin/qbank': 6,
    '/admin/cms': 7,
    '/admin/course-chats': 8,
    '/admin/doubts': 9,
  };
  var bestIdx = 0;
  var bestLen = 0;
  for (final e in prefixes.entries) {
    if (path.startsWith(e.key) && e.key.length > bestLen) {
      bestLen = e.key.length;
      bestIdx = e.value;
    }
  }
  return bestIdx;
}

const _kAdminNavRoutes = <String>[
  '/admin',
  '/admin/courses',
  '/admin/students',
  '/admin/payments',
  '/admin/attendance',
  '/admin/exams',
  '/admin/qbank',
  '/admin/cms',
  '/admin/course-chats',
  '/admin/doubts',
];

/// Admin shell: **narrow** = drawer + app bar; **wide** = permanent [NavigationRail] + app bar, optional centered max width.
class AdminResponsiveScaffold extends ConsumerWidget {
  const AdminResponsiveScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.bottom,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.constrainBodyWidth = true,
    this.resizeToAvoidBottomInset = true,
    this.toolbarHeight,
  });

  final Widget title;
  final Widget body;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;

  /// When true (default), wide layout centers body with [kAdminMaxContentWidth]. Set false for full-bleed (chat, attendance).
  final bool constrainBodyWidth;

  /// Passed to underlying [Scaffold]s (important for chat input + keyboard).
  final bool resizeToAvoidBottomInset;

  /// Optional [AppBar.toolbarHeight] (e.g. multi-line title on attendance).
  final double? toolbarHeight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = MediaQuery.sizeOf(context).width;
    final wide = w >= kAdminWideBreakpoint;
    final extendedRail = w >= kAdminRailExtendedBreakpoint;

    if (!wide) {
      return Scaffold(
        resizeToAvoidBottomInset: resizeToAvoidBottomInset,
        drawer: const AdminDrawer(),
        appBar: AppBar(
          toolbarHeight: toolbarHeight,
          leading: const AppBarDrawerLeading(),
          automaticallyImplyLeading: false,
          leadingWidth: leadingWidthForDrawer(context),
          title: title,
          actions: [
            ...(actions ?? const <Widget>[]),
            const AppBarDrawerAction(),
          ],
          bottom: bottom,
        ),
        floatingActionButton: floatingActionButton,
        floatingActionButtonLocation:
            floatingActionButtonLocation ?? FloatingActionButtonLocation.endFloat,
        body: body,
      );
    }

    final path = GoRouterState.of(context).uri.path;
    final selectedIndex = adminNavIndexForPath(path);

    Widget content = body;
    if (constrainBodyWidth) {
      content = Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kAdminMaxContentWidth),
          child: body,
        ),
      );
    }

    return Scaffold(
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AdminNavigationRailColumn(
            extended: extendedRail,
            selectedIndex: selectedIndex,
          ),
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(
            child: Scaffold(
              resizeToAvoidBottomInset: resizeToAvoidBottomInset,
              appBar: AppBar(
                toolbarHeight: toolbarHeight,
                automaticallyImplyLeading: false,
                title: title,
                actions: actions,
                bottom: bottom,
              ),
              floatingActionButton: floatingActionButton,
              floatingActionButtonLocation:
                  floatingActionButtonLocation ?? FloatingActionButtonLocation.endFloat,
              body: content,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminNavigationRailColumn extends ConsumerWidget {
  const _AdminNavigationRailColumn({
    required this.extended,
    required this.selectedIndex,
  });

  final bool extended;
  final int selectedIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.surfaceContainerHighest,
      child: SizedBox(
        width: extended ? 240 : 72,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Radiance',
                  style: GoogleFonts.hindSiliguri(
                    fontWeight: FontWeight.w800,
                    fontSize: extended ? 18 : 14,
                    color: scheme.primary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _AdminNavTile(
                    selected: selectedIndex == 0,
                    extended: extended,
                    icon: Icons.dashboard_outlined,
                    selectedIcon: Icons.dashboard,
                    label: 'ড্যাশবোর্ড',
                    onTap: () => context.go(_kAdminNavRoutes[0]),
                  ),
                  _AdminNavTile(
                    selected: selectedIndex == 1,
                    extended: extended,
                    icon: Icons.school_outlined,
                    selectedIcon: Icons.school,
                    label: 'কোর্স',
                    onTap: () => context.go(_kAdminNavRoutes[1]),
                  ),
                  _AdminNavTile(
                    selected: selectedIndex == 2,
                    extended: extended,
                    icon: Icons.people_outline,
                    selectedIcon: Icons.people,
                    label: 'শিক্ষার্থী',
                    onTap: () => context.go(_kAdminNavRoutes[2]),
                  ),
                  _AdminNavTile(
                    selected: selectedIndex == 3,
                    extended: extended,
                    icon: Icons.payment_outlined,
                    selectedIcon: Icons.payment,
                    label: 'পেমেন্ট',
                    onTap: () => context.go(_kAdminNavRoutes[3]),
                  ),
                  _AdminNavTile(
                    selected: selectedIndex == 4,
                    extended: extended,
                    icon: Icons.event_available_outlined,
                    selectedIcon: Icons.event_available,
                    label: 'উপস্থিতি',
                    onTap: () => context.go(_kAdminNavRoutes[4]),
                  ),
                  _AdminNavTile(
                    selected: selectedIndex == 5,
                    extended: extended,
                    icon: Icons.quiz_outlined,
                    selectedIcon: Icons.quiz,
                    label: 'পরীক্ষা',
                    onTap: () => context.go(_kAdminNavRoutes[5]),
                  ),
                  _AdminNavTile(
                    selected: selectedIndex == 6,
                    extended: extended,
                    icon: Icons.psychology_outlined,
                    selectedIcon: Icons.psychology,
                    label: 'প্রশ্নব্যাংক',
                    onTap: () => context.go(_kAdminNavRoutes[6]),
                  ),
                  _AdminNavTile(
                    selected: selectedIndex == 7,
                    extended: extended,
                    icon: Icons.web_outlined,
                    selectedIcon: Icons.web,
                    label: 'হোম CMS',
                    onTap: () => context.go(_kAdminNavRoutes[7]),
                  ),
                  _AdminNavTile(
                    selected: selectedIndex == 8,
                    extended: extended,
                    icon: Icons.forum_outlined,
                    selectedIcon: Icons.forum,
                    label: 'কোর্স চ্যাট',
                    onTap: () => context.go(_kAdminNavRoutes[8]),
                  ),
                  _AdminNavTile(
                    selected: selectedIndex == 9,
                    extended: extended,
                    icon: Icons.help_outline,
                    selectedIcon: Icons.help,
                    label: 'সন্দেহ',
                    onTap: () => context.go(_kAdminNavRoutes[9]),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'থিম',
                    icon: const Icon(Icons.palette_outlined),
                    onPressed: () => showThemePickerSheet(context, ref),
                  ),
                  IconButton(
                    tooltip: 'লগআউট',
                    icon: Icon(Icons.logout, color: scheme.error),
                    onPressed: () async {
                      await ref.read(signInProvider.notifier).signOut();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminNavTile extends StatelessWidget {
  const _AdminNavTile({
    required this.selected,
    required this.extended,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final bool extended;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ic = selected ? selectedIcon : icon;
    if (!extended) {
      return Tooltip(
        message: label,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Center(
              child: Icon(
                ic,
                color: selected ? scheme.primary : scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
    }
    return ListTile(
      dense: true,
      selected: selected,
      leading: Icon(ic, size: 22),
      title: Text(label, style: GoogleFonts.hindSiliguri(fontSize: 14)),
      onTap: onTap,
    );
  }
}
