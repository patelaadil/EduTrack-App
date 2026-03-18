import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../supabase/supabase_config.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_avatar.dart';

class StudentHomeScreen extends ConsumerStatefulWidget {
  const StudentHomeScreen({super.key});
  @override
  ConsumerState<StudentHomeScreen> createState() => _State();
}

class _State extends ConsumerState<StudentHomeScreen> {
  int _present = 0, _absent = 0, _late = 0;
  double _pct = 0;
  List<Map<String, dynamic>> _sliders = [];
  List<Map<String, dynamic>> _recentActivity = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    try {
      final results = await Future.wait<dynamic>([
        supabase.from('students').select('uuid').eq('profile_id', user.id).single(),
        supabase.from('sliders').select('*').eq('is_active', true).order('order_index'),
      ]);
      final studentData = results[0] as Map?;
      final uuid = studentData?['uuid'];
      if (uuid != null) {
        final records = await supabase
            .from('attendance_records')
            .select('status, scanned_at, attendance_sessions(subject, session_date)')
            .eq('student_uuid', uuid)
            .order('scanned_at', ascending: false);
        final recs = records as List;
        final p = recs.where((r) => r['status'] == 'present').length;
        final a = recs.where((r) => r['status'] == 'absent').length;
        final l = recs.where((r) => r['status'] == 'late').length;
        final total = p + a + l;
        if (mounted) setState(() {
          _present = p; _absent = a; _late = l;
          _pct = total > 0 ? (p + l) / total * 100 : 0;
          _recentActivity = recs.take(3).toList().cast<Map<String, dynamic>>();
        });
      }
      if (mounted) setState(() {
        _sliders = List<Map<String, dynamic>>.from(results[1] as List);
        _loading = false;
      });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider).value;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.menu_rounded), onPressed: () {}),
        title: const Text('EduTrack'),
        actions: [
          Stack(children: [
            IconButton(icon: const Icon(Icons.notifications_outlined), onPressed: () => context.go('/student/notifications')),
            Positioned(top: 10, right: 10, child: Container(
              width: 8, height: 8,
              decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
            )),
          ]),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Welcome card
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                        colors: [Color(0xFF1A6FD1), Color(0xFF1350A8)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${_greeting()}, ${profile?.name.split(' ').first ?? 'Student'}! 👋',
                              style: GoogleFonts.publicSans(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 5),
                            Text('Class 10-A | Roll 42', style: GoogleFonts.publicSans(
                              color: Colors.white.withOpacity(0.78), fontSize: 13)),
                          ],
                        )),
                        AppAvatar(name: profile?.name ?? 'S', photoUrl: profile?.photoUrl, size: 52),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Attendance circle card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white, borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(children: [
                      SizedBox(
                        width: 120, height: 120,
                        child: Stack(alignment: Alignment.center, children: [
                          SizedBox(
                            width: 120, height: 120,
                            child: CircularProgressIndicator(
                              value: _pct / 100,
                              strokeWidth: 10,
                              backgroundColor: AppColors.border,
                              valueColor: AlwaysStoppedAnimation(
                                _pct >= 75 ? AppColors.success : AppColors.error),
                            ),
                          ),
                          Column(mainAxisSize: MainAxisSize.min, children: [
                            Text('${_pct.round()}%', style: GoogleFonts.publicSans(
                              fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                          ]),
                        ]),
                      ),
                      const SizedBox(height: 12),
                      Text('This Month', style: GoogleFonts.publicSans(
                        fontSize: 13, color: AppColors.textGray, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 10),
                      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        _Dot(color: AppColors.success, label: 'PRESENT $_present'),
                        const SizedBox(width: 14),
                        _Dot(color: AppColors.error, label: 'ABSENT $_absent'),
                        const SizedBox(width: 14),
                        _Dot(color: AppColors.warning, label: 'LATE $_late'),
                      ]),
                    ]),
                  ),

                  const SizedBox(height: 16),

                  // Announcements (Sliders)
                  Text('Announcements', style: GoogleFonts.publicSans(
                    fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 150,
                    child: _sliders.isEmpty
                        ? Container(
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.border)),
                            child: Center(child: Text('No announcements', style: TextStyle(color: AppColors.textGray))))
                        : PageView.builder(
                            itemCount: _sliders.length,
                            itemBuilder: (_, i) {
                              final s = _sliders[i];
                              return Container(
                                margin: const EdgeInsets.only(right: 4),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  color: AppColors.primary,
                                  image: s['image_url'] != null
                                      ? DecorationImage(image: NetworkImage(s['image_url']), fit: BoxFit.cover, colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.35), BlendMode.darken))
                                      : null,
                                ),
                                padding: const EdgeInsets.all(16),
                                alignment: Alignment.bottomLeft,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('SCHOOL EVENT', style: GoogleFonts.publicSans(color: Colors.white60, fontSize: 10, letterSpacing: 1)),
                                    Text(s['title'] ?? '', style: GoogleFonts.publicSans(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),

                  const SizedBox(height: 16),

                  // Quick links
                  Row(children: [
                    Expanded(child: _QuickLink(icon: Icons.movie_rounded, label: 'Videos', onTap: () => context.go('/student/videos'))),
                    const SizedBox(width: 12),
                    Expanded(child: _QuickLink(icon: Icons.notifications_rounded, label: 'Notifications', onTap: () => context.go('/student/notifications'))),
                  ]),

                  const SizedBox(height: 20),

                  // Recent Activity
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Recent Activity', style: GoogleFonts.publicSans(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                      TextButton(onPressed: () => context.go('/student/attendance'),
                        child: Text('View All', style: GoogleFonts.publicSans(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 13))),
                    ],
                  ),
                  const SizedBox(height: 8),

                  if (_recentActivity.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
                      child: Text('No recent activity', style: TextStyle(color: AppColors.textGray, fontSize: 13)),
                    )
                  else
                    ..._recentActivity.map((r) => _ActivityTile(
                      status: r['status'],
                      subject: r['attendance_sessions']?['subject'] ?? 'Class',
                      time: r['scanned_at'] ?? '',
                    )),
                ],
              ),
            ),
    );
  }
}

class _Dot extends StatelessWidget {
  final Color color;
  final String label;
  const _Dot({required this.color, required this.label});
  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    const SizedBox(width: 5),
    Text(label, style: GoogleFonts.publicSans(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textGray)),
  ]);
}

class _QuickLink extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickLink({required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
      child: Column(children: [
        Icon(icon, size: 28, color: AppColors.textDark),
        const SizedBox(height: 8),
        Text(label, style: GoogleFonts.publicSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
      ]),
    ),
  );
}

class _ActivityTile extends StatelessWidget {
  final String status, subject, time;
  const _ActivityTile({required this.status, required this.subject, required this.time});

  Color get _color => status == 'present' ? AppColors.success : status == 'absent' ? AppColors.error : AppColors.warning;
  IconData get _icon => status == 'present' ? Icons.check_box_rounded : status == 'absent' ? Icons.warning_amber_rounded : Icons.access_time_rounded;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
    child: Row(children: [
      Container(
        width: 36, height: 36,
        decoration: BoxDecoration(color: _color.withOpacity(0.12), borderRadius: BorderRadius.circular(9)),
        child: Icon(_icon, color: _color, size: 18),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${status[0].toUpperCase()}${status.substring(1)} — $subject',
          style: GoogleFonts.publicSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
        Text(time, style: GoogleFonts.publicSans(fontSize: 11, color: AppColors.textGray)),
      ])),
    ]),
  );
}
