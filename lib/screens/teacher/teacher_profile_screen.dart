import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_avatar.dart';
import 'teacher_shell.dart';

class TeacherProfileScreen extends ConsumerWidget {
  const TeacherProfileScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider).value;
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      drawer: const TeacherDrawer(),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
          child: Column(children: [
            AppAvatar(name: profile?.name ?? 'T', photoUrl: profile?.photoUrl, size: 72),
            const SizedBox(height: 12),
            Text(profile?.name ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            Text(profile?.email ?? '', style: const TextStyle(fontSize: 13, color: AppColors.textGray)),
          ]),
        ),
        const SizedBox(height: 16),
        ListTile(
          tileColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.border)),
          leading: const Icon(Icons.logout_rounded, color: AppColors.error),
          title: const Text('Logout', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600)),
          onTap: () async { await ref.read(authProvider).signOut(); if (context.mounted) context.go('/login'); },
        ),
      ]),
    );
  }
}
