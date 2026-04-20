import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../supabase/supabase_config.dart';
import '../../theme/app_theme.dart';
import 'student_shell.dart';

class StudentMarksScreen extends ConsumerStatefulWidget {
  const StudentMarksScreen({super.key});
  @override
  ConsumerState<StudentMarksScreen> createState() => _State();
}

class _State extends ConsumerState<StudentMarksScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  List<Map<String, dynamic>> _marks = [];
  List<Map<String, dynamic>> _reports = [];
  List<String> _examTypes = ['All Subjects'];
  String _selectedType = 'All Subjects';
  bool _loading = true;

  @override
  void initState() { super.initState(); _tabCtrl = TabController(length: 2, vsync: this); _load(); }

  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    try {
      final student = await supabase.from('students').select('uuid').eq('profile_id', user.id).single();
      final uuid = student['uuid'];
      if (uuid == null) return;

      final results = await Future.wait([
        supabase.from('marks').select('*').eq('student_uuid', uuid).order('created_at', ascending: false),
        supabase.from('reports').select('id, title, file_url, created_at').eq('student_uuid', uuid).order('created_at', ascending: false),
      ]);

      final marks   = List<Map<String, dynamic>>.from(results[0] as List);
      final types   = marks.map((m) => m['exam_type'] as String).toSet().toList();

      if (mounted) setState(() {
        _marks    = marks;
        _reports  = List<Map<String, dynamic>>.from(results[1] as List);
        _examTypes = ['All Subjects', ...types];
        _loading  = false;
      });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  List<Map<String, dynamic>> get _filteredMarks => _selectedType == 'All Subjects'
      ? _marks : _marks.where((m) => m['exam_type'] == _selectedType).toList();

  Color _gradeColor(double pct) {
    if (pct >= 90) return AppColors.success;
    if (pct >= 75) return AppColors.primary;
    if (pct >= 60) return AppColors.warning;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Builder(builder: (ctx) => IconButton(
          icon: const Icon(Icons.menu_rounded),
          onPressed: () => Scaffold.of(ctx).openDrawer(),
        )),
        title: const Text('Academics'),
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textGray,
          labelStyle: GoogleFonts.publicSans(fontWeight: FontWeight.w700, fontSize: 14),
          tabs: const [
            Tab(icon: Icon(Icons.format_list_numbered_rounded, size: 16), text: 'Marks'),
            Tab(icon: Icon(Icons.description_outlined, size: 16), text: 'Reports'),
          ],
        ),
      ),
      drawer: const StudentDrawer(),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabCtrl,
              children: [
                // Marks tab
                Column(children: [
                  SizedBox(
                    height: 50,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: _examTypes.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        final t = _examTypes[i];
                        final sel = t == _selectedType;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedType = t),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: sel ? AppColors.primary : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: sel ? AppColors.primary : AppColors.border),
                            ),
                            child: Text(t, style: GoogleFonts.publicSans(
                              fontSize: 13, fontWeight: FontWeight.w600,
                              color: sel ? Colors.white : AppColors.textGray)),
                          ),
                        );
                      },
                    ),
                  ),
                  Expanded(
                    child: _filteredMarks.isEmpty
                        ? Center(child: Text('No marks yet', style: TextStyle(color: AppColors.textGray)))
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            itemCount: _filteredMarks.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (_, i) {
                              final m = _filteredMarks[i];
                              final pct = (m['percentage'] as num?)?.toDouble() ?? 0;
                              final gc  = _gradeColor(pct);
                              return Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white, borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Row(children: [
                                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Text(m['subject'] ?? '', style: GoogleFonts.publicSans(
                                        fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(6)),
                                        child: Text(m['exam_type'] ?? '', style: GoogleFonts.publicSans(
                                          fontSize: 11, color: AppColors.textGray, fontWeight: FontWeight.w500)),
                                      ),
                                    ])),
                                    Container(
                                      width: 36, height: 36,
                                      decoration: BoxDecoration(
                                        color: gc.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                                      child: Center(child: Text(m['grade'] ?? '--',
                                        style: GoogleFonts.publicSans(fontSize: 13, fontWeight: FontWeight.w800, color: gc))),
                                    ),
                                  ]),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Score: ${m['marks_obtained']} / ${m['total_marks']}',
                                        style: GoogleFonts.publicSans(fontSize: 13, color: AppColors.textGray)),
                                      Text('${pct.round()}%', style: GoogleFonts.publicSans(
                                        fontSize: 14, fontWeight: FontWeight.w700, color: gc)),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  LinearProgressIndicator(
                                    value: pct / 100,
                                    backgroundColor: AppColors.border,
                                    valueColor: AlwaysStoppedAnimation(gc),
                                    borderRadius: BorderRadius.circular(4),
                                    minHeight: 5,
                                  ),
                                ]),
                              );
                            },
                          ),
                  ),
                ]),

                // Reports tab
                _reports.isEmpty
                    ? Center(child: Text('No reports yet', style: TextStyle(color: AppColors.textGray)))
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _reports.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final r = _reports[i];
                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
                            child: Row(children: [
                              Container(
                                width: 40, height: 40,
                                decoration: BoxDecoration(color: AppColors.errorLight, borderRadius: BorderRadius.circular(10)),
                                child: const Icon(Icons.picture_as_pdf_rounded, color: AppColors.error, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(r['title'] ?? 'Report', style: GoogleFonts.publicSans(fontSize: 14, fontWeight: FontWeight.w600)),
                                Text(r['created_at']?.toString().split('T')[0] ?? '',
                                  style: GoogleFonts.publicSans(fontSize: 12, color: AppColors.textGray)),
                              ])),
                              IconButton(
                                icon: const Icon(Icons.download_rounded, color: AppColors.primary, size: 20),
                                onPressed: () {},
                              ),
                            ]),
                          );
                        },
                      ),
              ],
            ),
    );
  }
}
