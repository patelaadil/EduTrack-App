import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../supabase/supabase_config.dart';
import '../../theme/app_theme.dart';
import 'student_shell.dart';

class StudentHolidaysScreen extends ConsumerStatefulWidget {
  const StudentHolidaysScreen({super.key});

  @override
  ConsumerState<StudentHolidaysScreen> createState() => _State();
}

class _State extends ConsumerState<StudentHolidaysScreen> {
  bool _loading = true;
  int _monthIndex = 0;
  List<Map<String, dynamic>> _holidays = [];
  DateTime _academicStart = DateTime(DateTime.now().month >= 4 ? DateTime.now().year : DateTime.now().year - 1, 4, 1);
  DateTime _academicEnd = DateTime(DateTime.now().month >= 4 ? DateTime.now().year + 1 : DateTime.now().year, 3, 31);
  DateTime _calendarEnd = DateTime(DateTime.now().month >= 4 ? DateTime.now().year + 1 : DateTime.now().year, 3, 31);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        supabase.from('academic_years').select('start_date, end_date, name').eq('is_active', true).maybeSingle(),
        supabase.from('holidays').select('date, end_date, reason').order('date'),
      ]);

      final year = results[0] as Map<String, dynamic>?;
      final holidays = (results[1] as List?)?.cast<Map<String, dynamic>>() ?? [];

      DateTime academicStart = _academicStart;
      DateTime academicEnd = _academicEnd;
      if (year != null) {
        academicStart = DateTime.parse(year['start_date'] as String);
        academicEnd = DateTime.parse(year['end_date'] as String);
      }

      final holidayEnd = _latestHolidayEnd(holidays);
      final calendarEnd = holidayEnd != null && holidayEnd.isAfter(academicEnd) ? holidayEnd : academicEnd;

      if (!mounted) return;
      setState(() {
        _academicStart = academicStart;
        _academicEnd = academicEnd;
        _calendarEnd = calendarEnd;
        _holidays = holidays;
        _monthIndex = _initialMonthIndex(holidays, calendarEnd);
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  DateTime? _latestHolidayEnd(List<Map<String, dynamic>> holidays) {
    DateTime? latest;
    for (final holiday in holidays) {
      final start = holiday['date'] as String?;
      final end = holiday['end_date'] as String? ?? start;
      final candidate = end ?? start;
      if (candidate == null) continue;
      final parsed = DateTime.tryParse(candidate);
      if (parsed == null) continue;
      if (latest == null || parsed.isAfter(latest)) latest = parsed;
    }
    return latest;
  }

  int _initialMonthIndex(List<Map<String, dynamic>> holidays, DateTime calendarEnd) {
    final months = _months(calendarEnd);
    final todayKey = '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}';
    final todayIndex = months.indexWhere((m) => m['key'] == todayKey);
    if (todayIndex >= 0) return todayIndex;
    final latestHoliday = _latestHolidayEnd(holidays);
    if (latestHoliday != null) {
      final latestKey = '${latestHoliday.year}-${latestHoliday.month.toString().padLeft(2, '0')}';
      final latestIndex = months.indexWhere((m) => m['key'] == latestKey);
      if (latestIndex >= 0) return latestIndex;
    }
    return months.isEmpty ? 0 : months.length - 1;
  }

  List<Map<String, dynamic>> _months([DateTime? endOverride]) {
    final end = endOverride ?? _calendarEnd;
    final months = <Map<String, dynamic>>[];
    var cursor = DateTime(_academicStart.year, _academicStart.month, 1);
    while (cursor.isBefore(DateTime(end.year, end.month + 1, 1))) {
      months.add({
        'date': cursor,
        'key': '${cursor.year}-${cursor.month.toString().padLeft(2, '0')}',
      });
      cursor = DateTime(cursor.year, cursor.month + 1, 1);
    }
    return months;
  }

  bool _isHolidayDate(String dateStr) {
    return _holidays.any((h) {
      final start = h['date'] as String?;
      final end = (h['end_date'] as String?) ?? start;
      if (start == null || end == null) return false;
      return dateStr.compareTo(start) >= 0 && dateStr.compareTo(end) <= 0;
    });
  }

  String _formatRange(Map<String, dynamic> h) {
    final start = h['date'] as String? ?? '';
    final end = h['end_date'] as String?;
    if (end != null && end != start) return '$start → $end';
    return start;
  }

  @override
  Widget build(BuildContext context) {
    final months = _months();
    final currentMonth = months.isEmpty ? null : months[_monthIndex.clamp(0, months.length - 1).toInt()];
    final monthDate = currentMonth?['date'] as DateTime?;
    final monthTitle = monthDate == null ? 'Holidays' : '${_monthNames[monthDate.month - 1]} ${monthDate.year}';
    final monthYear = monthDate?.year;
    final monthValue = monthDate?.month;
    final selectedMonthHolidays = currentMonth == null
        ? <Map<String, dynamic>>[]
        : _holidays.where((h) {
            final start = h['date'] as String? ?? '';
            final end = (h['end_date'] as String?) ?? start;
            final monthStart = '${monthYear!}-${monthValue!.toString().padLeft(2, '0')}-01';
            final monthEnd = '$monthYear-${monthValue.toString().padLeft(2, '0')}-${DateUtils.getDaysInMonth(monthYear, monthValue)}';
            return !(end.compareTo(monthStart) < 0 || start.compareTo(monthEnd) > 0);
          }).toList();

    return Scaffold(
      drawer: const StudentDrawer(),
      appBar: AppBar(
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu_rounded),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: const Text('Holidays'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Holiday Calendar', style: GoogleFonts.publicSans(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                        const SizedBox(height: 4),
                        Text(
                          'Browse vacations and special holidays in the visible holiday range.',
                          style: GoogleFonts.publicSans(fontSize: 12, color: AppColors.textGray),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                value: months.isEmpty ? null : _monthIndex.clamp(0, months.length - 1).toInt(),
                                decoration: const InputDecoration(labelText: 'Choose Month'),
                                items: List.generate(months.length, (index) {
                                  final dt = months[index]['date'] as DateTime;
                                  return DropdownMenuItem(
                                    value: index,
                                    child: Text('${_monthNames[dt.month - 1]} ${dt.year}'),
                                  );
                                }),
                                onChanged: (value) {
                                  if (value == null) return;
                                  setState(() => _monthIndex = value);
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            _NavButton(
                              icon: Icons.chevron_left_rounded,
                              onTap: _monthIndex <= 0 ? null : () => setState(() => _monthIndex--),
                            ),
                            const SizedBox(width: 8),
                            _NavButton(
                              icon: Icons.chevron_right_rounded,
                              onTap: months.isEmpty || _monthIndex >= months.length - 1
                                  ? null
                                  : () => setState(() => _monthIndex++),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(monthTitle, style: GoogleFonts.publicSans(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                        const SizedBox(height: 12),
                        _buildCalendar(monthDate),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            _LegendDot(color: AppColors.textGray, label: 'Sunday'),
                            _LegendDot(color: AppColors.error, label: 'Holiday'),
                            _LegendDot(color: AppColors.primary, label: 'Today'),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  Text('Holidays in this month', style: GoogleFonts.publicSans(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                  const SizedBox(height: 10),
                  if (selectedMonthHolidays.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
                      child: Text('No holidays in this month.', style: GoogleFonts.publicSans(color: AppColors.textGray)),
                    )
                  else
                    ...selectedMonthHolidays.map((h) => Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: AppColors.error.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                            child: const Icon(Icons.event_busy_rounded, color: AppColors.error, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_formatRange(h), style: GoogleFonts.publicSans(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                                const SizedBox(height: 3),
                                Text(h['reason']?.toString() ?? '', style: GoogleFonts.publicSans(fontSize: 12, color: AppColors.textGray)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )),
                ],
              ),
            ),
    );
  }

  Widget _buildCalendar(DateTime? monthDate) {
    if (monthDate == null) return const SizedBox.shrink();
    final daysInMonth = DateUtils.getDaysInMonth(monthDate.year, monthDate.month);
    final firstDay = DateTime(monthDate.year, monthDate.month, 1).weekday % 7;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: firstDay + daysInMonth,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
      ),
      itemBuilder: (context, index) {
        if (index < firstDay) {
          return const SizedBox.shrink();
        }

        final day = index - firstDay + 1;
        final dateStr = '${monthDate.year}-${monthDate.month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
        final isSunday = DateTime(monthDate.year, monthDate.month, day).weekday == DateTime.sunday;
        final isHoliday = _isHolidayDate(dateStr);
        final isToday = DateTime.now().year == monthDate.year &&
            DateTime.now().month == monthDate.month &&
            DateTime.now().day == day;

        Color bg = Colors.transparent;
        Color fg = AppColors.textDark;
        if (isSunday) { bg = AppColors.textGray.withOpacity(0.14); fg = AppColors.textGray; }
        if (isHoliday) { bg = AppColors.error.withOpacity(0.12); fg = AppColors.error; }
        if (isToday) { bg = AppColors.primary; fg = Colors.white; }

        return Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            border: isHoliday && !isToday ? Border.all(color: AppColors.error.withOpacity(0.28)) : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('$day', style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.w700, color: fg)),
              const SizedBox(height: 2),
              if (isSunday || isHoliday)
                Container(width: 4, height: 4, decoration: BoxDecoration(color: isHoliday ? AppColors.error : AppColors.textGray, shape: BoxShape.circle)),
            ],
          ),
        );
      },
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _NavButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: enabled ? AppColors.primaryLight : AppColors.bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(icon, color: enabled ? AppColors.primary : AppColors.textLight),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text(label, style: GoogleFonts.publicSans(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textGray)),
    ],
  );
}

const _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];
