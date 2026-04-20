import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/auth_provider.dart';
import '../../supabase/supabase_config.dart';
import '../../theme/app_theme.dart';
import 'teacher_shell.dart';

class TeacherNotificationsScreen extends ConsumerStatefulWidget {
  const TeacherNotificationsScreen({super.key});
  @override
  ConsumerState<TeacherNotificationsScreen> createState() => _State();
}

class _State extends ConsumerState<TeacherNotificationsScreen> {
  List<Map<String, dynamic>> _notifications = [];
  List<Map<String, dynamic>> _myClasses = [];
  bool _loading = true;

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
          classesInfo.add({'class_id': c['id'], 'name': c['name']});
        }
      }
      _myClasses = classesInfo;
    }

    try {
      final user = supabase.auth.currentUser;
      final res = await supabase
          .from('notifications')
          .select('*, classes(name)')
          .eq('created_by', user?.id ?? '')
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _notifications = List<Map<String, dynamic>>.from(res);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showComposeDialog() {
    final titleCtrl = TextEditingController();
    final msgCtrl = TextEditingController();
    String? selClassId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setModalState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Compose Notification', style: GoogleFonts.publicSans(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                const SizedBox(height: 16),
                TextField(
                  controller: titleCtrl,
                  decoration: InputDecoration(
                    labelText: 'Title',
                    prefixIcon: const Icon(Icons.title),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: msgCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Message',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'Target Class (Leave empty for all your students)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: [
                    const DropdownMenuItem(value: 'ALL', child: Text('All My Classes')),
                    ..._myClasses.map((c) => DropdownMenuItem(
                      value: c['class_id'].toString(),
                      child: Text(c['name']),
                    ))
                  ],
                  onChanged: (v) => setModalState(() => selClassId = v),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () async {
                    if (titleCtrl.text.isEmpty || msgCtrl.text.isEmpty || selClassId == null) return;
                    Navigator.pop(ctx);
                    setState(() => _loading = true);
                    try {
                      final user = supabase.auth.currentUser;
                      await supabase.from('notifications').insert({
                        'title': titleCtrl.text,
                        'message': msgCtrl.text,
                        'target_role': 'student',
                        'class_id': selClassId == 'ALL' ? null : selClassId,
                        'created_by': user?.id,
                        'is_global': false,
                      });
                      _load();
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
                        setState(() => _loading = false);
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Send Notification', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                )
              ],
            ),
          );
        });
      },
    );
  }

  Future<void> _deleteNotification(String id) async {
    setState(() => _loading = true);
    try {
      await supabase.from('notifications').delete().eq('id', id);
      _load();
    } catch (_) {
      setState(() => _loading = false);
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
        title: const Text('Notifications Sent'),
      ),
      drawer: const TeacherDrawer(),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? Center(child: Text('No notifications sent yet.', style: GoogleFonts.publicSans(color: AppColors.textGray)))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _notifications.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) {
                    final n = _notifications[i];
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(20)),
                                child: Text(n['class_id'] == null ? 'All My Classes' : n['classes']?['name'] ?? 'Class', style: GoogleFonts.publicSans(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.primary)),
                              ),
                              IconButton(
                                constraints: const BoxConstraints(),
                                padding: EdgeInsets.zero,
                                icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.error),
                                onPressed: () => _deleteNotification(n['id']),
                              )
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(n['title'] ?? 'Notice', style: GoogleFonts.publicSans(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                          const SizedBox(height: 4),
                          Text(n['message'] ?? '', style: GoogleFonts.publicSans(fontSize: 13, color: AppColors.textGray)),
                        ],
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showComposeDialog,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.send_rounded, color: Colors.white),
      ),
    );
  }
}
