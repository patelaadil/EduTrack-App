import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../providers/auth_provider.dart';
import '../../supabase/supabase_config.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_avatar.dart';
import 'teacher_shell.dart';

class TeacherProfileScreen extends ConsumerStatefulWidget {
  const TeacherProfileScreen({super.key});

  @override
  ConsumerState<TeacherProfileScreen> createState() => _State();
}

class _State extends ConsumerState<TeacherProfileScreen> {
  bool _uploading = false;

  Future<void> _uploadAvatar() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (xfile == null) return;

    setState(() => _uploading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('Not logged in');

      final bytes = await xfile.readAsBytes();
      final ext = xfile.name.split('.').last;
      final fileName = '${user.id}_${const Uuid().v4()}.$ext';

      // Upload to avatars bucket
      await supabase.storage.from('avatars').uploadBinary(fileName, bytes);
      final url = supabase.storage.from('avatars').getPublicUrl(fileName);

      // Update profile
      await supabase.from('profiles').update({'photo_url': url}).eq('id', user.id);
      
      // Refresh provider
      ref.invalidate(userProfileProvider);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Avatar updated!')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update avatar: $e')));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);
    final teacherAsync = ref.watch(teacherDataProvider);

    final isLoading = profileAsync.isLoading || teacherAsync.isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      drawer: const TeacherDrawer(),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : profileAsync.when(
              error: (e, _) => Center(child: Text('Error: $e')),
              loading: () => const Center(child: CircularProgressIndicator()),
              data: (profile) {
                final tcs = (teacherAsync.value?['teacher_classes'] as List?) ?? [];
                final classNames = tcs
                    .map((tc) => tc['classes']?['name'] as String?)
                    .whereType<String>()
                    .toSet()
                    .join(', ');

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Profile card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F2FF),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(children: [
                        GestureDetector(
                          onTap: _uploading ? null : _uploadAvatar,
                          child: Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              AppAvatar(
                                name: profile?.name ?? 'T',
                                photoUrl: profile?.photoUrl,
                                size: 84,
                              ),
                              if (_uploading)
                                const Positioned.fill(child: CircularProgressIndicator(color: AppColors.primary)),
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                                child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                              )
                            ]
                          )
                        ),
                        const SizedBox(height: 12),
                        Text(
                          profile?.name ?? 'Teacher',
                          style: GoogleFonts.publicSans(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textDark),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          classNames.isNotEmpty ? 'Classes: $classNames' : 'No classes assigned',
                          style: GoogleFonts.publicSans(fontSize: 13, color: AppColors.textGray),
                          textAlign: TextAlign.center,
                        ),
                      ]),
                    ),

                    const SizedBox(height: 16),

                    // Info card
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      child: Column(children: [
                        _InfoTile(icon: Icons.phone_outlined, iconColor: AppColors.success, label: 'CONTACT', value: profile?.phone ?? '—'),
                        const Divider(height: 0, indent: 60),
                        _InfoTile(icon: Icons.mail_outlined, iconColor: const Color(0xFF8B5CF6), label: 'EMAIL', value: profile?.email ?? '—'),
                        const Divider(height: 0, indent: 60),
                        _InfoTile(icon: Icons.badge_outlined, iconColor: AppColors.primary, label: 'SUBJECTS', value: tcs.map((tc) => tc['subject']).where((s) => s != null).toSet().join(', ').isNotEmpty ? tcs.map((tc) => tc['subject']).where((s) => s != null).toSet().join(', ') : '—'),
                      ]),
                    ),

                    const SizedBox(height: 16),

                    // Settings & Logout
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      child: Column(children: [
                        ListTile(
                          leading: const Icon(Icons.logout_rounded, color: AppColors.error, size: 20),
                          title: Text('Logout', style: GoogleFonts.publicSans(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.error)),
                          onTap: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Logout'),
                                content: const Text('Are you sure you want to logout?'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                  TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Logout', style: TextStyle(color: AppColors.error))),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              await ref.read(authProvider).signOut();
                              if (context.mounted) context.go('/login');
                            }
                          },
                        ),
                      ]),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label, value;
  const _InfoTile({required this.icon, required this.iconColor, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Row(children: [
      Container(
        width: 36, height: 36,
        decoration: BoxDecoration(color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(9)),
        child: Icon(icon, color: iconColor, size: 18),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: GoogleFonts.publicSans(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textGray, letterSpacing: 0.8)),
          const SizedBox(height: 2),
          Text(value, style: GoogleFonts.publicSans(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textDark)),
        ]),
      ),
    ]),
  );
}
