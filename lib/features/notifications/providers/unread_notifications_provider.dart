import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/notifications_repository.dart';

final notificationsRepositoryProvider = Provider<NotificationsRepository>(
  (ref) => NotificationsRepository(),
);

/// Unread in-app notification count (Realtime).
final unreadNotificationCountProvider = StreamProvider<int>((ref) {
  return ref.watch(notificationsRepositoryProvider).watchUnreadCount();
});
