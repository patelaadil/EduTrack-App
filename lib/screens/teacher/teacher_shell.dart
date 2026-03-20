import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_avatar.dart';

class TeacherShell extends ConsumerWidget {
  final Widget child;
  const TeacherShell({super.key, required this.child});

  static const _navItems = [
    _NavItem(icon: Icons.home_outlined,       activeIcon: Icons.home_rounded,        label: 'HOME',       route: '/teacher/home'),
    _NavItem(icon: Icons.school_outlined,     activeIcon: Icons.school_rounded,      label: 'STUDENTS',   route: '/teacher/students'),
    _NavItem(icon: Icons.check_circle_outline,activeIcon: Icons.check_circle_rounded,label: 'ATTENDANCE', route: '/teacher/attendance'),
    _NavItem(icon: Icons.person_outline,      activeIcon: Icons.person_rounded,      label: 'PROFILE',    route: '/teacher/profile'),
  ];

  int _idx(BuildContext context) {
    final loc = GoRouterState.of(context).matchedLocation;
    for (int i = 0; i < _navItems.length; i++) {
      if (loc.startsWith(_navItems[i].route)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final idx = _idx(context);
    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.border, width: 1)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, -2))],
        ),
        child: SafeArea(
          child: SizedBox(
            height: 58,
            child: Row(
              children: List.generate(_navItems.length, (i) {
                final item = _navItems[i];
                final active = i == idx;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => context.go(item.route),
                    behavior: HitTestBehavior.opaque,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(active ? item.activeIcon : item.icon,
                            size: 22, color: active ? AppColors.primary : AppColors.textLight),
                        const SizedBox(height: 3),
                        Text(item.label, style: GoogleFonts.publicSans(
                          fontSize: 9, fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                          color: active ? AppColors.primary : AppColors.textLight,
                          letterSpacing: 0.5,
                        )),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon, activeIcon;
  final String label, route;
  const _NavItem({required this.icon, required this.activeIcon, required this.label, required this.route});
}

// ── Teacher Drawer ────────────────────────────────────────────
class TeacherDrawer extends ConsumerWidget {
  const TeacherDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync  = ref.watch(userProfileProvider);
    final teacherAsync  = ref.watch(teacherDataProvider);

    // Build "Classes: 10-A, 9-B" subtitle from real teacher_classes data
    final tcs        = (teacherAsync.value?['teacher_classes'] as List?) ?? [];
    final classNames = tcs
        .map((tc) => tc['classes']?['name'] as String?)
        .whereType<String>()
        .toSet()
        .join(', ');

    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 20, 20, 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [Color(0xFF1A6FD1), Color(0xFF1557A8)],
              ),
            ),
            child: profileAsync.when(
              data: (profile) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppAvatar(name: profile?.name ?? 'Teacher', photoUrl: profile?.photoUrl, size: 64),
                  const SizedBox(height: 12),
                  Text(profile?.name ?? 'Teacher', style: const TextStyle(
                      color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(classNames.isNotEmpty ? 'Classes: $classNames' : 'No classes assigned',
                      style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 13)),
                ],
              ),
              loading: () => const CircularProgressIndicator(color: Colors.white),
              error: (_, __) => const SizedBox(),
            ),
          ),

          // Nav items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _DrawerItem(icon: Icons.home_rounded,        label: 'Home',             route: '/teacher/home',          active: true),
                _DrawerItem(icon: Icons.school_rounded,      label: 'Students',         route: '/teacher/students'),
                _DrawerItem(icon: Icons.check_circle_rounded,label: 'Attendance',       route: '/teacher/attendance'),
                _DrawerItem(icon: Icons.movie_rounded,       label: 'Videos',           route: '/teacher/videos'),
                _DrawerItem(icon: Icons.bar_chart_rounded,   label: 'Marks & Reports',  route: '/teacher/marks'),
                _DrawerItem(icon: Icons.notifications_rounded,label: 'Notifications',   route: '/teacher/notifications', badge: 3),
                _DrawerItem(icon: Icons.person_rounded,      label: 'Profile',          route: '/teacher/profile'),
                const Divider(height: 24, indent: 16, endIndent: 16),
                _DrawerItem(icon: Icons.image_rounded,           label: 'Slider Management', route: '/teacher/sliders'),
                _DrawerItem(icon: Icons.qr_code_scanner_rounded, label: 'Take Attendance',   route: '/teacher/scanner', tag: 'SCAN', tagColor: AppColors.success, isExternal: true),
                _DrawerItem(icon: Icons.info_outline_rounded,    label: 'App Info',          route: '/teacher/home'),
                _DrawerItem(icon: Icons.settings_rounded,    label: 'Settings',         route: '/teacher/home'),
                const Divider(height: 24, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.logout_rounded, color: AppColors.error, size: 20),
                  title: Text('Logout', style: const TextStyle(
                      color: AppColors.error, fontWeight: FontWeight.w600, fontSize: 14)),
                  onTap: () async {
                    Navigator.pop(context);
                    await ref.read(authProvider).signOut();
                    if (context.mounted) context.go('/login');
                  },
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('EDUTRACK V2.4.0',
                style: TextStyle(fontSize: 11, color: AppColors.textLight, letterSpacing: 1.5,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label, route;
  final bool active;
  final int? badge;
  final String? tag;
  final Color? tagColor;
  final bool isExternal; // true = context.push (full screen), false = context.go
  const _DrawerItem({required this.icon, required this.label, required this.route,
    this.active = false, this.badge, this.tag, this.tagColor, this.isExternal = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      decoration: BoxDecoration(
        color: active ? AppColors.primaryLight : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        dense: true,
        leading: Icon(icon, size: 20, color: active ? AppColors.primary : AppColors.textDark),
        title: Text(label, style: TextStyle(
          fontSize: 14, fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          color: active ? AppColors.primary : AppColors.textDark,
        )),
        trailing: badge != null
            ? Container(
            width: 22, height: 22,
            decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
            child: Center(child: Text('$badge',
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700))))
            : tag != null
            ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: (tagColor ?? AppColors.primary).withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: (tagColor ?? AppColors.primary).withOpacity(0.3)),
            ),
            child: Text(tag!, style: TextStyle(
                color: tagColor ?? AppColors.primary, fontSize: 10, fontWeight: FontWeight.w700)))
            : null,
        onTap: () {
          Navigator.pop(context);
          if (isExternal) {
            context.push(route);
          } else {
            context.go(route);
          }
        },
      ),
    );
  }
}