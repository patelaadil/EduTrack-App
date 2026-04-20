import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../supabase/supabase_config.dart';
import '../../theme/app_theme.dart';
import 'student_shell.dart';

class StudentNotificationsScreen extends ConsumerStatefulWidget {
  const StudentNotificationsScreen({super.key});
  @override
  ConsumerState<StudentNotificationsScreen> createState() => _State();
}
class _State extends ConsumerState<StudentNotificationsScreen> {
  List<Map<String, dynamic>> _notifs = [];
  bool _loading = true;
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    final data = await supabase.from('notifications').select('id, title, body, created_at, target_type').order('created_at', ascending: false);
    if (mounted) setState(() { _notifs = List<Map<String, dynamic>>.from(data as List); _loading = false; });
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: Builder(builder: (ctx) => IconButton(
        icon: const Icon(Icons.menu_rounded),
        onPressed: () => Scaffold.of(ctx).openDrawer(),
      )),
      title: const Text('Notifications'),
    ),
    drawer: const StudentDrawer(),
    body: _loading ? const Center(child: CircularProgressIndicator())
      : _notifs.isEmpty ? Center(child: Text('No notifications', style: TextStyle(color: AppColors.textGray)))
      : ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: _notifs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final n = _notifs[i];
            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
              child: Row(children: [
                Container(width: 40, height: 40,
                  decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.notifications_rounded, color: AppColors.primary, size: 20)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(n['title'] ?? '', style: GoogleFonts.publicSans(fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(n['body'] ?? '', style: GoogleFonts.publicSans(fontSize: 12, color: AppColors.textGray), maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(n['created_at']?.toString().split('T')[0] ?? '', style: GoogleFonts.publicSans(fontSize: 11, color: AppColors.textLight)),
                ])),
              ]),
            );
          },
        ),
  );
}
