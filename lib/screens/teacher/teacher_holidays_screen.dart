import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../widgets/read_only_holiday_view.dart';
import 'teacher_shell.dart';

class TeacherHolidaysScreen extends ConsumerStatefulWidget {
  const TeacherHolidaysScreen({super.key});

  @override
  ConsumerState<TeacherHolidaysScreen> createState() => _State();
}

class _State extends ConsumerState<TeacherHolidaysScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const TeacherDrawer(),
      appBar: AppBar(
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu_rounded),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: const Text('Holidays'),
      ),
      body: const ReadOnlyHolidayView(),
    );
  }
}
