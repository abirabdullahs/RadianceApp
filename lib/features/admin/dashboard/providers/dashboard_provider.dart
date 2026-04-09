import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/dashboard_repository.dart';

final adminDashboardProvider =
    FutureProvider.autoDispose<AdminDashboardData>((ref) {
  return DashboardRepository().load();
});
