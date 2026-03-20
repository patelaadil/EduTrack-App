import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../providers/auth_provider.dart';
import '../../supabase/supabase_config.dart';
import '../../theme/app_theme.dart';
import 'student_shell.dart';

class StudentAttendanceScreen extends ConsumerStatefulWidget {
  const StudentAttendanceScreen({super.key});
  @override
  ConsumerState<StudentAttendanceScreen> createState() => _State();
}

class _State extends ConsumerState<StudentAttendanceScreen> {
  DateTime _focusedDay = DateTime.now();
  List<Map<String, dynamic>> _records = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final studentData = await ref.read(studentDataProvider.future);
    if (!mounted || studentData == null) return;
    try {
      final res = await supabase
          .from('attendance_records')
          .select('id, status, scanned_at, attendance_sessions(subject, session_date)')
          .eq('student_uuid', studentData['uuid']);
      if (mounted) {
        setState(() {
          _records = List<Map<String, dynamic>>.from(res);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> _getEventsForDay(DateTime day) {
    if (_records.isEmpty) return [];
    final dateStr = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    return _records.where((r) {
      final sd = r['attendance_sessions']?['session_date'];
      return sd != null && sd.startsWith(dateStr);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    int p = 0, a = 0, l = 0;
    for (var r in _records) {
      if (r['status'] == 'present') p++;
      else if (r['status'] == 'absent') a++;
      else if (r['status'] == 'late') l++;
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        leading: Builder(builder: (ctx) => IconButton(
          icon: const Icon(Icons.menu_rounded),
          onPressed: () => Scaffold.of(ctx).openDrawer(),
        )),
        title: const Text('My Attendance'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Downloading Report...'))),
          ),
        ],
      ),
      drawer: const StudentDrawer(),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Premium Summary Cards
                  Row(
                    children: [
                      Expanded(child: _SummaryBox(title: 'Present', count: p, color: AppColors.success, icon: Icons.check_circle_rounded)),
                      const SizedBox(width: 12),
                      Expanded(child: _SummaryBox(title: 'Late', count: l, color: AppColors.warning, icon: Icons.watch_later_rounded)),
                      const SizedBox(width: 12),
                      Expanded(child: _SummaryBox(title: 'Absent', count: a, color: AppColors.error, icon: Icons.cancel_rounded)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Premium Calendar Wrap
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 10))
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: TableCalendar(
                      firstDay: DateTime.utc(2022, 1, 1),
                      lastDay: DateTime.utc(2030, 12, 31),
                      focusedDay: _focusedDay,
                      onPageChanged: (d) => setState(() => _focusedDay = d),
                      headerStyle: HeaderStyle(
                        formatButtonVisible: false,
                        titleCentered: true,
                        titleTextStyle: GoogleFonts.publicSans(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textDark),
                        leftChevronIcon: const Icon(Icons.chevron_left_rounded, color: AppColors.primary),
                        rightChevronIcon: const Icon(Icons.chevron_right_rounded, color: AppColors.primary),
                      ),
                      daysOfWeekStyle: DaysOfWeekStyle(
                        weekdayStyle: GoogleFonts.publicSans(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textGray),
                        weekendStyle: GoogleFonts.publicSans(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textLight),
                      ),
                      calendarBuilders: CalendarBuilders(
                        defaultBuilder: (context, day, focusedDay) {
                          final events = _getEventsForDay(day);
                          if (events.isEmpty) return null;
                          final hasAbsent = events.any((e) => e['status'] == 'absent');
                          final hasLate = events.any((e) => e['status'] == 'late');
                          final color = hasAbsent ? AppColors.error : (hasLate ? AppColors.warning : AppColors.success);
                          
                          return Container(
                            margin: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [color.withOpacity(0.15), color.withOpacity(0.3)],
                                begin: Alignment.topLeft, end: Alignment.bottomRight
                              )
                            ),
                            alignment: Alignment.center,
                            child: Text('${day.day}', style: GoogleFonts.publicSans(fontWeight: FontWeight.w700, color: color)),
                          );
                        },
                        todayBuilder: (context, day, focusedDay) {
                          return Container(
                            margin: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primary,
                              boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))]
                            ),
                            alignment: Alignment.center,
                            child: Text('${day.day}', style: GoogleFonts.publicSans(fontWeight: FontWeight.w800, color: Colors.white)),
                          );
                        }
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Recent Logs', style: GoogleFonts.publicSans(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                      Text('All Logs', style: GoogleFonts.publicSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  if (_records.isEmpty)
                     Container(
                       padding: const EdgeInsets.all(20),
                       alignment: Alignment.center,
                       child: Text('No attendance records yet', style: GoogleFonts.publicSans(color: AppColors.textGray)),
                     )
                  else
                     ..._records.take(5).map((r) => _PremiumLogTile(record: r)),
                ],
              ),
            ),
    );
  }
}

class _SummaryBox extends StatelessWidget {
  final String title;
  final int count;
  final Color color;
  final IconData icon;
  
  const _SummaryBox({required this.title, required this.count, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 4))]
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 10),
          Text('$count', style: GoogleFonts.publicSans(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textDark)),
          Text(title, style: GoogleFonts.publicSans(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textGray)),
        ],
      ),
    );
  }
}

class _PremiumLogTile extends StatelessWidget {
  final Map<String, dynamic> record;
  const _PremiumLogTile({required this.record});

  @override
  Widget build(BuildContext context) {
    final status = record['status'];
    final subj = record['attendance_sessions']?['subject'] ?? 'System';
    final timeStr = record['scanned_at']?.split('T') ?? ['--', '--'];
    final time = timeStr.length > 1 ? timeStr[1].substring(0, 5) : '--';
    
    final color = status == 'present' ? AppColors.success : (status == 'late' ? AppColors.warning : AppColors.error);
    final icon = status == 'present' ? Icons.check_rounded : (status == 'late' ? Icons.watch_later_rounded : Icons.close_rounded);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [color.withOpacity(0.2), color.withOpacity(0.05)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(subj, style: GoogleFonts.publicSans(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                const SizedBox(height: 2),
                Text('Scanned at $time', style: GoogleFonts.publicSans(fontSize: 12, color: AppColors.textGray)),
              ],
            )
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
            child: Text(status.toUpperCase(), style: GoogleFonts.publicSans(fontSize: 11, fontWeight: FontWeight.w800, color: color, letterSpacing: 0.5)),
          ),
        ],
      )
    );
  }
}
