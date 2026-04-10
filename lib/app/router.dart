import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/auth/profile_role_notifier.dart';
import '../core/constants.dart';
import '../core/supabase_client.dart';
import '../features/admin/courses/screens/admin_course_detail_screen.dart';
import '../features/admin/courses/screens/admin_courses_screen.dart';
import '../features/admin/notices/screens/admin_course_notice_screen.dart';
import '../features/admin/attendance/screens/attendance_hub_screen.dart';
import '../features/admin/attendance/screens/attendance_taking_screen.dart';
import '../features/admin/dashboard/screens/admin_dashboard_screen.dart';
import '../features/admin/payments/screens/add_payment_screen.dart';
import '../features/admin/payments/screens/admin_payment_discounts_screen.dart';
import '../features/admin/payments/screens/admin_payments_hub_screen.dart';
import '../features/admin/payments/screens/admin_payment_reports_screen.dart';
import '../features/admin/payments/screens/admin_payment_settings_screen.dart';
import '../features/admin/payments/screens/admin_payment_sms_templates_screen.dart';
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
import '../features/admin/community/screens/admin_course_chats_screen.dart';
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
import '../features/student/profile/student_edit_profile_screen.dart';
import '../features/student/results/student_results_screen.dart';
import '../features/student/screens/student_route_screens.dart';
import '../features/student/settings/student_settings_screen.dart';
import '../features/doubts/screens/doubt_chat_screen.dart';
import '../features/doubts/screens/staff_doubt_inbox_screen.dart';
import '../features/doubts/screens/student_doubts_list_screen.dart';
import '../features/doubts/screens/student_new_doubt_screen.dart';
import '../features/notifications/screens/notifications_screen.dart';

/// Notifies [GoRouter] when Supabase session changes (login, logout, refresh).
final class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier() {
    supabaseClient.auth.onAuthStateChange.listen((_) => notifyListeners());
  }
}

final _authRefreshNotifier = _AuthRefreshNotifier();

/// Refreshes [GoRouter] on auth events and when [profileRoleNotifier] loads [users.role].
final Listenable _routerRefresh =
    Listenable.merge([_authRefreshNotifier, profileRoleNotifier]);

String _withQuery(String path, String query) =>
    query.isEmpty ? path : '$path?$query';

/// App navigation: splash, public home, auth, role-based admin vs student stacks.
///
/// Role: [users.role] (cached) first, then JWT [app_metadata] / [user_metadata].
final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  refreshListenable: _routerRefresh,
  redirect: _redirect,
  errorBuilder: (context, state) => _RouteErrorScreen(state: state),
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const SplashScreen(),
    ),
    // Typo: `/students/...` — app uses singular `/student/...`
    GoRoute(
      path: '/students/doubts',
      redirect: (context, state) =>
          _withQuery('/student/doubts', state.uri.query),
    ),
    GoRoute(
      path: '/students/doubts/new',
      redirect: (context, state) =>
          _withQuery('/student/doubts/new', state.uri.query),
    ),
    GoRoute(
      path: '/students/doubts/:id',
      redirect: (context, state) => _withQuery(
        '/student/doubts/${state.pathParameters['id']}',
        state.uri.query,
      ),
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
      path: '/admin/courses/:id/notice',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        final name = state.uri.queryParameters['name'];
        return AdminCourseNoticeScreen(courseId: id, courseName: name);
      },
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
      path: '/admin/payments/edit/:id',
      builder: (context, state) =>
          AddPaymentScreen(editingPaymentId: state.pathParameters['id']!),
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
      path: '/admin/payments/discounts',
      builder: (context, state) => const AdminPaymentDiscountsScreen(),
    ),
    GoRoute(
      path: '/admin/payments/reports',
      builder: (context, state) => const AdminPaymentReportsScreen(),
    ),
    GoRoute(
      path: '/admin/payments/settings',
      builder: (context, state) => const AdminPaymentSettingsScreen(),
    ),
    GoRoute(
      path: '/admin/payments/sms-templates',
      builder: (context, state) => const AdminPaymentSmsTemplatesScreen(),
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
    GoRoute(
      path: '/admin/course-chats',
      builder: (context, state) => const AdminCourseChatsScreen(),
    ),
    GoRoute(
      path: '/admin/course-chats/:groupId',
      builder: (context, state) {
        final id = state.pathParameters['groupId']!;
        final name = state.uri.queryParameters['name'] ?? 'গ্রুপ';
        return CommunityChatScreen(groupId: id, groupName: name, useAdminShell: true);
      },
    ),
    GoRoute(
      path: '/admin/doubts',
      builder: (context, state) => const StaffDoubtInboxScreen(isAdmin: true),
    ),
    GoRoute(
      path: '/admin/doubts/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return DoubtChatScreen(doubtId: id, shell: DoubtChatShell.admin);
      },
    ),

    // --- Teacher (doubt inbox + chat) ---
    GoRoute(
      path: '/teacher',
      builder: (context, state) => const StaffDoubtInboxScreen(isAdmin: false),
    ),
    GoRoute(
      path: '/teacher/doubts/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return DoubtChatScreen(doubtId: id, shell: DoubtChatShell.teacher);
      },
    ),

    // --- Student ---
    GoRoute(
      path: '/student',
      builder: (context, state) => const StudentDashboardScreen(),
    ),
    GoRoute(
      path: '/student/notifications',
      builder: (context, state) => const NotificationsScreen(),
    ),
    // Doubt solve: literal `/student/doubts/new` must be before `/student/doubts/:id`.
    GoRoute(
      path: '/student/doubts',
      builder: (context, state) => const StudentDoubtsListScreen(),
    ),
    GoRoute(
      path: '/student/doubts/new',
      builder: (context, state) => const StudentNewDoubtScreen(),
    ),
    GoRoute(
      path: '/student/doubts/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return DoubtChatScreen(doubtId: id, shell: DoubtChatShell.student);
      },
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
    GoRoute(
      path: '/student/profile/edit',
      builder: (context, state) => const StudentEditProfileScreen(),
    ),
    GoRoute(
      path: '/student/settings',
      builder: (context, state) => const StudentSettingsScreen(),
    ),
  ],
);

