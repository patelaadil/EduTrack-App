import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../supabase/supabase_config.dart';
import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import 'package:image_picker/image_picker.dart';

// ── Two phases: setup form → live camera ─────────────────────
enum _Phase { setup, scanning }

class TeacherScannerScreen extends ConsumerStatefulWidget {
  const TeacherScannerScreen({super.key});
  @override
  ConsumerState<TeacherScannerScreen> createState() => _TeacherScannerScreenState();
}

class _TeacherScannerScreenState extends ConsumerState<TeacherScannerScreen> {

  _Phase _phase = _Phase.setup;

  // ── Setup state ──────────────────────────────────────────────
  List<Map<String, dynamic>> _classes       = [];
  String?                    _selectedClassId;
  String?                    _selectedClassName;
  final _subjectCtrl = TextEditingController();
  int    _lateThreshold  = 15;
  bool   _loadingClasses = true;
  bool   _starting       = false;
  String _setupError     = '';

  // ── Scanning state ───────────────────────────────────────────
  String?                   _sessionId;
  MobileScannerController?  _camera;
  bool                      _processing    = false;
  Map<String, dynamic>?     _lastStudent;
  String?                   _lastStatus;   // present | late | already_marked | not_found
  int                       _presentCount  = 0;
  int                       _lateCount     = 0;
  final Set<String>         _markedUUIDs   = {};
  DateTime?                 _sessionStart;

