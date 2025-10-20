import 'package:flutter/material.dart';

class AppColors {
  static const bg = Color(0xFF0B0B0F);
  static const neonPink = Color(0xFFFF3FA4);
  static const neonCyan = Color(0xFF00D1FF);
  static const neonLime = Color(0xFFB3FF00);
  static const neonViolet = Color(0xFFB266FF);
  static const card = Color(0xFF141419);
  static const text = Color(0xFFF5F5F5);
  static const muted = Color(0xFFB7B7C0);
}

final ThemeData neonTheme = ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: AppColors.bg,
  colorScheme: const ColorScheme.dark(
    primary: AppColors.neonPink,
    secondary: AppColors.neonCyan,
    surface: AppColors.card,
    onSurface: AppColors.text,
  ),
  textTheme: const TextTheme(
    titleLarge: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5),
    bodyMedium: TextStyle(letterSpacing: 0.2),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.neonPink,
      foregroundColor: Colors.black,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
    ),
  ),
);
