import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../providers/auth_provider.dart';
import '../../supabase/supabase_config.dart';
import '../../theme/app_theme.dart';
import '../../utils/qr_export.dart';
import '../../widgets/app_avatar.dart';
import 'student_shell.dart';

class StudentProfileScreen extends ConsumerStatefulWidget {
  const StudentProfileScreen({super.key});

  @override
  ConsumerState<StudentProfileScreen> createState() => _State();
}

class _State extends ConsumerState<StudentProfileScreen> {
  bool _uploading = false;
  final GlobalKey _qrKey = GlobalKey();

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

      await supabase.storage.from('avatars').uploadBinary(fileName, bytes);
      final url = supabase.storage.from('avatars').getPublicUrl(fileName);
      await supabase.from('profiles').update({'photo_url': url}).eq('id', user.id);

      ref.invalidate(userProfileProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Avatar updated!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update avatar: $e')));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _exportQr(String rollNumber) async {
    try {
      final boundary = _qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final pngBytes = byteData.buffer.asUint8List();
      await saveQrCodeImage(
        pngBytes,
        'QR_${rollNumber.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_')}.png',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('QR Code saved for $rollNumber'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);
    final studentAsync = ref.watch(studentDataProvider);
    final isLoading = profileAsync.isLoading || studentAsync.isLoading;

    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu_rounded),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: const Text('Profile'),
      ),
      drawer: const StudentDrawer(),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : profileAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (profile) {
                final student = studentAsync.value;

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F0FF),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: _uploading ? null : _uploadAvatar,
                            child: Stack(
                              alignment: Alignment.bottomRight,
                              children: [
                                AppAvatar(
                                  name: profile?.name ?? 'Student',
                                  photoUrl: profile?.photoUrl,
                                  size: 84,
                                ),
                                if (_uploading)
                                  const Positioned.fill(
                                    child: CircularProgressIndicator(color: AppColors.primary),
                                  ),
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                  child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            profile?.name ?? 'Student',
                            style: GoogleFonts.publicSans(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${student?['classes']?['name'] ?? '--'} | Roll No. ${student?['roll_number'] ?? '--'}',
                            style: GoogleFonts.publicSans(fontSize: 13, color: AppColors.textGray),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: [
                          _InfoTile(
                            icon: Icons.cake_outlined,
                            iconColor: const Color(0xFF3B82F6),
                            label: 'DATE OF BIRTH',
                            value: student?['dob']?.toString() ?? '--',
                          ),
                          const Divider(height: 0, indent: 60),
                          _InfoTile(
                            icon: Icons.phone_outlined,
                            iconColor: AppColors.success,
                            label: 'CONTACT',
                            value: profile?.phone ?? '--',
                          ),
                          const Divider(height: 0, indent: 60),
                          _InfoTile(
                            icon: Icons.mail_outlined,
                            iconColor: const Color(0xFF8B5CF6),
                            label: 'EMAIL',
                            value: profile?.email ?? '--',
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: [
                          _InfoTile(
                            icon: Icons.school_outlined,
                            iconColor: AppColors.primary,
                            label: 'CLASS',
                            value: student?['classes']?['name'] ?? '--',
                          ),
                          const Divider(height: 0, indent: 60),
                          _InfoTile(
                            icon: Icons.format_list_numbered_rounded,
                            iconColor: AppColors.success,
                            label: 'ROLL NUMBER',
                            value: student?['roll_number']?.toString() ?? '--',
                          ),
                          const Divider(height: 0, indent: 60),
                          _InfoTile(
                            icon: Icons.badge_outlined,
                            iconColor: const Color(0xFF8B5CF6),
                            label: 'STUDENT ID',
                            value: student?['uuid']?.toString() ?? '--',
                          ),
                          const Divider(height: 0, indent: 60),
                          _InfoTile(
                            icon: Icons.verified_user_outlined,
                            iconColor: AppColors.warning,
                            label: 'ROLE',
                            value: profile?.role.toUpperCase() ?? '--',
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'My QR Code',
                              style: GoogleFonts.publicSans(fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (student?['uuid'] != null)
                            RepaintBoundary(
                              key: _qrKey,
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                color: Colors.white,
                                child: QrImageView(
                                  data: student!['uuid'],
                                  version: QrVersions.auto,
                                  size: 180,
                                ),
                              ),
                            ),
                          const SizedBox(height: 12),
                          Text(
                            'Show this to teacher for attendance',
                            style: GoogleFonts.publicSans(fontSize: 12, color: AppColors.textGray),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: () => _exportQr(student?['roll_number']?.toString() ?? 'QR'),
                            icon: const Icon(Icons.download_rounded, size: 18),
                            label: Text(
                              'Export QR Code',
                              style: GoogleFonts.publicSans(fontWeight: FontWeight.w600),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.logout_rounded, color: AppColors.error, size: 20),
                        title: Text(
                          'Logout',
                          style: GoogleFonts.publicSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.error,
                          ),
                        ),
                        onTap: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Logout'),
                              content: const Text('Are you sure you want to logout?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text(
                                    'Logout',
                                    style: TextStyle(color: AppColors.error),
                                  ),
                                ),
                              ],
                            ),
                          );

                          if (confirm == true) {
                            await ref.read(authProvider).signOut();
                            if (context.mounted) context.go('/login');
                          }
                        },
                      ),
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
  final String label;
  final String value;

  const _InfoTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.publicSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textGray,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.publicSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
