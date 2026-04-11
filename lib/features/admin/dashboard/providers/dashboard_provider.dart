import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/dashboard_repository.dart';

/// Optional course filter for revenue + attendance trend charts (null = all).
final adminChartCourseIdProvider = StateProvider<String?>((ref) => null);

final adminDashboardProvider =
    FutureProvider.autoDispose<AdminDashboardData>((ref) {
  final courseId = ref.watch(adminChartCourseIdProvider);
  return DashboardRepository().load(chartCourseId: courseId);
});
