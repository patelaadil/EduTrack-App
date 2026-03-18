import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../supabase/supabase_config.dart';
import '../../theme/app_theme.dart';

class StudentAttendanceScreen extends ConsumerStatefulWidget {
  const StudentAttendanceScreen({super.key});
  @override
  ConsumerState<StudentAttendanceScreen> createState() => _State();
}

class _State extends ConsumerState<StudentAttendanceScreen> {
  DateTime _month = DateTime.now();
  Map<String, String> _dayStatus = {}; // 'YYYY-MM-DD' -> 'present'|'absent'|'late'
  List<String> _subjects = ['All'];
  String _selectedSubject = 'All';
  int _present = 0, _absent = 0, _late = 0;
  bool _loading = true;
  double _warningPct = 75;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    try {
      final student = await supabase.from('students').select('uuid').eq('profile_id', user.id).single();
      final uuid = student['uuid'];
      if (uuid == null) return;

      final start = DateTime(_month.year, _month.month, 1);
      final end   = DateTime(_month.year, _month.month + 1, 0);

      final records = await supabase
          .from('attendance_records')
          .select('status, scanned_at, attendance_sessions(session_date, subject)')
          .eq('student_uuid', uuid)
          .gte('attendance_sessions.session_date', start.toIso8601String().split('T')[0])
          .lte('attendance_sessions.session_date', end.toIso8601String().split('T')[0]);

      final recs = records as List;
      final statusMap = <String, String>{};
      final subjectSet = <String>{};

      for (final r in recs) {
        final date    = r['attendance_sessions']?['session_date'] as String?;
        final status  = r['status'] as String?;
        final subject = r['attendance_sessions']?['subject'] as String?;
        if (date != null && status != null) statusMap[date] = status;
        if (subject != null) subjectSet.add(subject);
      }

      final p = recs.where((r) => r['status'] == 'present').length;
      final a = recs.where((r) => r['status'] == 'absent').length;
      final l = recs.where((r) => r['status'] == 'late').length;

      if (mounted) setState(() {
        _dayStatus = statusMap;
        _subjects  = ['All', ...subjectSet];
        _present = p; _absent = a; _late = l;
        _loading = false;
      });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  void _prevMonth() { setState(() { _month = DateTime(_month.year, _month.month - 1); _loading = true; }); _load(); }
  void _nextMonth() { setState(() { _month = DateTime(_month.year, _month.month + 1); _loading = true; }); _load(); }

  Color? _dayColor(String dateStr) {
    final s = _dayStatus[dateStr];
    if (s == 'present') return AppColors.success;
    if (s == 'absent')  return AppColors.error;
    if (s == 'late')    return AppColors.warning;
    return null;
  }

  double get _pct {
    final total = _present + _absent + _late;
    return total > 0 ? (_present + _late) / total * 100 : 100;
  }

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final firstWeekday = DateTime(_month.year, _month.month, 1).weekday % 7;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Attendance'),
        actions: [IconButton(icon: const Icon(Icons.download_outlined), onPressed: () {})],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Summary tiles
                      Row(children: [
                        _SummaryTile(value: '$_present', label: 'PRESENT', color: AppColors.success),
                        const SizedBox(width: 10),
                        _SummaryTile(value: '$_absent', label: 'ABSENT', color: AppColors.error),
                        const SizedBox(width: 10),
                        _SummaryTile(value: '$_late', label: 'LATE', color: AppColors.warning),
                      ]),
                      const SizedBox(height: 14),

                      // Subject filter chips
                      SizedBox(
                        height: 40,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _subjects.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (_, i) {
                            final sub = _subjects[i];
                            final sel = sub == _selectedSubject;
                            return GestureDetector(
                              onTap: () => setState(() => _selectedSubject = sub),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: sel ? AppColors.primary : Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: sel ? AppColors.primary : AppColors.border),
                                ),
                                child: Text(sub, style: GoogleFonts.publicSans(
                                  fontSize: 13, fontWeight: FontWeight.w600,
                                  color: sel ? Colors.white : AppColors.textGray)),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Calendar
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
                        child: Column(children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(DateFormat('MMMM yyyy').format(_month),
                                style: GoogleFonts.publicSans(fontSize: 16, fontWeight: FontWeight.w800)),
                              Row(children: [
                                GestureDetector(onTap: _prevMonth, child: const Icon(Icons.chevron_left_rounded, size: 22, color: AppColors.textGray)),
                                const SizedBox(width: 8),
                                GestureDetector(onTap: _nextMonth, child: const Icon(Icons.chevron_right_rounded, size: 22, color: AppColors.textGray)),
                              ]),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Day headers
                          Row(children: ['S','M','T','W','T','F','S'].map((d) => Expanded(
                            child: Center(child: Text(d, style: GoogleFonts.publicSans(
                              fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textGray))),
                          )).toList()),
                          const SizedBox(height: 8),
                          // Calendar grid
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, mainAxisSpacing: 6, crossAxisSpacing: 4),
                            itemCount: firstWeekday + daysInMonth,
                            itemBuilder: (_, i) {
                              if (i < firstWeekday) return const SizedBox();
                              final day   = i - firstWeekday + 1;
                              final date  = DateTime(_month.year, _month.month, day);
                              final dateStr = DateFormat('yyyy-MM-dd').format(date);
                              final color = _dayColor(dateStr);
                              final isWeekend = date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
                              return Container(
                                decoration: BoxDecoration(
                                  color: color ?? (isWeekend ? Colors.transparent : null),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(child: Text('$day', style: GoogleFonts.publicSans(
                                  fontSize: 12, fontWeight: FontWeight.w600,
                                  color: color != null ? Colors.white : isWeekend ? AppColors.textLight : AppColors.textDark))),
                              );
                            },
                          ),
                        ]),
                      ),
                    ],
                  ),
                ),

                // Warning banner
                if (_pct < _warningPct)
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.warningLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.warning.withOpacity(0.4)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 20),
                      const SizedBox(width: 10),
                      Expanded(child: Text(
                        'Your attendance is below ${_warningPct.round()}%. Please attend regularly.',
                        style: GoogleFonts.publicSans(fontSize: 13, color: AppColors.warning, fontWeight: FontWeight.w500))),
                    ]),
                  ),
              ],
            ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String value, label;
  final Color color;
  const _SummaryTile({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(14)),
      child: Column(children: [
        Text(value, style: GoogleFonts.publicSans(fontSize: 26, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 3),
        Text(label, style: GoogleFonts.publicSans(fontSize: 10, fontWeight: FontWeight.w700, color: color, letterSpacing: 0.8)),
      ]),
    ),
  );
}
