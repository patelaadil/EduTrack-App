import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_theme.dart';

class AppAvatar extends StatelessWidget {
  final String name;
  final String? photoUrl;
  final double size;
  final Color? color;

  const AppAvatar({super.key, required this.name, this.photoUrl, this.size = 40, this.color});

  Color get _color {
    if (color != null) return color!;
    final idx = name.isEmpty ? 0 : name.codeUnitAt(0) % AppColors.avatarColors.length;
    return AppColors.avatarColors[idx];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: _color.withOpacity(0.15)),
      clipBehavior: Clip.antiAlias,
      child: photoUrl != null && photoUrl!.isNotEmpty
          ? CachedNetworkImage(imageUrl: photoUrl!, fit: BoxFit.cover,
              placeholder: (_, __) => _initials(),
              errorWidget: (_, __, ___) => _initials())
          : _initials(),
    );
  }

  Widget _initials() {
    final parts = name.trim().split(' ');
    final initials = parts.length >= 2
        ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
        : name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Center(
      child: Text(initials, style: TextStyle(
        fontSize: size * 0.36, fontWeight: FontWeight.w700, color: _color,
      )),
    );
  }
}
