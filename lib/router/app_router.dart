import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../supabase/supabase_config.dart';

// Screens
import '../screens/auth/login_screen.dart';
import '../screens/auth/splash_screen.dart';
import '../screens/teacher/teacher_shell.dart';
import '../screens/teacher/teacher_home_screen.dart';
import '../screens/teacher/teacher_students_screen.dart';
import '../screens/teacher/teacher_attendance_screen.dart';
import '../screens/teacher/teacher_scanner_screen.dart';
import '../screens/teacher/teacher_marks_screen.dart';
import '../screens/teacher/teacher_videos_screen.dart';
import '../screens/teacher/teacher_notifications_screen.dart';
import '../screens/teacher/teacher_profile_screen.dart';
import '../screens/teacher/teacher_sliders_screen.dart';
import '../screens/student/student_shell.dart';
import '../screens/student/student_home_screen.dart';
import '../screens/student/student_attendance_screen.dart';
import '../screens/student/student_holidays_screen.dart';
import '../screens/student/student_marks_screen.dart';
import '../screens/student/student_videos_screen.dart';
import '../screens/student/student_notifications_screen.dart';
import '../screens/student/student_profile_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) async {
      final user = supabase.auth.currentUser;
      final loc = state.matchedLocation;
      final onAuth = loc == '/login' || loc == '/splash';

      if (user == null) return onAuth ? null : '/login';
      if (loc == '/splash') return null;

      try {
        final profile = await supabase
            .from('profiles')
            .select('role, is_active')
            .eq('id', user.id)
            .single();

        if (profile['is_active'] == false) return '/login';

        final role = profile['role'] as String?;
        if (role == null || role == 'admin') return '/login';

        final home = role == 'teacher' ? '/teacher/home' : '/student/home';
        final isTeacherRoute = loc.startsWith('/teacher/');
        final isStudentRoute = loc.startsWith('/student/');

        if (onAuth) return home;
        if (isTeacherRoute && role != 'teacher') return home;
        if (isStudentRoute && role != 'student') return home;
        return null;
      } catch (_) {
        return '/login';
      }
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login',  builder: (_, __) => const LoginScreen()),

      // ── Scanner — outside shell so NO bottom nav bar while scanning ──
      GoRoute(path: '/teacher/scanner', builder: (_, __) => const TeacherScannerScreen()),

      // ── Teacher Shell (bottom nav) ───────────────────────
      ShellRoute(
        builder: (context, state, child) => TeacherShell(child: child),
        routes: [
          GoRoute(path: '/teacher/home',          builder: (_, __) => const TeacherHomeScreen()),
          GoRoute(path: '/teacher/students',       builder: (_, __) => const TeacherStudentsScreen()),
          GoRoute(path: '/teacher/attendance',     builder: (_, __) => const TeacherAttendanceScreen()),
          GoRoute(path: '/teacher/marks',          builder: (_, __) => const TeacherMarksScreen()),
          GoRoute(path: '/teacher/videos',         builder: (_, __) => const TeacherVideosScreen()),
          GoRoute(path: '/teacher/notifications',  builder: (_, __) => const TeacherNotificationsScreen()),
          GoRoute(path: '/teacher/profile',        builder: (_, __) => const TeacherProfileScreen()),
          GoRoute(path: '/teacher/sliders',        builder: (_, __) => const TeacherSlidersScreen()),
        ],
      ),

      // ── Student Shell (bottom nav) ───────────────────────
      ShellRoute(
        builder: (context, state, child) => StudentShell(child: child),
        routes: [
          GoRoute(path: '/student/home',          builder: (_, __) => const StudentHomeScreen()),
          GoRoute(path: '/student/attendance',    builder: (_, __) => const StudentAttendanceScreen()),
          GoRoute(path: '/student/holidays',      builder: (_, __) => const StudentHolidaysScreen()),
          GoRoute(path: '/student/marks',         builder: (_, __) => const StudentMarksScreen()),
          GoRoute(path: '/student/videos',        builder: (_, __) => const StudentVideosScreen()),
          GoRoute(path: '/student/notifications', builder: (_, __) => const StudentNotificationsScreen()),
          GoRoute(path: '/student/profile',       builder: (_, __) => const StudentProfileScreen()),
        ],
      ),
    ],
  );
});
