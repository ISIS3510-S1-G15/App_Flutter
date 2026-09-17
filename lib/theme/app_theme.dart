import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const background = Color(0xFFF5E8DC); // fondo general de las pantallas
  static const dark = Color(0xFF1A1512);        // texto principal, tarjetas destacadas, bottom nav, ícono de perfil
  static const accent = Color(0xFFE8622C);      // badges
  static const open = Color(0xFF119A00);        // ícono de estado "Open"
  static const closed = Color(0xFFA6A6A6);      // ícono de estado "Closed"
  static const card = Color(0xFFFFFFFF);        // tarjetas individuales de restaurante
}

class AppTextStyles {
  // Primary Headlines: Bold/ExtraBold, 24–28pt
  static TextStyle headline = GoogleFonts.poppins(
    fontSize: 26,
    fontWeight: FontWeight.w800, // ExtraBold
    color: AppColors.dark,
  );

  // Card Titles: Bold, 18–20pt
  static TextStyle cardTitle = GoogleFonts.poppins(
    fontSize: 19,
    fontWeight: FontWeight.w700, // Bold
    color: AppColors.dark,
  );

  // Buttons / CTAs: Bold, 16pt
  static TextStyle button = GoogleFonts.poppins(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: AppColors.card, // texto blanco sobre fondo oscuro/acento
  );

  // Navigation Labels & Badges: Bold/SemiBold, 11–12pt, con letter-spacing
  static TextStyle navLabel = GoogleFonts.poppins(
    fontSize: 11.5,
    fontWeight: FontWeight.w600, // SemiBold
    color: AppColors.dark,
    letterSpacing: 0.4,
  );

  // Secondary / Supporting Text: Regular/Medium, 13–14pt
  static TextStyle body = GoogleFonts.poppins(
    fontSize: 13.5,
    fontWeight: FontWeight.w400, // Regular
    color: AppColors.dark,
  );

  static TextStyle bodyMedium = GoogleFonts.poppins(
    fontSize: 13.5,
    fontWeight: FontWeight.w500, // Medium
    color: AppColors.dark,
  );
}

final ThemeData appTheme = ThemeData(
  scaffoldBackgroundColor: AppColors.background,
  textTheme: GoogleFonts.poppinsTextTheme(),
  colorScheme: ColorScheme.fromSeed(
    seedColor: AppColors.accent,
    surface: AppColors.background,
  ),
);