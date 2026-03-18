import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const primary      = Color(0xFF1A6FD1);
  static const primaryDark  = Color(0xFF1557A8);
  static const primaryLight = Color(0xFFEFF6FF);
  static const success      = Color(0xFF16A34A);
  static const successLight = Color(0xFFDCFCE7);
  static const warning      = Color(0xFFD97706);
  static const warningLight = Color(0xFFFEF9C3);
  static const error        = Color(0xFFDC2626);
  static const errorLight   = Color(0xFFFEE2E2);
  static const bg           = Color(0xFFF8FAFC);
  static const card         = Color(0xFFFFFFFF);
  static const border       = Color(0xFFE2E8F0);
  static const textDark     = Color(0xFF0F172A);
  static const textGray     = Color(0xFF64748B);
  static const textLight    = Color(0xFF94A3B8);
  static const List<Color> avatarColors = [
    Color(0xFF1A6FD1), Color(0xFF7C3AED), Color(0xFF059669),
    Color(0xFFD97706), Color(0xFFDC2626), Color(0xFF0891B2),
  ];
}

class AppTheme {
  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary, background: AppColors.bg),
    textTheme: GoogleFonts.publicSansTextTheme(),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.card,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      shadowColor: AppColors.border,
      centerTitle: true,
      titleTextStyle: GoogleFonts.publicSans(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textDark),
      iconTheme: const IconThemeData(color: AppColors.textDark),
    ),
    cardTheme: CardThemeData(
      color: AppColors.card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: GoogleFonts.publicSans(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.bg,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: GoogleFonts.publicSans(color: AppColors.textLight, fontSize: 14),
    ),
  );
}
