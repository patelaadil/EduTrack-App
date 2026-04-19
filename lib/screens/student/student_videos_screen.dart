import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../supabase/supabase_config.dart';
import '../../theme/app_theme.dart';

class StudentVideosScreen extends ConsumerStatefulWidget {
  const StudentVideosScreen({super.key});
  @override
  ConsumerState<StudentVideosScreen> createState() => _State();
}
class _State extends ConsumerState<StudentVideosScreen> {
  List<Map<String, dynamic>> _videos = [];
  bool _loading = true;
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    final data = await supabase.from('videos').select('id, title, subject, video_url, thumbnail_url, classes(name), teachers(profiles(name))').order('created_at', ascending: false);
    if (mounted) setState(() { _videos = List<Map<String, dynamic>>.from(data as List); _loading = false; });
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Class Videos')),
    body: _loading ? const Center(child: CircularProgressIndicator())
      : _videos.isEmpty ? Center(child: Text('No videos yet', style: TextStyle(color: AppColors.textGray)))
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
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    height: 140,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                      color: AppColors.primaryLight,
                      image: v['thumbnail_url'] != null ? DecorationImage(image: NetworkImage(v['thumbnail_url']), fit: BoxFit.cover) : null,
                    ),
                    child: Center(child: Icon(Icons.play_circle_fill_rounded, size: 48, color: v['thumbnail_url'] == null ? AppColors.primary : Colors.white.withOpacity(0.9))),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(v['title'] ?? '', style: GoogleFonts.publicSans(fontSize: 14, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text('${v['subject'] ?? ''} • ${v['teachers']?['profiles']?['name'] ?? ''}',
                        style: GoogleFonts.publicSans(fontSize: 12, color: AppColors.textGray)),
                    ]),
                  ),
                ]),
              ),
            );
          },
        ),
  );
}