  // ────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _camera?.dispose();
    super.dispose();
  }

  // ── Load only this teacher's assigned classes ────────────────
  Future<void> _loadClasses() async {
    try {
      final teacherData = await ref.read(teacherDataProvider.future);
      if (teacherData != null) {
        final tcs  = (teacherData['teacher_classes'] as List?) ?? [];
        final seen = <String>{};
        final list = tcs
            .map((tc) => tc['classes'] as Map<String, dynamic>?)
            .whereType<Map<String, dynamic>>()
            .where((c) => seen.add(c['id'] as String))
            .toList();
        if (mounted) setState(() { _classes = list; _loadingClasses = false; });
        return;
      }
    } catch (_) {}

    // Fallback: load all classes if teacher row not found
    final rows = await supabase.from('classes').select('id, name').order('name');
    if (mounted) setState(() {
      _classes       = List<Map<String, dynamic>>.from(rows as List);
      _loadingClasses = false;
    });
  }

  // ── Start session → create attendance_sessions row ───────────
  Future<void> _startSession() async {
    if (_selectedClassId == null) {
      setState(() => _setupError = 'Please select a class');
      return;
    }
    if (_subjectCtrl.text.trim().isEmpty) {
      setState(() => _setupError = 'Please enter a subject');
      return;
    }

    setState(() { _starting = true; _setupError = ''; });

    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('Not logged in');

      // Get teacher id
      final teacherRow = await supabase
          .from('teachers')
          .select('id')
          .eq('profile_id', user.id)
          .maybeSingle();

      // Get active academic year
      final yearRow = await supabase
          .from('academic_years')
          .select('id')
          .eq('is_active', true)
          .maybeSingle();

      final now     = DateTime.now();
      final today   = now.toIso8601String().split('T')[0];
      final timeStr = '${now.hour.toString().padLeft(2, '0')}:'
          '${now.minute.toString().padLeft(2, '0')}:00';

      final session = await supabase
          .from('attendance_sessions')
          .insert({
        'class_id':         _selectedClassId,
        'teacher_id':       teacherRow?['id'],
        'subject':          _subjectCtrl.text.trim(),
        'academic_year_id': yearRow?['id'],
        'session_date':     today,
        'start_time':       timeStr,
        'late_threshold':   _lateThreshold,
      })
          .select('id')
          .single();

      setState(() {
        _sessionId    = session['id'];
        _sessionStart = DateTime.now();
        _camera       = MobileScannerController(
          detectionSpeed: DetectionSpeed.noDuplicates,
        );
        _phase   = _Phase.scanning;
        _starting = false;
      });

    } catch (e) {
      setState(() {
        _setupError = e.toString().contains(':')
            ? e.toString().split(':').last.trim()
            : e.toString();
        _starting   = false;
      });
    }
  }

  // ── Handle QR scan → mark attendance ────────────────────────
  Future<void> _onScan(String uuid) async {
    if (_processing || _sessionId == null) return;
    setState(() { _processing = true; _lastStudent = null; _lastStatus = null; });

    try {
      // Find student by uuid
      final row = await supabase
          .from('students')
          .select('uuid, roll_number, profiles:profile_id(name, photo_url), classes(name)')
          .eq('uuid', uuid)
          .maybeSingle();

      if (row == null) {
        setState(() { _lastStatus = 'not_found'; _processing = false; });
        return;
      }

      // Already scanned this session?
      if (_markedUUIDs.contains(uuid)) {
        setState(() { _lastStudent = row; _lastStatus = 'already_marked'; _processing = false; });
        return;
      }

      // Present vs late based on elapsed time since session start
      final elapsed = DateTime.now().difference(_sessionStart!).inMinutes;
      final status  = elapsed <= _lateThreshold ? 'present' : 'late';

      await supabase.from('attendance_records').insert({
        'session_id':   _sessionId,
        'student_uuid': uuid,
        'status':       status,
        'scanned_at':   DateTime.now().toIso8601String(),
      });

      _markedUUIDs.add(uuid);
      setState(() {
        _lastStudent = row;
        _lastStatus  = status;
        if (status == 'present') _presentCount++;
        else _lateCount++;
        _processing = false;
      });

    } catch (e) {
      setState(() { _lastStatus = 'error'; _processing = false; });
    }
  }

  // ────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return _phase == _Phase.setup
        ? _buildSetup(context)
        : _buildScanning(context);
  }

  // ══════════════════════════════════════════════════════════════
  // PHASE 1 — Setup UI
  // ══════════════════════════════════════════════════════════════
  Widget _buildSetup(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text('New Attendance Session',
            style: GoogleFonts.publicSans(fontWeight: FontWeight.w700, fontSize: 17)),
      ),
      body: _loadingClasses
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.all(20),
        children: [

          // ── Header card ──────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1A6FD1), Color(0xFF1557A8)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [BoxShadow(
                  color: AppColors.primary.withOpacity(0.28),
                  blurRadius: 14, offset: const Offset(0, 5))],
            ),
            child: Row(children: [
              const Icon(Icons.qr_code_scanner_rounded, size: 40, color: Colors.white),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Configure Session',
                    style: GoogleFonts.publicSans(
                        color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('Select class, enter subject and set the late threshold',
                    style: GoogleFonts.publicSans(color: Colors.white70, fontSize: 12)),
              ])),
            ]),
          ),
          const SizedBox(height: 24),

          // ── Class selection ──────────────────────────
          _Label('SELECT CLASS'),
          const SizedBox(height: 10),
          if (_classes.isEmpty)
            _InfoBox('No classes assigned to you. Contact admin.')
          else
            ..._classes.map((cls) {
              final selected = cls['id'] == _selectedClassId;
              return GestureDetector(
                onTap: () => setState(() {
                  _selectedClassId   = cls['id'];
                  _selectedClassName = cls['name'];
                  _setupError        = '';
                }),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color:  selected ? AppColors.primaryLight : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected ? AppColors.primary : AppColors.border,
                      width: selected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(children: [
                    Icon(Icons.class_rounded, size: 18,
                        color: selected ? AppColors.primary : AppColors.textGray),
                    const SizedBox(width: 10),
                    Expanded(child: Text(cls['name'] ?? '',
                        style: GoogleFonts.publicSans(
                            fontSize: 14,
                            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                            color: selected ? AppColors.primary : AppColors.textDark))),
                    if (selected)
                      const Icon(Icons.check_circle_rounded,
                          size: 18, color: AppColors.primary),
                  ]),
                ),
              );
            }),
          const SizedBox(height: 20),

          // ── Subject ──────────────────────────────────
          _Label('SUBJECT'),
          const SizedBox(height: 10),
          TextField(
            controller: _subjectCtrl,
            onChanged: (_) => setState(() => _setupError = ''),
            decoration: InputDecoration(
              hintText: 'e.g. Mathematics, Science...',
              hintStyle: GoogleFonts.publicSans(color: AppColors.textLight),
              prefixIcon: const Icon(Icons.book_outlined, size: 18,
                  color: AppColors.textLight),
              contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
          const SizedBox(height: 20),

          // ── Late threshold slider ─────────────────────
          _Label('LATE THRESHOLD (MINUTES AFTER SESSION START)'),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(
                    'Students scanning after $_lateThreshold min will be marked  Late',
                    style: GoogleFonts.publicSans(
                        fontSize: 12, color: AppColors.textGray))),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(20)),
                  child: Text('$_lateThreshold min',
                      style: GoogleFonts.publicSans(
                          fontSize: 13, fontWeight: FontWeight.w700,
                          color: AppColors.primary)),
                ),
              ]),
              Slider(
                value:      _lateThreshold.toDouble(),
                min: 1, max: 30, divisions: 29,
                activeColor:   AppColors.primary,
                inactiveColor: AppColors.border,
                onChanged: (v) => setState(() => _lateThreshold = v.round()),
              ),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('1 min',  style: GoogleFonts.publicSans(
                    fontSize: 10, color: AppColors.textLight)),
                Text('30 min', style: GoogleFonts.publicSans(
                    fontSize: 10, color: AppColors.textLight)),
              ]),
            ]),
          ),

          // ── Error banner ──────────────────────────────
          if (_setupError.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.error.withOpacity(0.3)),
              ),
              child: Row(children: [
                const Icon(Icons.error_outline_rounded, size: 16, color: AppColors.error),
                const SizedBox(width: 8),
                Expanded(child: Text(_setupError,
                    style: GoogleFonts.publicSans(fontSize: 13, color: AppColors.error))),
              ]),
            ),
          ],
          const SizedBox(height: 28),

          // ── Start button ─────────────────────────────
          ElevatedButton.icon(
            onPressed: _starting ? null : _startSession,
            icon: _starting
                ? const SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.play_arrow_rounded, size: 24),
            label: Text(_starting ? 'Starting...' : 'Start Scanning',
                style: GoogleFonts.publicSans(
                    fontSize: 15, fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              minimumSize:         const Size(double.infinity, 56),
              backgroundColor:     AppColors.primary,
              foregroundColor:     Colors.white,
              disabledBackgroundColor: AppColors.border,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // PHASE 2 — Scanning UI
  // ══════════════════════════════════════════════════════════════
  Widget _buildScanning(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => _showEndDialog(context),
        ),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$_selectedClassName  •  ${_subjectCtrl.text}',
              style: GoogleFonts.publicSans(
                  color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
          Text('Late after $_lateThreshold min',
              style: GoogleFonts.publicSans(color: Colors.white54, fontSize: 11)),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.image_rounded),
            tooltip: 'Scan from Gallery',
            onPressed: () async {
              try {
                final picker = ImagePicker();
                final xfile = await picker.pickImage(source: ImageSource.gallery);
                if (xfile != null) {
                  final success = await _camera!.analyzeImage(xfile.path);
                  if (success == false && mounted) {
                     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No QR code found in image')));
                  }
                }
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error reading image: $e')));
              }
            },
          ),
          TextButton(
            onPressed: () => _showEndDialog(context),
            child: Text('END SESSION',
                style: GoogleFonts.publicSans(
                    color: AppColors.warning, fontWeight: FontWeight.w800,
                    fontSize: 12, letterSpacing: 0.4)),
          ),
        ],
      ),
      body: Stack(children: [

        // ── Live camera ──────────────────────────────────
        MobileScanner(
          controller: _camera!,
          onDetect: (capture) {
            final val = capture.barcodes.firstOrNull?.rawValue;
            if (val != null && val.isNotEmpty) _onScan(val);
          },
        ),

        // ── Top counter strip ─────────────────────────────
        Positioned(
          top: 0, left: 0, right: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Colors.black87, Colors.transparent],
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _Counter(label: 'Present', count: _presentCount, color: AppColors.success),
                _Counter(label: 'Late',    count: _lateCount,    color: AppColors.warning),
                _Counter(label: 'Total',   count: _markedUUIDs.length, color: Colors.white),
              ],
            ),
          ),
        ),

        // ── Scan frame overlay ────────────────────────────
        Center(
          child: Container(
            width: 240, height: 240,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.primary, width: 2.5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Stack(children: [
              _Corner(top: true,  left: true),
              _Corner(top: true,  left: false),
              _Corner(top: false, left: true),
              _Corner(top: false, left: false),
              Center(child: Text('Point at student QR card',
                  style: GoogleFonts.publicSans(color: Colors.white38, fontSize: 12))),
            ]),
          ),
        ),

        // ── Result card (bottom) ──────────────────────────
        if (_lastStatus != null)
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _statusColor().withOpacity(0.95),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [BoxShadow(color: Colors.black38, blurRadius: 12)],
              ),
              child: Row(children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12)),
                  child: Icon(_statusIcon(), color: Colors.white, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_statusTitle(),
                        style: GoogleFonts.publicSans(
                            color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                    if (_lastStudent != null) ...[
                      const SizedBox(height: 2),
                      Text(
                          '${_lastStudent!['profiles']?['name'] ?? '?'}'
                              '  •  Roll ${_lastStudent!['roll_number'] ?? '--'}',
                          style: GoogleFonts.publicSans(
                              color: Colors.white70, fontSize: 12)),
                    ],
                  ],
                )),
              ]),
            ),
          ),

        // ── Processing overlay ────────────────────────────
        if (_processing)
          Container(
            color: Colors.black45,
            child: const Center(child: CircularProgressIndicator(color: Colors.white)),
          ),
      ]),
    );
  }

  // ── Status helpers ───────────────────────────────────────────
  Color _statusColor() {
    switch (_lastStatus) {
      case 'present':        return AppColors.success;
      case 'late':           return AppColors.warning;
      case 'already_marked': return const Color(0xFF607D8B);
      default:               return AppColors.error;
    }
  }

  IconData _statusIcon() {
    switch (_lastStatus) {
      case 'present':        return Icons.check_circle_rounded;
      case 'late':           return Icons.watch_later_rounded;
      case 'already_marked': return Icons.info_rounded;
      default:               return Icons.cancel_rounded;
    }
  }

  String _statusTitle() {
    switch (_lastStatus) {
      case 'present':        return 'Marked Present ✓';
      case 'late':           return 'Marked Late ⏱';
      case 'already_marked': return 'Already Marked';
      case 'not_found':      return 'Student Not Found';
      default:               return 'Error — Try Again';
    }
  }

  // ── End session confirmation dialog ─────────────────────────
  void _showEndDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('End Session?',
            style: GoogleFonts.publicSans(fontWeight: FontWeight.w700, fontSize: 17)),
        content: Text(
            'Session Summary\n\n'
                '✅  Present  :  $_presentCount\n'
                '🕐  Late        :  $_lateCount\n'
                '📋  Total       :  ${_markedUUIDs.length} scanned',
            style: GoogleFonts.publicSans(fontSize: 14, height: 1.8)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Continue Scanning',
                  style: GoogleFonts.publicSans(
                      color: AppColors.primary, fontWeight: FontWeight.w600))),
          TextButton(
              onPressed: () { Navigator.pop(context); Navigator.pop(context); },
              child: Text('End Session',
                  style: GoogleFonts.publicSans(
                      color: AppColors.error, fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }
}

// ── Small helper widgets ──────────────────────────────────────

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: GoogleFonts.publicSans(
          fontSize: 11, fontWeight: FontWeight.w700,
          color: AppColors.textGray, letterSpacing: 1.1));
}

