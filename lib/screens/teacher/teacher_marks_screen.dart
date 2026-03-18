import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'teacher_shell.dart';
class TeacherMarksScreen extends ConsumerWidget {
  const TeacherMarksScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Marks & Reports')),
    drawer: const TeacherDrawer(),
    body: const Center(child: Text('Coming in next build')),
  );
}
