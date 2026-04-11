import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/dashboard_repository.dart';

/// Optional course filter for revenue + attendance trend charts (null = all).
final adminChartCourseIdProvider = StateProvider<String?>((ref) => null);

/// Non–autoDispose so admin home does not refetch full dashboard on every navigation.
final adminDashboardProvider = FutureProvider<AdminDashboardData>((ref) {
  final courseId = ref.watch(adminChartCourseIdProvider);
  return DashboardRepository().load(chartCourseId: courseId);
});