String? _redirect(BuildContext context, GoRouterState state) {
  var path = state.uri.path;
  final querySuffix =
      state.uri.hasQuery ? '?${state.uri.query}' : '';

  // Trailing slash: `/admin/doubts/` → `/admin/doubts` (otherwise no match).
  if (path.length > 1 && path.endsWith('/')) {
    return '${path.substring(0, path.length - 1)}$querySuffix';
  }

  // Common typo: `/students/...` → `/student/...` (routes use singular `student`).
  if (path.startsWith('/students')) {
    path = path.replaceFirst('/students', '/student');
    return '$path$querySuffix';
  }

  final session = supabaseClient.auth.currentSession;
  final role = effectiveRoleFromSession();

  final onLogin = path == '/login';
  final onSplash = path == '/';
  final onAdmin = path.startsWith('/admin');
  final onStudent = path.startsWith('/student');
  final onTeacher = path.startsWith('/teacher');

  if (onLogin) {
    if (session == null) return null;
    if (role == kRoleAdmin) return '/admin';
    if (role == kRoleTeacher) return '/teacher';
    if (role == kRoleStudent) return '/student';
    // Session exists but role unknown (profile/RLS failed, empty JWT metadata).
    // Do not redirect to /home — that looked like "reload" and hid the login screen.
    if (role == null) return null;
    return '/home';
  }

  if (onSplash) return null;

  if (onAdmin) {
    if (session == null) return '/login';
    if (role != kRoleAdmin) {
      if (role == kRoleStudent) return '/student';
      if (role == kRoleTeacher) return '/teacher';
      return '/home';
    }
    return null;
  }

  if (onTeacher) {
    if (session == null) return '/login';
    if (role != kRoleTeacher) {
      if (role == kRoleAdmin) return '/admin';
      if (role == kRoleStudent) return '/student';
      return '/home';
    }
    return null;
  }

  if (onStudent) {
    if (session == null) return '/login';
    if (role != kRoleStudent) {
      if (role == kRoleAdmin) return '/admin';
      if (role == kRoleTeacher) return '/teacher';
      return '/home';
    }
    return null;
  }

  return null;
}

/// Shown when [GoRouter] has no matching route (wrong URL or ordering bug).
class _RouteErrorScreen extends StatelessWidget {
  const _RouteErrorScreen({required this.state});

  final GoRouterState state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final msg = state.error?.toString() ?? state.uri.toString();
    return Scaffold(
      appBar: AppBar(
        title: Text('পেজ পাওয়া যায়নি', style: GoogleFonts.hindSiliguri()),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SelectableText(
            msg,
            textAlign: TextAlign.center,
            style: GoogleFonts.hindSiliguri(color: scheme.onSurface),
          ),
        ),
      ),
    );
  }
}
