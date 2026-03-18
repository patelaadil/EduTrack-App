import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_avatar.dart';

class StudentProfileScreen extends ConsumerWidget {
  const StudentProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Both providers are cached — no Supabase call on re-navigation
    final profileAsync = ref.watch(userProfileProvider);
    final studentAsync = ref.watch(studentDataProvider);

    // Show loading only on the very first load
    final isLoading = profileAsync.isLoading || studentAsync.isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : profileAsync.when(
              error: (e, _) => Center(child: Text('Error: $e')),
              loading: () => const Center(child: CircularProgressIndicator()),
              data: (profile) {
                final student = studentAsync.value;
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Profile card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F0FF),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Stack(
                        children: [
                          Column(children: [
                            AppAvatar(
                              name: profile?.name ?? '?',
                              photoUrl: profile?.photoUrl,
                              size: 80,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              profile?.name ?? '',
                              style: GoogleFonts.publicSans(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textDark,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${student?['classes']?['name'] ?? ''} • Roll No. ${student?['roll_number'] ?? ''}',
                              style: GoogleFonts.publicSans(
                                fontSize: 13,
                                color: AppColors.textGray,
                              ),
                            ),
                          ]),
                          Positioned(
                            top: 0, right: 0,
                            child: IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.textGray),
                              onPressed: () {},
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Info card
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(children: [
                        _InfoTile(icon: Icons.cake_outlined,        iconColor: const Color(0xFF3B82F6), label: 'DATE OF BIRTH',  value: student?['dob'] ?? '—'),
                        const Divider(height: 0, indent: 60),
                        _InfoTile(icon: Icons.phone_outlined,        iconColor: AppColors.success,       label: 'CONTACT',       value: profile?.phone ?? '—'),
                        const Divider(height: 0, indent: 60),
                        _InfoTile(icon: Icons.mail_outlined,         iconColor: const Color(0xFF8B5CF6), label: 'EMAIL',          value: profile?.email ?? '—'),
                        const Divider(height: 0, indent: 60),
                        _InfoTile(icon: Icons.location_on_outlined,  iconColor: AppColors.error,         label: 'ADDRESS',        value: '—'),
                      ]),
                    ),

                    const SizedBox(height: 16),

                    // QR Code section
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text('My QR Code',
                            style: GoogleFonts.publicSans(fontSize: 16, fontWeight: FontWeight.w700)),
                        ),
                        const SizedBox(height: 16),
                        if (student?['uuid'] != null)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.border, width: 1.5),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: QrImageView(
                              data: student!['uuid'],
                              version: QrVersions.auto,
                              size: 180,
                            ),
                          ),
                        const SizedBox(height: 12),
                        Text('Show this to teacher for attendance',
                          style: GoogleFonts.publicSans(fontSize: 12, color: AppColors.textGray)),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.download_outlined, size: 18),
                          label: Text('Save QR', style: GoogleFonts.publicSans(fontWeight: FontWeight.w600)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
                            minimumSize: const Size(double.infinity, 46),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ]),
                    ),

                    const SizedBox(height: 16),

                    // Settings
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(children: [
                        ListTile(
                          leading: const Icon(Icons.lock_outline, color: AppColors.textDark, size: 20),
                          title: Text('Change Password',
                            style: GoogleFonts.publicSans(fontSize: 14, fontWeight: FontWeight.w500)),
                          trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textLight),
                          onTap: () {},
                        ),
                        const Divider(height: 0),
                        ListTile(
                          leading: const Icon(Icons.logout_rounded, color: AppColors.error, size: 20),
                          title: Text('Logout',
                            style: GoogleFonts.publicSans(
                              fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.error)),
                          onTap: () async {
                            await ref.read(authProvider).signOut();
                            if (context.mounted) context.go('/login');
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
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(icon, color: iconColor, size: 18),
      ),
      const SizedBox(width: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: GoogleFonts.publicSans(
          fontSize: 10, fontWeight: FontWeight.w700,
          color: AppColors.textGray, letterSpacing: 0.8)),
        const SizedBox(height: 2),
        Text(value, style: GoogleFonts.publicSans(
          fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textDark)),
      ]),
    ]),
  );
}
