import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/profile_role_notifier.dart';
import '../../core/constants.dart';
import '../../features/notifications/providers/unread_notifications_provider.dart';

/// Bell icon + unread badge; opens notifications for the current role.
class NotificationAppBarAction extends ConsumerWidget {
  const NotificationAppBarAction({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadNotificationCountProvider);
    final n = unread.maybeWhen(data: (c) => c, orElse: () => 0);
    return IconButton(
      tooltip: 'নোটিফিকেশন',
      icon: Badge(
        isLabelVisible: n > 0,
        backgroundColor: Theme.of(context).colorScheme.error,
        label: n > 9
            ? const Text('9+', style: TextStyle(fontSize: 10))
            : Text('$n', style: const TextStyle(fontSize: 10)),
        child: const Icon(Icons.notifications_outlined),
      ),
      onPressed: () {
        final role = effectiveRoleFromSession();
        if (role == kRoleAdmin) {
          context.push('/admin/notifications');
        } else {
          context.push('/student/notifications');
        }
      },
    );
  }
}
