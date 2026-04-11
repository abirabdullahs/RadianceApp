import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/community_repository.dart';

final communityRepositoryProvider = Provider<CommunityRepository>(
  (ref) => CommunityRepository(),
);

final communityUnreadGroupsCountProvider = StreamProvider<int>((ref) {
  return ref.watch(communityRepositoryProvider).watchUnreadGroupsCount();
});
