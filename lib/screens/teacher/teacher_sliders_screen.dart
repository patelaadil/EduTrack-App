import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../supabase/supabase_config.dart';
import '../../theme/app_theme.dart';
import 'teacher_shell.dart';

class TeacherSlidersScreen extends ConsumerStatefulWidget {
  const TeacherSlidersScreen({super.key});
  @override
  ConsumerState<TeacherSlidersScreen> createState() => _State();
}

class _State extends ConsumerState<TeacherSlidersScreen> {
  List<Map<String, dynamic>> _sliders = [];
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await supabase.from('sliders').select().order('order_index');
      if (mounted) {
        setState(() {
          _sliders = List<Map<String, dynamic>>.from(res);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addSlider() async {
    try {
      final picker = ImagePicker();
      final img = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (img == null) return;
      
      setState(() => _saving = true);
      final bytes = await img.readAsBytes();
      final ext = img.name.split('.').last;
      final fileName = '${const Uuid().v4()}.$ext';

      // 1. Upload to storage
      await supabase.storage.from('sliders').uploadBinary(fileName, bytes);
      final url = supabase.storage.from('sliders').getPublicUrl(fileName);

      // 2. Insert record
      await supabase.from('sliders').insert({
        'title': 'Announcement',
        'image_url': url,
        'order_index': _sliders.length + 1,
        'is_active': true,
      });

      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Slider added!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error adding slider: $e'), backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _toggleActive(String id, bool active) async {
    try {
      setState(() {
        _sliders.firstWhere((s) => s['id'] == id)['is_active'] = active;
      });
      await supabase.from('sliders').update({'is_active': active}).eq('id', id);
    } catch (_) {
      _load();
    }
  }

  Future<void> _deleteSlider(String id, String url) async {
    try {
      setState(() => _saving = true);
      // Remove from table
      await supabase.from('sliders').delete().eq('id', id);
      // Remove from bucket (extract filename)
      final uri = Uri.parse(url);
      final fileName = uri.pathSegments.last;
      await supabase.storage.from('sliders').remove([fileName]);
      
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting slider'), backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
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
        title: const Text('Slider Management'),
      ),
      drawer: const TeacherDrawer(),
      body: _loading || _saving
          ? const Center(child: CircularProgressIndicator())
          : _sliders.isEmpty
              ? Center(child: Text('No sliders found. Add one below.', style: GoogleFonts.publicSans(color: AppColors.textGray)))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _sliders.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (ctx, i) {
                    final s = _sliders[i];
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                            child: Image.network(s['image_url'], height: 160, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(height: 160, color: Colors.grey.shade200, child: const Icon(Icons.broken_image, color: Colors.grey))),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Switch(
                                      value: s['is_active'] == true,
                                      onChanged: (v) => _toggleActive(s['id'], v),
                                      activeColor: AppColors.primary,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(s['is_active'] == true ? 'Active' : 'Hidden', style: GoogleFonts.publicSans(fontSize: 14, fontWeight: FontWeight.w600, color: s['is_active'] == true ? AppColors.success : AppColors.textGray)),
                                  ],
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: AppColors.error),
                                  onPressed: () => _deleteSlider(s['id'], s['image_url']),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _sliders.length >= 5
            ? () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Maximum 5 sliders allowed!'), backgroundColor: AppColors.warning))
            : _addSlider,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add_photo_alternate_rounded, color: Colors.white),
      ),
    );
  }
}
