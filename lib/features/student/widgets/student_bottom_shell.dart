import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/i18n/app_localizations.dart';
import '../../notifications/providers/unread_notifications_provider.dart';
import '../community/providers/community_unread_provider.dart';

/// Bottom nav: Home → Courses → Community → Notifications → Profile (menu).
class StudentBottomShell extends ConsumerWidget {
  const StudentBottomShell({
    super.key,
    required this.location,
    required this.child,
  });

  final String location;
  final Widget child;

  int _selectedIndex() {
    if (location.startsWith('/student/notifications')) return 3;
    if (location.startsWith('/student/community')) return 2;
    if (location.startsWith('/student/courses')) return 1;
    if (location.startsWith('/student/menu')) return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final unreadNotif = ref.watch(unreadNotificationCountProvider).maybeWhen(
          data: (v) => v,
          orElse: () => 0,
        );
    final unreadChat = ref.watch(communityUnreadGroupsCountProvider).maybeWhen(
          data: (v) => v,
          orElse: () => 0,
        );
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex(),
        onDestinationSelected: (index) {
          switch (index) {
            case 0:
              if (location != '/student') {
                context.go('/student');
              }
              break;
            case 1:
              if (!location.startsWith('/student/courses')) {
                context.go('/student/courses');
              }
              break;
            case 2:
              if (!location.startsWith('/student/community')) {
                context.go('/student/community');
              }
              break;
            case 3:
              if (!location.startsWith('/student/notifications')) {
                context.go('/student/notifications');
              }
              break;
            case 4:
              if (!location.startsWith('/student/menu')) {
                context.go('/student/menu');
              }
              break;
          }
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: l10n.t('home'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.school_outlined),
            selectedIcon: const Icon(Icons.school),
            label: l10n.t('courses'),
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: unreadChat > 0,
              label: unreadChat > 9
                  ? const Text('9+', style: TextStyle(fontSize: 10))
                  : Text('$unreadChat', style: const TextStyle(fontSize: 10)),
              child: const Icon(Icons.chat_bubble_outline),
            ),
            selectedIcon: Badge(
              isLabelVisible: unreadChat > 0,
              label: unreadChat > 9
                  ? const Text('9+', style: TextStyle(fontSize: 10))
                  : Text('$unreadChat', style: const TextStyle(fontSize: 10)),
              child: const Icon(Icons.chat_bubble),
            ),
            label: l10n.t('chat'),
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: unreadNotif > 0,
              label: unreadNotif > 9
                  ? const Text('9+', style: TextStyle(fontSize: 10))
                  : Text('$unreadNotif', style: const TextStyle(fontSize: 10)),
              child: const Icon(Icons.notifications_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: unreadNotif > 0,
              label: unreadNotif > 9
                  ? const Text('9+', style: TextStyle(fontSize: 10))
                  : Text('$unreadNotif', style: const TextStyle(fontSize: 10)),
              child: const Icon(Icons.notifications),
            ),
            label: l10n.t('notification'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: l10n.t('profile'),
          ),
        ],
      ),
    );
  }
}
