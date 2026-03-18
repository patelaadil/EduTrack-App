import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'teacher_shell.dart';
class TeacherNotificationsScreen extends ConsumerWidget {
  const TeacherNotificationsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Notifications')),
    drawer: const TeacherDrawer(),
    body: const Center(child: Text('Coming in next build')),
  );
}
