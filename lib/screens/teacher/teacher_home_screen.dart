import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../supabase/supabase_config.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_avatar.dart';
import 'teacher_shell.dart';

class TeacherHomeScreen extends ConsumerStatefulWidget {
  const TeacherHomeScreen({super.key});
  @override
  ConsumerState<TeacherHomeScreen> createState() => _TeacherHomeScreenState();
}

class _TeacherHomeScreenState extends ConsumerState<TeacherHomeScreen> {
  int    _studentCount  = 0;
  double _attendancePct = 0;
  bool   _loading       = true;
  List<Map<String, dynamic>> _schedule = [];

  @override
  void initState() { super.initState(); _loadStats(); }

  Future<void> _loadStats() async {
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];

      // Student count + today's attendance
      final studentList = await supabase.from('students').select('uuid') as List;
      final sessions    = await supabase
          .from('attendance_sessions')
          .select('attendance_records(status)')
          .eq('session_date', today) as List;

      int present = 0, total = 0;
      for (final s in sessions) {
        for (final r in (s['attendance_records'] as List)) {
          total++;
          if (r['status'] == 'present' || r['status'] == 'late') present++;
        }
      }

      // Assigned classes from cached provider
      final teacherData = await ref.read(teacherDataProvider.future);
      final tcs = (teacherData?['teacher_classes'] as List?) ?? [];

      if (mounted) setState(() {
        _studentCount  = studentList.length;
        _attendancePct = total > 0 ? (present / total * 100) : 0;
        _schedule      = List<Map<String, dynamic>>.from(tcs);
        _loading       = false;
      });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);
    final profile = profileAsync.value;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        leading: Builder(builder: (ctx) => IconButton(
          icon: const Icon(Icons.menu_rounded, size: 24),
          onPressed: () => Scaffold.of(ctx).openDrawer(),
        )),
        title: Text('EduTrack', style: GoogleFonts.publicSans(
            color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 20)),
        centerTitle: false,
        actions: [
          Stack(children: [
            IconButton(icon: const Icon(Icons.notifications_outlined, size: 24), onPressed: () => context.go('/teacher/notifications')),
            Positioned(top: 10, right: 10, child: Container(
              width: 8, height: 8,
              decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
            )),
          ]),
        ],
      ),
      drawer: const TeacherDrawer(),
      body: RefreshIndicator(
        onRefresh: _loadStats,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Welcome card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [Color(0xFF1A6FD1), Color(0xFF1A5CB8)],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6))],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Welcome, ${profile?.name ?? 'Teacher'}! 👋',
                            style: GoogleFonts.publicSans(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        Text('${_schedule.length} Class${_schedule.length == 1 ? '' : 'es'} Assigned',
                            style: GoogleFonts.publicSans(color: Colors.white.withOpacity(0.8), fontSize: 13)),
                      ],
                    ),
                  ),
                  AppAvatar(name: profile?.name ?? 'T', photoUrl: profile?.photoUrl, size: 56),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Stats row
            Row(children: [
              _StatCard(icon: Icons.groups_rounded, iconColor: AppColors.primary,
                  value: _loading ? '--' : '$_studentCount', label: 'STUDENTS'),
              const SizedBox(width: 10),
              _StatCard(icon: Icons.fact_check_rounded, iconColor: AppColors.success,
                  value: _loading ? '--' : '${_attendancePct.round()}%', label: 'ATTENDANCE'),
              const SizedBox(width: 10),
              _StatCard(icon: Icons.pending_actions_rounded, iconColor: AppColors.warning,
                  value: '5', label: 'PENDING'),
            ]),

            const SizedBox(height: 20),

            // Quick Actions
            Text('QUICK ACTIONS', style: GoogleFonts.publicSans(
                fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textGray, letterSpacing: 1.2)),
            const SizedBox(height: 12),

            // Scanner - primary large button
            ElevatedButton.icon(
              onPressed: () => context.push('/teacher/scanner'),
              icon: const Icon(Icons.qr_code_scanner_rounded, size: 22),
              label: Text('Take Attendance (Scan QR)', style: GoogleFonts.publicSans(fontSize: 15, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 10),

            Row(children: [
              Expanded(child: _OutlineBtn(
                  icon: Icons.campaign_outlined, label: 'Notification',
                  onTap: () => context.go('/teacher/notifications'))),
              const SizedBox(width: 10),
              Expanded(child: _OutlineBtn(
                  icon: Icons.add_box_outlined, label: 'Add Video',
                  onTap: () => context.go('/teacher/videos'))),
            ]),
            const SizedBox(height: 10),

            _OutlineBtn(
                icon: Icons.format_list_numbered_rounded, label: 'Add Student Marks',
                onTap: () => context.go('/teacher/marks')),

            const SizedBox(height: 24),

            // Today's Schedule
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("ASSIGNED CLASSES", style: GoogleFonts.publicSans(
                    fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textGray, letterSpacing: 1.2)),
                TextButton(
                    onPressed: () => context.go('/teacher/students'),
                    child: Text('View Students',
                        style: GoogleFonts.publicSans(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 13))),
              ],
            ),
            const SizedBox(height: 8),

            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_schedule.isEmpty)
              Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: Colors.white, borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border)),
                  child: Text('No classes assigned yet. Contact admin.',
                      style: GoogleFonts.publicSans(color: AppColors.textGray, fontSize: 13)))
            else
              ..._schedule.map((tc) {
                final cls     = (tc['classes'] as Map?) ?? {};
                final subject = (tc['subject'] as String?) ?? '';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _ScheduleCard(
                    className: (cls['name'] as String?) ?? '--',
                    subject:   subject,
                    onScan:    () => context.push('/teacher/scanner'),
                  ),
                );
              }),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value, label;
  const _StatCard({required this.icon, required this.iconColor, required this.value, required this.label});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(height: 8),
          Text(value, style: GoogleFonts.publicSans(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textDark)),
          const SizedBox(height: 4),
          Text(label, style: GoogleFonts.publicSans(fontSize: 9, fontWeight: FontWeight.w700,
              color: AppColors.textGray, letterSpacing: 0.8)),
        ],
      ),
    ),
  );
}

class _OutlineBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _OutlineBtn({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(label, style: GoogleFonts.publicSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
        ],
      ),
    ),
  );
}

class _ScheduleCard extends StatelessWidget {
  final String      className, subject;
  final VoidCallback onScan;
  const _ScheduleCard({required this.className, required this.subject, required this.onScan});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white, borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.border),
    ),
    child: Row(children: [
      Container(
        width: 42, height: 42,
        decoration: BoxDecoration(
            color: AppColors.primaryLight, borderRadius: BorderRadius.circular(10)),
        child: const Icon(Icons.class_rounded, color: AppColors.primary, size: 20),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(className, style: GoogleFonts.publicSans(
            fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark)),
        const SizedBox(height: 2),
        Text(subject, style: GoogleFonts.publicSans(
            fontSize: 12, color: AppColors.textGray)),
      ])),
      GestureDetector(
        onTap: onScan,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
              color: AppColors.primaryLight, borderRadius: BorderRadius.circular(20)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.qr_code_scanner_rounded, size: 14, color: AppColors.primary),
            const SizedBox(width: 4),
            Text('Scan', style: GoogleFonts.publicSans(
                fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
          ]),
        ),
      ),
    ]),
  );
}