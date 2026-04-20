import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../supabase/supabase_config.dart';
import '../theme/app_theme.dart';

class ReadOnlyHolidayView extends StatefulWidget {
  const ReadOnlyHolidayView({super.key});

  @override
  State<ReadOnlyHolidayView> createState() => _ReadOnlyHolidayViewState();
}

class _ReadOnlyHolidayViewState extends State<ReadOnlyHolidayView> {
  bool _loading = true;
  int _monthIndex = 0;
  List<Map<String, dynamic>> _holidays = [];
  String _errorMessage = '';
  DateTime _academicStart = DateTime(DateTime.now().month >= 4 ? DateTime.now().year : DateTime.now().year - 1, 4, 1);
  DateTime _academicEnd = DateTime(DateTime.now().month >= 4 ? DateTime.now().year + 1 : DateTime.now().year, 3, 31);
  DateTime _calendarEnd = DateTime(DateTime.now().month >= 4 ? DateTime.now().year + 1 : DateTime.now().year, 3, 31);
  String _academicName = '';

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

      var academicStart = _academicStart;
      var academicEnd = _academicEnd;
      var academicName = '${academicStart.year}-${academicEnd.year}';
      if (year != null) {
        academicStart = DateTime.parse(year['start_date'] as String);
        academicEnd = DateTime.parse(year['end_date'] as String);
        academicName = (year['name'] as String?)?.trim().isNotEmpty == true
            ? year['name'] as String
            : '${academicStart.year}-${academicEnd.year}';
      }

      final latestHolidayEnd = _latestHolidayEnd(holidays);
      final calendarEnd = latestHolidayEnd != null && latestHolidayEnd.isAfter(academicEnd)
          ? latestHolidayEnd
          : academicEnd;

      if (!mounted) return;
      setState(() {
        _academicStart = academicStart;
        _academicEnd = academicEnd;
        _academicName = academicName;
        _calendarEnd = calendarEnd;
        _holidays = holidays;
        _monthIndex = _initialMonthIndex(holidays, calendarEnd);
        _errorMessage = '';
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _mapHolidayError(error.toString());
        _loading = false;
      });
    }
  }

  String _mapHolidayError(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('relation') && lower.contains('holidays')) {
      return 'The holidays table could not be found in Supabase.';
    }
    if (lower.contains('permission') || lower.contains('row-level security') || lower.contains('policy')) {
      return 'The app does not have permission to read holidays from Supabase.';
    }
    return 'Holiday data could not be loaded from Supabase.';
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
    if (todayIndex >= 0 && _monthContainsHoliday(months[todayIndex]['date'] as DateTime, holidays)) {
      return todayIndex;
    }

    if (todayIndex >= 0) {
      for (int i = todayIndex; i < months.length; i++) {
        if (_monthContainsHoliday(months[i]['date'] as DateTime, holidays)) return i;
      }
    }

    final latestHoliday = _latestHolidayEnd(holidays);
    if (latestHoliday != null) {
      final latestKey = '${latestHoliday.year}-${latestHoliday.month.toString().padLeft(2, '0')}';
      final latestIndex = months.indexWhere((m) => m['key'] == latestKey);
      if (latestIndex >= 0) return latestIndex;
    }

    return months.isEmpty ? 0 : months.length - 1;
  }

  bool _monthContainsHoliday(DateTime monthDate, List<Map<String, dynamic>> holidays) {
    final monthStart = '${monthDate.year}-${monthDate.month.toString().padLeft(2, '0')}-01';
    final monthEnd =
        '${monthDate.year}-${monthDate.month.toString().padLeft(2, '0')}-${DateUtils.getDaysInMonth(monthDate.year, monthDate.month)}';

    return holidays.any((holiday) {
      final start = holiday['date'] as String? ?? '';
      final end = (holiday['end_date'] as String?) ?? start;
      return !(end.compareTo(monthStart) < 0 || start.compareTo(monthEnd) > 0);
    });
  }

  List<Map<String, dynamic>> _months([DateTime? endOverride]) {
    final end = endOverride ?? _calendarEnd;
    final months = <Map<String, dynamic>>[];
    var cursor = DateTime(_academicStart.year, _academicStart.month, 1);
    final lastVisibleMonth = DateTime(end.year, end.month, 1);

    while (!cursor.isAfter(lastVisibleMonth)) {
      months.add({
        'date': cursor,
        'key': '${cursor.year}-${cursor.month.toString().padLeft(2, '0')}',
      });
      cursor = DateTime(cursor.year, cursor.month + 1, 1);
    }

    return months;
  }

  bool _isHolidayDate(String dateStr) {
    return _holidays.any((holiday) {
      final start = holiday['date'] as String?;
      final end = (holiday['end_date'] as String?) ?? start;
      if (start == null || end == null) return false;
      return dateStr.compareTo(start) >= 0 && dateStr.compareTo(end) <= 0;
    });
  }

  String _formatRange(Map<String, dynamic> holiday) {
    final start = holiday['date'] as String? ?? '';
    final end = holiday['end_date'] as String?;
    if (end != null && end != start) return '$start -> $end';
    return start;
  }

  List<Map<String, dynamic>> _selectedMonthHolidays(DateTime? monthDate) {
    if (monthDate == null) return [];
    final monthStart = '${monthDate.year}-${monthDate.month.toString().padLeft(2, '0')}-01';
    final monthEnd = '${monthDate.year}-${monthDate.month.toString().padLeft(2, '0')}-${DateUtils.getDaysInMonth(monthDate.year, monthDate.month)}';
    return _holidays.where((holiday) {
      final start = holiday['date'] as String? ?? '';
      final end = (holiday['end_date'] as String?) ?? start;
      return !(end.compareTo(monthStart) < 0 || start.compareTo(monthEnd) > 0);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final months = _months();
    final safeIndex = months.isEmpty ? 0 : _monthIndex.clamp(0, months.length - 1);
    final selectedMonth = months.isEmpty ? null : months[safeIndex];
    final monthDate = selectedMonth?['date'] as DateTime?;
    final monthLabel = monthDate == null ? 'Month View' : '${_monthNames[monthDate.month - 1]} ${monthDate.year}';
    final selectedMonthHolidays = _selectedMonthHolidays(monthDate);

    return _loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _HeaderCard(holidayCount: _holidays.length, academicName: _academicName),
                const SizedBox(height: 16),
                _errorMessage.isNotEmpty
                    ? _StatusBanner(
                        icon: Icons.error_outline_rounded,
                        message: _errorMessage,
                        background: AppColors.warning.withOpacity(0.12),
                        border: AppColors.warning.withOpacity(0.28),
                        foreground: AppColors.textDark,
                      )
                    : const _InfoBanner(),
                const SizedBox(height: 16),
                _MonthViewCard(
                  months: months,
                  monthIndex: safeIndex,
                  monthLabel: monthLabel,
                  onBack: safeIndex <= 0 ? null : () => setState(() => _monthIndex = safeIndex - 1),
                  onForward: months.isEmpty || safeIndex >= months.length - 1 ? null : () => setState(() => _monthIndex = safeIndex + 1),
                  onMonthChanged: (value) => setState(() => _monthIndex = value),
                  child: monthDate == null
                      ? const Padding(
                          padding: EdgeInsets.all(20),
                          child: Center(child: Text('No academic year found.')),
                        )
                      : _MonthCard(monthDate: monthDate, isHolidayDate: _isHolidayDate),
                ),
                const SizedBox(height: 16),
                _MonthHolidayList(
                  title: 'Holidays in ${monthDate == null ? 'this month' : monthLabel}',
                  holidays: selectedMonthHolidays,
                  formatRange: _formatRange,
                ),
              ],
            ),
          );
  }
}

