import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../supabase/supabase_config.dart';
import '../../theme/app_theme.dart';
import 'teacher_shell.dart';

class TeacherAttendanceScreen extends ConsumerStatefulWidget {
  const TeacherAttendanceScreen({super.key});
  @override
  ConsumerState<TeacherAttendanceScreen> createState() => _State();
}

class _State extends ConsumerState<TeacherAttendanceScreen> {
  List<Map<String, dynamic>> _sessions  = [];
  List<Map<String, dynamic>> _filtered  = [];
  List<Map<String, dynamic>> _classes   = [];
  bool      _loading       = true;
  String    _classFilter   = 'All';
  String    _subjectFilter = 'All';
  DateTime? _dateFilter;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      supabase
          .from('attendance_sessions')
          .select('id, session_date, subject, classes(id, name), attendance_records(status)')
          .order('session_date', ascending: false)
          .limit(100),
      supabase.from('classes').select('id, name').order('name'),
    ]);
    if (mounted) setState(() {
      _sessions = List<Map<String, dynamic>>.from(results[0] as List);
      _classes  = List<Map<String, dynamic>>.from(results[1] as List);
      _loading  = false;
    });
    _applyFilters();
  }

  void _applyFilters() {
    setState(() {
      _filtered = _sessions.where((s) {
        final cls  = (s['classes']?['name'] as String?) ?? '';
        final subj = (s['subject']           as String?) ?? '';
        final date = (s['session_date']       as String?) ?? '';
        final matchClass   = _classFilter   == 'All' || cls  == _classFilter;
        final matchSubject = _subjectFilter == 'All' || subj.toLowerCase().contains(_subjectFilter.toLowerCase());
        final matchDate    = _dateFilter    == null  || date == _dateFilter!.toIso8601String().split('T')[0];
        return matchClass && matchSubject && matchDate;
      }).toList();
    });
  }

  // Real avg attendance across filtered sessions
  double get _avgAttendance {
    if (_filtered.isEmpty) return 0;
    int present = 0, total = 0;
    for (final s in _filtered) {
      for (final r in (s['attendance_records'] as List? ?? [])) {
        total++;
        if (r['status'] == 'present' || r['status'] == 'late') present++;
      }
    }
    return total > 0 ? (present / total * 100) : 0;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateFilter ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate:  DateTime.now(),
    );
    setState(() => _dateFilter = picked);
    _applyFilters();
  }

  String _formatDate(String? d) {
    if (d == null || d.isEmpty) return '--';
    try {
      final dt = DateTime.parse(d);
      const m  = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${dt.day} ${m[dt.month - 1]} ${dt.year}';
    } catch (_) { return d; }
  }

  Map<String, int> _counts(Map s) {
    final recs = (s['attendance_records'] as List?) ?? [];
    return {
      'present': recs.where((r) => r['status'] == 'present').length,
      'absent':  recs.where((r) => r['status'] == 'absent').length,
      'late':    recs.where((r) => r['status'] == 'late').length,
    };
  }

  @override
  Widget build(BuildContext context) {
    // Unique subjects from all sessions for dropdown
    final subjects = ['All', ...{
      ..._sessions.map((s) => (s['subject'] as String?) ?? '').where((s) => s.isNotEmpty)
    }];

    return Scaffold(
      appBar: AppBar(
        leading: Builder(builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu_rounded), onPressed: () => Scaffold.of(ctx).openDrawer())),
        title: Text('Attendance', style: GoogleFonts.publicSans(fontWeight: FontWeight.w700)),
        actions: [
          if (_dateFilter != null || _classFilter != 'All' || _subjectFilter != 'All')
            TextButton(
              onPressed: () {
                setState(() { _dateFilter = null; _classFilter = 'All'; _subjectFilter = 'All'; });
                _applyFilters();
              },
              child: Text('Reset', style: GoogleFonts.publicSans(
                  color: AppColors.error, fontWeight: FontWeight.w600, fontSize: 12)),
            ),
          IconButton(icon: const Icon(Icons.ios_share_rounded), onPressed: () {}),
        ],
      ),
      drawer: const TeacherDrawer(),
      body: Column(
        children: [
          // ── Summary row ─────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(children: [
              Expanded(child: _SummaryCard(
                  label: 'SESSIONS',
                  value: '${_filtered.length}',
                  valueColor: AppColors.primary)),
              const SizedBox(width: 12),
              Expanded(child: _SummaryCard(
                  label: 'AVG ATTENDANCE',
                  value: '${_avgAttendance.round()}%',
                  valueColor: _avgAttendance >= 75 ? AppColors.success : AppColors.error)),
            ]),
          ),

          // ── Filters ─────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(children: [
              // Date picker
              Expanded(child: GestureDetector(
                onTap: _pickDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  decoration: BoxDecoration(
                      color: _dateFilter != null ? AppColors.primaryLight : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: _dateFilter != null ? AppColors.primary : AppColors.border)),
                  child: Row(children: [
                    Icon(Icons.calendar_today_outlined, size: 14,
                        color: _dateFilter != null ? AppColors.primary : AppColors.textGray),
                    const SizedBox(width: 6),
                    Expanded(child: Text(
                        _dateFilter == null ? 'All Dates' : _formatDate(_dateFilter!.toIso8601String()),
                        style: GoogleFonts.publicSans(fontSize: 13,
                            color: _dateFilter != null ? AppColors.primary : AppColors.textDark,
                            fontWeight: _dateFilter != null ? FontWeight.w600 : FontWeight.w500),
                        overflow: TextOverflow.ellipsis)),
                  ]),
                ),
              )),
              const SizedBox(width: 8),
              // Class dropdown
              Expanded(child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                    color: _classFilter != 'All' ? AppColors.primaryLight : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: _classFilter != 'All' ? AppColors.primary : AppColors.border)),
                child: DropdownButton<String>(
                  value: _classFilter,
                  isExpanded: true, isDense: true, underline: const SizedBox(),
                  icon: Icon(Icons.keyboard_arrow_down_rounded, size: 16,
                      color: _classFilter != 'All' ? AppColors.primary : AppColors.textGray),
                  items: ['All', ..._classes.map((c) => c['name'] as String)]
                      .map((v) => DropdownMenuItem(value: v,
                      child: Text(v, style: GoogleFonts.publicSans(fontSize: 13,
                          color: AppColors.textDark))))
                      .toList(),
                  onChanged: (v) { setState(() => _classFilter = v!); _applyFilters(); },
                ),
              )),
            ]),
          ),
          // Subject dropdown (full width)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                  color: _subjectFilter != 'All' ? AppColors.primaryLight : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: _subjectFilter != 'All' ? AppColors.primary : AppColors.border)),
              child: DropdownButton<String>(
                value: subjects.contains(_subjectFilter) ? _subjectFilter : 'All',
                isExpanded: true, isDense: true, underline: const SizedBox(),
                icon: Icon(Icons.keyboard_arrow_down_rounded, size: 16,
                    color: _subjectFilter != 'All' ? AppColors.primary : AppColors.textGray),
                items: subjects.map((v) => DropdownMenuItem(value: v,
                    child: Text(v, style: GoogleFonts.publicSans(fontSize: 13,
                        color: AppColors.textDark))))
                    .toList(),
                onChanged: (v) { setState(() => _subjectFilter = v!); _applyFilters(); },
              ),
            ),
          ),

          // ── Section label ────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(alignment: Alignment.centerLeft,
                child: Text('SESSIONS (${_filtered.length})', style: GoogleFonts.publicSans(
                    fontSize: 11, fontWeight: FontWeight.w700,
                    color: AppColors.textGray, letterSpacing: 1.2))),
          ),
          const SizedBox(height: 10),

          // ── Session list ─────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.event_busy_rounded, size: 48, color: AppColors.textLight),
              const SizedBox(height: 12),
              Text('No sessions found.',
                  style: GoogleFonts.publicSans(color: AppColors.textGray, fontSize: 14)),
              const SizedBox(height: 4),
              Text('Tap the button below to start scanning.',
                  style: GoogleFonts.publicSans(color: AppColors.textLight, fontSize: 12)),
            ]))
                : RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
                itemCount: _filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final s      = _filtered[i];
                  final counts = _counts(s);
                  final total  = counts['present']! + counts['absent']! + counts['late']!;
                  final pct    = total > 0
                      ? ((counts['present']! + counts['late']!) / total * 100).round()
                      : 0;
                  return _SessionCard(
                    date:            _formatDate(s['session_date']),
                    classAndSubject: '${s['classes']?['name'] ?? ''}  •  ${s['subject'] ?? ''}',
                    present: counts['present']!,
                    absent:  counts['absent']!,
                    late:    counts['late']!,
                    pct:     pct,
                  );
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/teacher/scanner'),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white),
        label: Text('New Session', style: GoogleFonts.publicSans(
            fontWeight: FontWeight.w700, color: Colors.white)),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label, value;
  final Color valueColor;
  const _SummaryCard({required this.label, required this.value, required this.valueColor});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: GoogleFonts.publicSans(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textGray, letterSpacing: 1)),
      const SizedBox(height: 6),
      Text(value, style: GoogleFonts.publicSans(fontSize: 16, fontWeight: FontWeight.w800, color: valueColor)),
    ]),
  );
}

