import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/auth_metadata.dart';
import '../core/constants.dart';
import '../core/supabase_client.dart';
import '../features/admin/courses/screens/admin_course_detail_screen.dart';
import '../features/admin/courses/screens/admin_courses_screen.dart';
import '../features/admin/attendance/screens/attendance_hub_screen.dart';
import '../features/admin/attendance/screens/attendance_taking_screen.dart';
import '../features/admin/dashboard/screens/admin_dashboard_screen.dart';
import '../features/admin/payments/screens/add_payment_screen.dart';
import '../features/admin/payments/screens/admin_payments_hub_screen.dart';
import '../features/admin/exams/screens/admin_exam_detail_screen.dart';
import '../features/admin/exams/screens/admin_exam_editor_screen.dart';
import '../features/admin/exams/screens/admin_exams_list_screen.dart';
import '../features/admin/students/screens/admin_student_profile_screen.dart';
import '../features/admin/students/screens/admin_students_list_screen.dart';
import '../features/admin/students/screens/add_student_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/splash_screen.dart';
import '../features/home/screens/public_home_screen.dart';
import '../features/admin/cms/admin_home_cms_screen.dart';
import '../features/student/attendance/student_attendance_screen.dart';
import '../features/student/community/screens/community_chat_screen.dart';
import '../features/student/community/screens/community_groups_screen.dart';
import '../features/student/courses/student_course_detail_screen.dart';
import '../features/student/courses/student_courses_screen.dart';
import '../features/student/exams/screens/student_exam_take_screen.dart';
import '../features/student/exams/screens/student_exams_list_screen.dart';
import '../features/student/home/student_dashboard_screen.dart';
import '../features/student/notes/chapter_notes_screen.dart';
import '../features/student/payments/student_payments_screen.dart';
import '../features/student/results/student_results_screen.dart';
import '../features/student/screens/student_route_screens.dart';

/// Notifies [GoRouter] when Supabase session changes (login, logout, refresh).
final class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier() {
    supabaseClient.auth.onAuthStateChange.listen((_) => notifyListeners());
  }
}

final _authRefreshNotifier = _AuthRefreshNotifier();

/// App navigation: splash, public home, auth, role-based admin vs student stacks.
///
/// Role is read from [User.appMetadata] / [User.userMetadata] via
/// [roleFromSupabaseMetadata] (e.g. `role: "admin"` | `"student"`).
final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  refreshListenable: _authRefreshNotifier,
  redirect: _redirect,
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => const PublicHomeScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),

    // --- Admin ---
    GoRoute(
      path: '/admin',
      builder: (context, state) => const AdminDashboardScreen(),
    ),
    GoRoute(
      path: '/admin/courses',
      builder: (context, state) => const AdminCoursesScreen(),
    ),
    GoRoute(
      path: '/admin/courses/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return AdminCourseDetailScreen(courseId: id);
      },
    ),
    GoRoute(
      path: '/admin/students',
      builder: (context, state) => const AdminStudentsScreen(),
    ),
    GoRoute(
      path: '/admin/students/add',
      builder: (context, state) => const AddStudentScreen(),
    ),
    GoRoute(
      path: '/admin/students/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return StudentProfileScreen(studentId: id);
      },
    ),
    GoRoute(
      path: '/admin/payments/add',
      builder: (context, state) => const AddPaymentScreen(),
    ),
    GoRoute(
      path: '/admin/payments',
      builder: (context, state) => const AdminPaymentsScreen(),
    ),
    GoRoute(
      path: '/admin/attendance/:courseId/:date',
      builder: (context, state) {
        final courseId = state.pathParameters['courseId']!;
        final dateStr = state.pathParameters['date']!;
        final parsed = DateTime.tryParse(dateStr);
        final date = parsed != null
            ? DateTime.utc(parsed.year, parsed.month, parsed.day)
            : DateTime.utc(
                DateTime.now().year,
                DateTime.now().month,
                DateTime.now().day,
              );
        return AttendanceTakingScreen(courseId: courseId, date: date);
      },
    ),
    GoRoute(
      path: '/admin/attendance',
      builder: (context, state) => const AttendanceScreen(),
    ),
    GoRoute(
      path: '/admin/exams/new',
      builder: (context, state) => const AdminExamEditorScreen(),
    ),
    GoRoute(
      path: '/admin/exams/:examId',
      builder: (context, state) {
        final id = state.pathParameters['examId']!;
        return AdminExamDetailScreen(examId: id);
      },
    ),
    GoRoute(
      path: '/admin/exams',
      builder: (context, state) => const AdminExamsScreen(),
    ),
    GoRoute(
      path: '/admin/cms',
      builder: (context, state) => const AdminHomeCmsScreen(),
    ),

    // --- Student ---
    GoRoute(
      path: '/student',
      builder: (context, state) => const StudentDashboardScreen(),
    ),
    GoRoute(
      path: '/student/courses',
      builder: (context, state) => const StudentCoursesScreen(),
    ),
    GoRoute(
      path: '/student/courses/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return CourseDetailScreen(courseId: id);
      },
    ),
    GoRoute(
      path: '/student/notes/:chapterId',
      builder: (context, state) {
        final chapterId = state.pathParameters['chapterId']!;
        return NotesScreen(chapterId: chapterId);
      },
    ),
    GoRoute(
      path: '/student/exams',
      builder: (context, state) => const StudentExamsScreen(),
    ),
    GoRoute(
      path: '/student/exams/:id/take',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return ExamTakingScreen(examId: id);
      },
    ),
    GoRoute(
      path: '/student/results',
      builder: (context, state) => const StudentResultsScreen(),
    ),
    GoRoute(
      path: '/student/payments',
      builder: (context, state) => const StudentPaymentsScreen(),
    ),
    GoRoute(
      path: '/student/attendance',
      builder: (context, state) => const StudentAttendanceScreen(),
    ),
    GoRoute(
      path: '/student/community/:groupId',
      builder: (context, state) {
        final groupId = state.pathParameters['groupId']!;
        final name = state.uri.queryParameters['name'] ?? 'গ্রুপ';
        return CommunityChatScreen(groupId: groupId, groupName: name);
      },
    ),
    GoRoute(
      path: '/student/community',
      builder: (context, state) => const CommunityScreen(),
    ),
    GoRoute(
      path: '/student/qbank',
      builder: (context, state) => const QBankScreen(),
    ),
  ],
);

String? _redirect(BuildContext context, GoRouterState state) {
  final path = state.uri.path;
  final session = supabaseClient.auth.currentSession;
  final role = roleFromSupabaseMetadata(session?.user);

  final onLogin = path == '/login';
  final onSplash = path == '/';
  final onAdmin = path.startsWith('/admin');
  final onStudent = path.startsWith('/student');

  if (onLogin) {
    if (session == null) return null;
    if (role == kRoleAdmin) return '/admin';
    if (role == kRoleStudent) return '/student';
    return '/home';
  }

  if (onSplash) return null;

  if (onAdmin) {
    if (session == null) return '/login';
    if (role != kRoleAdmin) {
      if (role == kRoleStudent) return '/student';
      return '/home';
    }
    return null;
  }

  if (onStudent) {
    if (session == null) return '/login';
    if (role != kRoleStudent) {
      if (role == kRoleAdmin) return '/admin';
      return '/home';
    }
    return null;
  }

  return null;
}