class _HeaderCard extends StatelessWidget {
  final int holidayCount;
  final String academicName;

  const _HeaderCard({required this.holidayCount, required this.academicName});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Holiday Management',
              style: GoogleFonts.publicSans(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textDark),
            ),
          ),
          _Badge(label: '$holidayCount holidays', active: true),
          const SizedBox(width: 8),
          _Badge(label: academicName, active: false),
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.info_outline_rounded, size: 16, color: AppColors.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Read-only holiday calendar from admin panel. Any holiday added in admin will appear here automatically.',
              style: GoogleFonts.publicSans(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final IconData icon;
  final String message;
  final Color background;
  final Color border;
  final Color foreground;

  const _StatusBanner({
    required this.icon,
    required this.message,
    required this.background,
    required this.border,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 16, color: foreground),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.publicSans(fontSize: 13, color: foreground, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthViewCard extends StatelessWidget {
  final List<Map<String, dynamic>> months;
  final int monthIndex;
  final String monthLabel;
  final VoidCallback? onBack;
  final VoidCallback? onForward;
  final ValueChanged<int> onMonthChanged;
  final Widget child;

  const _MonthViewCard({
    required this.months,
    required this.monthIndex,
    required this.monthLabel,
    required this.onBack,
    required this.onForward,
    required this.onMonthChanged,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      monthLabel,
                      style: GoogleFonts.publicSans(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Pick a month inside the visible holiday range',
                      style: GoogleFonts.publicSans(fontSize: 11, color: AppColors.textGray),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  _ControlButton(icon: Icons.chevron_left_rounded, label: 'Back', onTap: onBack),
                  const SizedBox(width: 8),
                  _ControlButton(icon: Icons.chevron_right_rounded, label: 'Forward', onTap: onForward),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<int>(
            value: months.isEmpty ? null : monthIndex,
            decoration: const InputDecoration(
              labelText: 'Choose Month',
              filled: true,
              fillColor: Color(0xFFF8FAFC),
            ),
            items: List.generate(months.length, (index) {
              final date = months[index]['date'] as DateTime;
              return DropdownMenuItem<int>(
                value: index,
                child: Text('${_monthNames[date.month - 1]} ${date.year}'),
              );
            }),
            onChanged: (value) {
              if (value != null) onMonthChanged(value);
            },
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _MonthCard extends StatelessWidget {
  final DateTime monthDate;
  final bool Function(String dateStr) isHolidayDate;

  const _MonthCard({
    required this.monthDate,
    required this.isHolidayDate,
  });

  @override
  Widget build(BuildContext context) {
    final monthLabel = '${_monthNames[monthDate.month - 1]} ${monthDate.year}';
    final daysInMonth = DateUtils.getDaysInMonth(monthDate.year, monthDate.month);
    final firstDay = DateTime(monthDate.year, monthDate.month, 1).weekday % 7;
    final today = DateTime.now();

    final cells = <Widget>[];
    for (int i = 0; i < firstDay; i++) {
      cells.add(const SizedBox());
    }

    for (int day = 1; day <= daysInMonth; day++) {
      final dateStr = '${monthDate.year}-${monthDate.month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
      final isSunday = DateTime(monthDate.year, monthDate.month, day).weekday == DateTime.sunday;
      final isHoliday = isHolidayDate(dateStr);
      final isToday = today.year == monthDate.year && today.month == monthDate.month && today.day == day;

      Color bg = Colors.transparent;
      Color fg = AppColors.textDark;
      if (isSunday) {
        bg = AppColors.textGray.withOpacity(0.10);
        fg = AppColors.textGray;
      }
      if (isHoliday) {
        bg = AppColors.error.withOpacity(0.12);
        fg = AppColors.error;
      }
      if (isToday) {
        bg = AppColors.primary;
        fg = Colors.white;
      }

      cells.add(
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
            border: isHoliday && !isToday
                ? Border.all(color: AppColors.error.withOpacity(0.25), width: 1.5)
                : Border.all(color: Colors.transparent, width: 1.5),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Text(
                '$day',
                style: GoogleFonts.publicSans(
                  fontSize: 13,
                  fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                  color: fg,
                ),
              ),
              if ((isSunday || isHoliday) && !isToday)
                Positioned(
                  bottom: 3,
                  child: Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isHoliday ? AppColors.error : AppColors.textGray,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.primary.withOpacity(0.35), width: 1.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      monthLabel,
                      style: GoogleFonts.publicSans(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Selected month',
                      style: GoogleFonts.publicSans(fontSize: 11, color: AppColors.textGray),
                    ),
                  ],
                ),
              ),
              _Badge(label: monthLabel, active: true),
            ],
          ),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.2,
            children: const [
              _WeekdayCell('SUN'),
              _WeekdayCell('MON'),
              _WeekdayCell('TUE'),
              _WeekdayCell('WED'),
              _WeekdayCell('THU'),
              _WeekdayCell('FRI'),
              _WeekdayCell('SAT'),
            ],
          ),
          const SizedBox(height: 6),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
            childAspectRatio: 1,
            children: cells,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 14,
            runSpacing: 8,
            children: const [
              _LegendDot(color: AppColors.textGray, label: 'Sunday'),
              _LegendDot(color: AppColors.error, label: 'Holiday'),
              _LegendDot(color: AppColors.primary, label: 'Today'),
            ],
          ),
        ],
      ),
    );
  }
}

class _MonthHolidayList extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> holidays;
  final String Function(Map<String, dynamic> holiday) formatRange;

  const _MonthHolidayList({
    required this.title,
    required this.holidays,
    required this.formatRange,
  });

  String _dayName(String value) {
    final date = DateTime.tryParse(value);
    if (date == null) return '--';
    return _dayNames[date.weekday - 1];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Text(
              title,
              style: GoogleFonts.publicSans(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark),
            ),
          ),
          if (holidays.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No holidays in this month.',
                style: GoogleFonts.publicSans(fontSize: 13, color: AppColors.textGray),
              ),
            )
          else
            ...holidays.asMap().entries.map((entry) {
              final index = entry.key;
              final holiday = entry.value;
              return Container(
                color: index.isEven ? Colors.white : const Color(0xFFFAFBFD),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: _ListColumn(label: 'DATE', value: formatRange(holiday), bold: true)),
                    Expanded(flex: 2, child: _ListColumn(label: 'DAY', value: _dayName(holiday['date']?.toString() ?? ''))),
                    Expanded(flex: 3, child: _ListColumn(label: 'REASON', value: holiday['reason']?.toString() ?? '--')),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _ListColumn extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;

  const _ListColumn({
    required this.label,
    required this.value,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.publicSans(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textGray, letterSpacing: 0.5),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.publicSans(
              fontSize: 13,
              fontWeight: bold ? FontWeight.w600 : FontWeight.w500,
              color: bold ? AppColors.textDark : AppColors.textGray,
            ),
          ),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textDark,
        side: BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final bool active;

  const _Badge({required this.label, required this.active});

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.primary : AppColors.textGray;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.publicSans(fontSize: 11, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.publicSans(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textGray),
        ),
      ],
    );
  }
}

class _WeekdayCell extends StatelessWidget {
  final String label;

  const _WeekdayCell(this.label);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        label,
        style: GoogleFonts.publicSans(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textGray, letterSpacing: 0.5),
      ),
    );
  }
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

const _dayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];
