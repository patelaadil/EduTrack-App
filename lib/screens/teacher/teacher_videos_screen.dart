import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/auth_provider.dart';
import '../../supabase/supabase_config.dart';
import '../../theme/app_theme.dart';
import 'teacher_shell.dart';

class TeacherVideosScreen extends ConsumerStatefulWidget {
  const TeacherVideosScreen({super.key});
  @override
  ConsumerState<TeacherVideosScreen> createState() => _State();
}

class _State extends ConsumerState<TeacherVideosScreen> {
  List<Map<String, dynamic>> _videos = [];
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
          classesInfo.add({
            'class_id': c['id'],
            'name': c['name'],
            'subject': tc['subject']
          });
        }
      }
      _myClasses = classesInfo;
    }

    try {
      final res = await supabase.from('videos').select('*, classes(name)').order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _videos = List<Map<String, dynamic>>.from(res);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showAddDialog() {
    final titleCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
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
                Text('Share Video Lesson', style: GoogleFonts.publicSans(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                const SizedBox(height: 16),
                TextField(
                  controller: titleCtrl,
                  decoration: InputDecoration(
                    labelText: 'Video Title',
                    prefixIcon: const Icon(Icons.title),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: urlCtrl,
                  decoration: InputDecoration(
                    labelText: 'YouTube URL',
                    prefixIcon: const Icon(Icons.link),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'Assign to Class',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: _myClasses.map((c) => DropdownMenuItem(
                    value: c['class_id'].toString(),
                    child: Text('${c['name']} (${c['subject']})'),
                  )).toList(),
                  onChanged: (v) => setModalState(() => selClassId = v),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () async {
                    if (titleCtrl.text.isEmpty || urlCtrl.text.isEmpty || selClassId == null) return;
                    Navigator.pop(ctx);
                    setState(() => _loading = true);
                    try {
                      await supabase.from('videos').insert({
                        'title': titleCtrl.text,
                        'video_url': urlCtrl.text,
                        'class_id': selClassId,
                      });
                      _load();
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error sharing video: $e'), backgroundColor: AppColors.error));
                        setState(() => _loading = false);
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Share Video', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                )
              ],
            ),
          );
        });
      },
    );
  }

  Future<void> _deleteVideo(String id) async {
    setState(() => _loading = true);
    try {
      await supabase.from('videos').delete().eq('id', id);
      _load();
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Videos')),
      drawer: const TeacherDrawer(),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _videos.isEmpty
              ? Center(child: Text('No videos shared yet.', style: GoogleFonts.publicSans(color: AppColors.textGray)))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _videos.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) {
                    final v = _videos[i];
                    return GestureDetector(
                      onTap: () {
                        final url = v['video_url'] as String?;
                        if (url != null && url.isNotEmpty) {
                          launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                        }
                      },
                      child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 50, height: 50,
                            decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(12)),
                            child: const Icon(Icons.play_circle_fill_rounded, color: AppColors.primary, size: 28),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(v['title'] ?? 'Video', style: GoogleFonts.publicSans(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                                const SizedBox(height: 4),
                                Text('Class: ${v['classes']?['name'] ?? '--'}', style: GoogleFonts.publicSans(fontSize: 12, color: AppColors.textGray)),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: AppColors.error),
                            onPressed: () => _deleteVideo(v['id']),
                          )
                        ],
                      ),
                    ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _myClasses.isEmpty
            ? () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You have no assigned classes to share videos with.')))
            : _showAddDialog,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }
}
