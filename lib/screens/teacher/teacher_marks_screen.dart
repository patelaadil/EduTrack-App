import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/auth_provider.dart';
import '../../supabase/supabase_config.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_avatar.dart';
import 'teacher_shell.dart';

class TeacherMarksScreen extends ConsumerStatefulWidget {
  const TeacherMarksScreen({super.key});
  @override
  ConsumerState<TeacherMarksScreen> createState() => _State();
}

class _State extends ConsumerState<TeacherMarksScreen> {
  List<Map<String, dynamic>> _myClasses = [];
  Map<String, dynamic>? _selectedClass;
  String? _examType;
  bool _loading = true;
  bool _loadingStudents = false;
  
  List<Map<String, dynamic>> _students = [];
  final Map<String, TextEditingController> _markControllers = {};

  final _examTypes = ['Mid Term', 'Final Exam', 'Assignment', 'Quiz'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final tData = await ref.read(teacherDataProvider.future);
    if (!mounted) return;

    if (tData != null) {
      final tcs = tData['teacher_classes'] as List? ?? [];
      final classesInfo = <Map<String, dynamic>>[];
      for (final tc in tcs) {
        final c = tc['classes'];
        if (c != null) {
          classesInfo.add({
            'class_id': c['id'],
            'name': c['name'],
            'subject': tc['subject']
          });
        }
      }
      _myClasses = classesInfo;
    }
    setState(() => _loading = false);
  }

  Future<void> _loadStudents() async {
    if (_selectedClass == null) return;
    setState(() => _loadingStudents = true);
    
    try {
      final res = await supabase
          .from('students')
          .select('uuid, roll_number, profiles(name, photo_url)')
          .eq('class_id', _selectedClass!['class_id'])
          .order('roll_number');
          
      _students = List<Map<String, dynamic>>.from(res);
      _markControllers.clear();
      for (var s in _students) {
        _markControllers[s['uuid']] = TextEditingController();
      }
      
    } catch (_) {}
    if (mounted) setState(() => _loadingStudents = false);
  }

  Future<void> _saveMarks() async {
    if (_selectedClass == null || _examType == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select class and exam type.')));
      return;
    }
    
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    
    try {
      final records = <Map<String, dynamic>>[];
      for (var s in _students) {
        final markText = _markControllers[s['uuid']]?.text ?? '';
        if (markText.isNotEmpty && double.tryParse(markText) != null) {
          records.add({
            'student_uuid': s['uuid'],
            'subject': _selectedClass!['subject'],
            'exam_type': _examType,
            'marks_obtained': double.parse(markText),
            'total_marks': 100, // Hardcoded max marks for simplicity
            'recorded_by': supabase.auth.currentUser?.id,
          });
        }
      }
      
      if (records.isNotEmpty) {
        await supabase.from('marks').insert(records);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Marks saved successfully!'), backgroundColor: AppColors.success));
        for (var c in _markControllers.values) { c.clear(); }
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No valid marks entered.')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving marks: $e'), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Builder(builder: (ctx) => IconButton(
          icon: const Icon(Icons.menu_rounded),
          onPressed: () => Scaffold.of(ctx).openDrawer(),
        )),
        title: const Text('Add Marks'),
      ),
      drawer: const TeacherDrawer(),
      body: _loading 
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    DropdownButtonFormField<Map<String, dynamic>>(
                      decoration: InputDecoration(
                        labelText: 'Select Class & Subject',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      value: _selectedClass,
                      items: _myClasses.map((c) => DropdownMenuItem(
                        value: c,
                        child: Text('${c['name']} - ${c['subject']}'),
                      )).toList(),
                      onChanged: (v) {
                        setState(() => _selectedClass = v);
                        _loadStudents();
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Exam Type',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      value: _examType,
                      items: _examTypes.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      onChanged: (v) => setState(() => _examType = v),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              
              Expanded(
                child: _loadingStudents
                  ? const Center(child: CircularProgressIndicator())
                  : _selectedClass == null
                    ? Center(child: Text('Select a class to view students', style: GoogleFonts.publicSans(color: AppColors.textGray)))
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _students.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final s = _students[i];
                          final name = s['profiles']?['name'] ?? '--';
                          final roll = s['roll_number'] ?? '--';
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                            child: Row(
                              children: [
                                AppAvatar(name: name, photoUrl: s['profiles']?['photo_url'], size: 40),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(name, style: GoogleFonts.publicSans(fontSize: 14, fontWeight: FontWeight.w700)),
                                      Text('Roll: $roll', style: GoogleFonts.publicSans(fontSize: 12, color: AppColors.textGray)),
                                    ],
                                  )
                                ),
                                SizedBox(
                                  width: 80,
                                  child: TextField(
                                    controller: _markControllers[s['uuid']],
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    decoration: InputDecoration(
                                      hintText: '/ 100',
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              
              if (_students.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4))]),
                  child: ElevatedButton(
                    onPressed: _saveMarks,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Save Marks', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ),
            ],
          ),
    );
  }
}