class _InfoBox extends StatelessWidget {
  final String text;
  const _InfoBox(this.text);
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border)),
      child: Text(text,
          style: GoogleFonts.publicSans(color: AppColors.textGray, fontSize: 13)));
}

class _Counter extends StatelessWidget {
  final String label;
  final int    count;
  final Color  color;
  const _Counter({required this.label, required this.count, required this.color});
  @override
  Widget build(BuildContext context) => Column(children: [
    Text('$count', style: GoogleFonts.publicSans(
        fontSize: 28, fontWeight: FontWeight.w800, color: color)),
    const SizedBox(height: 2),
    Text(label, style: GoogleFonts.publicSans(
        fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white60)),
  ]);
}

class _Corner extends StatelessWidget {
  final bool top, left;
  const _Corner({required this.top, required this.left});
  @override
  Widget build(BuildContext context) => Positioned(
    top:    top  ? 0 : null,
    bottom: top  ? null : 0,
    left:   left ? 0 : null,
    right:  left ? null : 0,
    child: Container(
      width: 26, height: 26,
      decoration: BoxDecoration(
        border: Border(
          top:    top  ? const BorderSide(color: Colors.white, width: 3) : BorderSide.none,
          bottom: !top ? const BorderSide(color: Colors.white, width: 3) : BorderSide.none,
          left:   left ? const BorderSide(color: Colors.white, width: 3) : BorderSide.none,
          right: !left ? const BorderSide(color: Colors.white, width: 3) : BorderSide.none,
        ),
      ),
    ),
  );
}