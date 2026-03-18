import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../supabase/supabase_config.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_avatar.dart';
import 'teacher_shell.dart';

class TeacherStudentsScreen extends ConsumerStatefulWidget {
  const TeacherStudentsScreen({super.key});
  @override
  ConsumerState<TeacherStudentsScreen> createState() => _State();
}

class _State extends ConsumerState<TeacherStudentsScreen> {
  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _classes  = [];
  List<Map<String, dynamic>> _filtered = [];
  String _search = '', _selectedClass = 'All Classes';
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final results = await Future.wait([
      supabase.from('students').select('uuid, roll_number, profiles(name, photo_url, is_active), classes(name)').order('roll_number'),
      supabase.from('classes').select('id, name'),
    ]);
    setState(() {
      _students = List<Map<String, dynamic>>.from(results[0] as List);
      _classes  = List<Map<String, dynamic>>.from(results[1] as List);
      _loading  = false;
    });
    _applyFilter();
  }

  void _applyFilter() {
    setState(() {
      _filtered = _students.where((s) {
        final name  = (s['profiles']?['name'] ?? '').toString().toLowerCase();
        final roll  = (s['roll_number'] ?? '').toString().toLowerCase();
        final cls   = (s['classes']?['name'] ?? '').toString();
        final matchSearch = _search.isEmpty || name.contains(_search.toLowerCase()) || roll.contains(_search.toLowerCase());
        final matchClass  = _selectedClass == 'All Classes' || cls == _selectedClass;
        return matchSearch && matchClass;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final classOptions = ['All Classes', ..._classes.map((c) => c['name'] as String)];
    return Scaffold(
      appBar: AppBar(
        leading: Builder(builder: (ctx) => IconButton(
          icon: const Icon(Icons.menu_rounded), onPressed: () => Scaffold.of(ctx).openDrawer())),
        title: const Text('Students'),
        actions: [
          IconButton(icon: const Icon(Icons.search_rounded), onPressed: () {}),
          IconButton(icon: const Icon(Icons.filter_list_rounded), onPressed: () {}),
        ],
      ),
      drawer: const TeacherDrawer(),
      body: Column(
        children: [
          // Class filter chips
          SizedBox(
            height: 52,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              itemCount: classOptions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final cls = classOptions[i];
                final selected = cls == _selectedClass;
                return GestureDetector(
                  onTap: () { setState(() => _selectedClass = cls); _applyFilter(); },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.primary : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: selected ? AppColors.primary : AppColors.border),
                    ),
                    child: Text(cls, style: GoogleFonts.publicSans(
                      fontSize: 13, fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : AppColors.textGray)),
                  ),
                );
              },
            ),
          ),

          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              onChanged: (v) { setState(() => _search = v); _applyFilter(); },
              decoration: InputDecoration(
                hintText: 'Search students by name or roll...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppColors.textLight),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),

          // Count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${_filtered.length} Students', style: GoogleFonts.publicSans(
                  fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textGray)),
                Text('Sorted by Roll No.', style: GoogleFonts.publicSans(
                  fontSize: 12, color: AppColors.textLight, fontStyle: FontStyle.italic)),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // List
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? Center(child: Text('No students found', style: TextStyle(color: AppColors.textGray)))
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final s = _filtered[i];
                          final name    = s['profiles']?['name'] ?? '?';
                          final photo   = s['profiles']?['photo_url'] as String?;
                          final roll    = s['roll_number'] ?? '--';
                          final cls     = s['classes']?['name'] ?? '--';
                          // Attendance % would come from a real query
                          final pct     = (i % 3 == 0) ? 64 : (i % 2 == 0) ? 92 : 88;
                          final pctColor= pct < 75 ? AppColors.error : AppColors.success;

                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                AppAvatar(name: name, photoUrl: photo, size: 46),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(name, style: GoogleFonts.publicSans(
                                        fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                                      const SizedBox(height: 3),
                                      Text('Roll $roll • $cls', style: GoogleFonts.publicSans(
                                        fontSize: 12, color: AppColors.textGray)),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: pctColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text('$pct%', style: GoogleFonts.publicSans(
                                    fontSize: 13, fontWeight: FontWeight.w700, color: pctColor)),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.chevron_right_rounded, color: AppColors.textLight, size: 18),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.person_add_rounded, color: Colors.white),
      ),
    );
  }
}
