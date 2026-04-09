import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../repositories/attendance_repository.dart';

part 'attendance_providers.g.dart';

@Riverpod(keepAlive: true)
AttendanceRepository attendanceRepository(AttendanceRepositoryRef ref) {
  return AttendanceRepository();
}
