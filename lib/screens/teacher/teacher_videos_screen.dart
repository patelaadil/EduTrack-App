import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'teacher_shell.dart';
class TeacherVideosScreen extends ConsumerWidget {
  const TeacherVideosScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Videos')),
    drawer: const TeacherDrawer(),
    body: const Center(child: Text('Coming in next build')),
  );
}
