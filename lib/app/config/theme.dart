import 'package:flutter/material.dart';

/// AppTheme
///
/// Kelas terpusat untuk semua konstanta yang berhubungan dengan tema UI.
/// Ini mencakup warna, padding, radius, dan konfigurasi ThemeData lengkap
/// untuk memastikan tampilan yang konsisten di seluruh aplikasi.
class AppTheme {
  // --- WARNA ---
  static const Color primaryColor = Color(0xFF0D47A1); // Biru Tua
  static const Color accentColor = Color(0xFF42A5F5); // Biru Cerah
  static const Color backgroundColor = Colors.white;
  static const Color scaffoldBackgroundColor = Color(0xFFF5F5F5); // Abu-abu muda
  static const Color textColor = Color(0xFF333333); // Abu-abu tua
  static const Color headingColor = Color(0xFF1A1A1A); // Hitam lembut
  static const Color subtitleColor = Colors.grey;

  // Warna status
  static const Color successColor = Colors.green;
  static const Color warningColor = Colors.orange;
  static const Color errorColor = Colors.red;
  static const Color infoColor = Colors.blue;

  // --- UKURAN ---
  static const double paddingSmall = 8.0;
  static const double paddingMedium = 16.0;
  static const double paddingLarge = 24.0;

  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;

  // --- KONFIGURASI TEMA GLOBAL ---
  static ThemeData get themeData {
    return ThemeData(
      primarySwatch: Colors.blue,
      scaffoldBackgroundColor: scaffoldBackgroundColor,
      fontFamily: 'Poppins', // Pastikan Anda menambahkan font ini di pubspec.yaml
      visualDensity: VisualDensity.adaptivePlatformDensity,
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        secondary: accentColor,
        error: errorColor,
      ),

      // Tema untuk AppBar
      appBarTheme: const AppBarTheme(
        backgroundColor: backgroundColor,
        foregroundColor: headingColor,
        elevation: 0.5,
        iconTheme: IconThemeData(color: headingColor),
        titleTextStyle: TextStyle(
          color: headingColor,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          fontFamily: 'Poppins'
        ),
      ),

      // Tema untuk Tombol
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: paddingMedium, horizontal: paddingLarge),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMedium),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            fontFamily: 'Poppins'
          ),
        ),
      ),

      // Tema untuk Input Field
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(vertical: paddingMedium, horizontal: paddingMedium),
      ),

      // Tema untuk Card
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
        ),
        margin: const EdgeInsets.only(bottom: paddingMedium),
      ),

      // Tema untuk Teks
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: headingColor),
        displayMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: headingColor),
        headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: headingColor),
        titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textColor),
        bodyLarge: TextStyle(fontSize: 16, color: textColor),
        bodyMedium: TextStyle(fontSize: 14, color: textColor),
        labelLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
      ),
    );
  }
}