class _SessionCard extends StatelessWidget {
  final String date, classAndSubject;
  final int present, absent, late, pct;
  const _SessionCard({required this.date, required this.classAndSubject,
    required this.present, required this.absent, required this.late, required this.pct});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(date, style: GoogleFonts.publicSans(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textDark)),
            const SizedBox(height: 3),
            Text(classAndSubject, style: GoogleFonts.publicSans(fontSize: 12, color: AppColors.textGray)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
                color: pct >= 75 ? AppColors.success.withOpacity(0.1) : AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20)),
            child: Text('$pct%', style: GoogleFonts.publicSans(
                fontSize: 13, fontWeight: FontWeight.w800,
                color: pct >= 75 ? AppColors.success : AppColors.error)),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          _Badge(label: 'P: $present', color: AppColors.success),
          const SizedBox(width: 8),
          _Badge(label: 'A: $absent',  color: AppColors.error),
          const SizedBox(width: 8),
          _Badge(label: 'L: $late',    color: AppColors.warning),
        ]),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          GestureDetector(
            onTap: () {},
            child: Row(children: [
              const Icon(Icons.download_outlined, size: 14, color: AppColors.primary),
              const SizedBox(width: 4),
              Text('EXPORT', style: GoogleFonts.publicSans(
                  fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary, letterSpacing: 0.5)),
            ]),
          ),
        ]),
      ],
    ),
  );
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
    child: Text(label, style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
  );
}