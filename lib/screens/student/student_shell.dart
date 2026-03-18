import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';

class StudentShell extends StatelessWidget {
  final Widget child;
  const StudentShell({super.key, required this.child});

  static const _tabs = [
    _Tab(icon: Icons.home_outlined,       activeIcon: Icons.home_rounded,        label: 'Home',       route: '/student/home'),
    _Tab(icon: Icons.bar_chart_outlined,  activeIcon: Icons.bar_chart_rounded,   label: 'Attendance', route: '/student/attendance'),
    _Tab(icon: Icons.menu_book_outlined,  activeIcon: Icons.menu_book_rounded,   label: 'Academics',  route: '/student/marks'),
    _Tab(icon: Icons.person_outline,      activeIcon: Icons.person_rounded,      label: 'Profile',    route: '/student/profile'),
  ];

  int _idx(BuildContext context) {
    final loc = GoRouterState.of(context).matchedLocation;
    for (int i = 0; i < _tabs.length; i++) {
      if (loc.startsWith(_tabs[i].route)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final idx = _idx(context);
    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.border)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, -2))],
        ),
        child: SafeArea(
          child: SizedBox(
            height: 58,
            child: Row(
              children: List.generate(_tabs.length, (i) {
                final tab = _tabs[i];
                final active = i == idx;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => context.go(tab.route),
                    behavior: HitTestBehavior.opaque,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(active ? tab.activeIcon : tab.icon,
                          size: 22, color: active ? AppColors.primary : AppColors.textLight),
                        const SizedBox(height: 3),
                        Text(tab.label, style: GoogleFonts.publicSans(
                          fontSize: 10, fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                          color: active ? AppColors.primary : AppColors.textLight)),
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

class _Tab {
  final IconData icon, activeIcon;
  final String label, route;
  const _Tab({required this.icon, required this.activeIcon, required this.label, required this.route});
}
