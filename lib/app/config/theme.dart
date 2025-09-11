import 'package:flutter/material.dart';

/// AppTheme
///
/// Kelas terpusat untuk semua konstanta yang berhubungan dengan tema UI.
/// Ini mencakup warna, padding, radius, dan konfigurasi ThemeData lengkap
/// untuk memastikan tampilan yang konsisten di seluruh aplikasi.
class AppTheme {
  // --- RESPONSIVE BREAKPOINTS ---
  static const double mobileBreakpoint = 600.0;
  static const double tabletBreakpoint = 1024.0;

  // Responsive padding based on screen size
  static double responsivePadding(BuildContext context, {
    double mobile = paddingSmall,
    double tablet = paddingMedium,
    double desktop = paddingLarge,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth >= tabletBreakpoint) return desktop;
    if (screenWidth >= mobileBreakpoint) return tablet;
    return mobile;
  }

  // Responsive font size based on screen size
  static double responsiveFontSize(BuildContext context, {
    double mobile = fontSizeMedium,
    double tablet = fontSizeLarge,
    double desktop = fontSizeExtraLarge,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth >= tabletBreakpoint) return desktop;
    if (screenWidth >= mobileBreakpoint) return tablet;
    return mobile;
  }

  // Get screen type
  static ScreenType getScreenType(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth >= tabletBreakpoint) return ScreenType.desktop;
    if (screenWidth >= mobileBreakpoint) return ScreenType.tablet;
    return ScreenType.mobile;
  }
  // --- MATERIAL DESIGN COLOR PALETTE ---
  // Primary colors
  static const Color primaryColor = Color(0xFF1976D2); // Blue 700
  static const Color primaryVariant = Color(0xFF1565C0); // Blue 800
  static const Color onPrimary = Colors.white;

  // Secondary colors
  static const Color secondaryColor = Color(0xFF03DAC6); // Teal 200
  static const Color secondaryVariant = Color(0xFF00BFA5); // Teal 400
  static const Color onSecondary = Colors.black;

  // Background and surface
  static const Color backgroundColor = Colors.white;
  static const Color surfaceColor = Colors.white;
  static const Color scaffoldBackgroundColor = Color(0xFFFAFAFA); // Grey 50

  // Text colors
  static const Color textColor = Color(0xFF212121); // Grey 900
  static const Color headingColor = Color(0xFF212121); // Grey 900
  static const Color subtitleColor = Color(0xFF757575); // Grey 600
  static const Color onSurface = Color(0xFF212121); // Grey 900
  static const Color onBackground = Color(0xFF212121); // Grey 900

  // Legacy accent color (mapped to secondary)
  static const Color accentColor = secondaryColor;

  // Warna status
  static const Color successColor = Colors.green;
  static const Color warningColor = Colors.orange;
  static const Color errorColor = Colors.red;
  static const Color errorShade100 = Color(0xFFEF9A9A);
  static const Color errorShade200 = Color(0xFFEF5350);
  static const Color errorShade400 = Color(0xFFE53935);
  static const Color infoColor = Colors.blue;
  static const Color infoShade800 = Color(0xFF1565C0);

  // Additional colors
  static const Color whiteColor = Colors.white;
  static const Color whiteColor70 = Color(0xB3FFFFFF);
  static const Color blackColor = Colors.black;
  static const Color blackColor12 = Color(0x1F000000);
  static const Color blackColor26 = Color(0x42000000);
  static const Color blackColor38 = Color(0x61000000);
  static const Color blackColor45 = Color(0x73000000);
  static const Color blackColor54 = Color(0x8A000000);
  static const Color blackColor87 = Color(0xDD000000);
  static const Color greyColor = Colors.grey;
  static const Color transparentColor = Colors.transparent;

  // Grey shades
  static const Color greyShade50 = Color(0xFFFAFAFA);
  static const Color greyShade100 = Color(0xFFF5F5F5);
  static const Color greyShade200 = Color(0xFFEEEEEE);
  static const Color greyShade300 = Color(0xFFE0E0E0);
  static const Color greyShade400 = Color(0xFFBDBDBD);
  static const Color greyShade500 = Color(0xFF9E9E9E);
  static const Color greyShade600 = Color(0xFF757575);
  static const Color greyShade700 = Color(0xFF616161);
  static const Color greyShade800 = Color(0xFF424242);
  static const Color greyShade900 = Color(0xFF212121);

  // --- MATERIAL DESIGN SPACING SCALE ---
  static const double spacing4 = 4.0;
  static const double spacing8 = 8.0;
  static const double spacing12 = 12.0;
  static const double spacing16 = 16.0;
  static const double spacing20 = 20.0;
  static const double spacing24 = 24.0;
  static const double spacing32 = 32.0;
  static const double spacing40 = 40.0;
  static const double spacing48 = 48.0;
  static const double spacing56 = 56.0;
  static const double spacing64 = 64.0;

  // Legacy padding constants (mapped to new spacing)
  static const double paddingSmall = spacing8;
  static const double paddingMedium = spacing16;
  static const double paddingLarge = spacing24;

  // --- MATERIAL DESIGN BORDER RADIUS ---
  static const double radiusSmall = spacing4;
  static const double radiusMedium = spacing8;
  static const double radiusLarge = spacing12;
  static const double radiusExtraLarge = spacing16;

  // --- MATERIAL DESIGN TYPOGRAPHY SCALE ---
  static const double fontSizeCaption = 12.0; // Extra Small
  static const double fontSizeBody2 = 14.0; // Small
  static const double fontSizeBody1 = 16.0; // Medium
  static const double fontSizeButton = 14.0; // Button
  static const double fontSizeH6 = 20.0; // Large
  static const double fontSizeH5 = 24.0; // Extra Large
  static const double fontSizeH4 = 32.0; // XX Large
  static const double fontSizeH3 = 48.0; // XXX Large
  static const double fontSizeH2 = 60.0; // XXXX Large
  static const double fontSizeH1 = 96.0; // XXXXX Large

  // Legacy font size constants (mapped to new typography)
  static const double fontSizeExtraSmall = fontSizeCaption;
  static const double fontSizeSmall = fontSizeBody2;
  static const double fontSizeMedium = fontSizeBody1;
  static const double fontSizeLarge = fontSizeBody1;
  static const double fontSizeExtraLarge = fontSizeH6;
  static const double fontSizeXXLarge = fontSizeH5;
  static const double fontSizeXXXLarge = fontSizeH4;
  static const double fontSizeXXXXLarge = fontSizeH3;
  static const double fontSizeXXXXXLarge = fontSizeH2;

  // --- MATERIAL DESIGN THEME CONFIGURATION ---
  static ThemeData get themeData {
    return ThemeData(
      useMaterial3: true, // Enable Material Design 3
      fontFamily: 'Poppins',
      visualDensity: VisualDensity.adaptivePlatformDensity,

      // Color Scheme
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        primaryContainer: primaryVariant,
        secondary: secondaryColor,
        secondaryContainer: secondaryVariant,
        surface: surfaceColor,
        background: backgroundColor,
        error: errorColor,
        onPrimary: onPrimary,
        onSecondary: onSecondary,
        onSurface: onSurface,
        onBackground: onBackground,
        onError: Colors.white,
      ),

      // Scaffold
      scaffoldBackgroundColor: scaffoldBackgroundColor,

      // AppBar Theme
      appBarTheme: AppBarTheme(
        backgroundColor: surfaceColor,
        foregroundColor: onSurface,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: onSurface,
          fontSize: fontSizeH6,
          fontWeight: FontWeight.w600,
          fontFamily: 'Poppins',
        ),
        iconTheme: IconThemeData(color: onSurface),
      ),

      // Elevated Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: onPrimary,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: spacing12, horizontal: spacing24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusLarge),
          ),
          textStyle: TextStyle(
            fontSize: fontSizeButton,
            fontWeight: FontWeight.w500,
            fontFamily: 'Poppins',
          ),
        ),
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: BorderSide(color: greyShade400),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: BorderSide(color: greyShade400),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: errorColor, width: 1),
        ),
        filled: true,
        fillColor: greyShade50,
        contentPadding: const EdgeInsets.symmetric(vertical: spacing16, horizontal: spacing16),
        labelStyle: TextStyle(
          color: subtitleColor,
          fontSize: fontSizeBody2,
          fontFamily: 'Poppins',
        ),
        hintStyle: TextStyle(
          color: subtitleColor,
          fontSize: fontSizeBody1,
          fontFamily: 'Poppins',
        ),
      ),

      // Card Theme
      cardTheme: CardThemeData(
        elevation: 1,
        shadowColor: blackColor12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
        ),
        margin: const EdgeInsets.only(bottom: spacing16),
        surfaceTintColor: Colors.transparent,
      ),

      // Text Theme (Material Design 3 Typography)
      textTheme: TextTheme(
        displayLarge: TextStyle(fontSize: fontSizeH1, fontWeight: FontWeight.w400, color: onSurface, fontFamily: 'Poppins'),
        displayMedium: TextStyle(fontSize: fontSizeH2, fontWeight: FontWeight.w400, color: onSurface, fontFamily: 'Poppins'),
        displaySmall: TextStyle(fontSize: fontSizeH3, fontWeight: FontWeight.w400, color: onSurface, fontFamily: 'Poppins'),
        headlineLarge: TextStyle(fontSize: fontSizeH4, fontWeight: FontWeight.w400, color: onSurface, fontFamily: 'Poppins'),
        headlineMedium: TextStyle(fontSize: fontSizeH5, fontWeight: FontWeight.w400, color: onSurface, fontFamily: 'Poppins'),
        headlineSmall: TextStyle(fontSize: fontSizeH6, fontWeight: FontWeight.w400, color: onSurface, fontFamily: 'Poppins'),
        titleLarge: TextStyle(fontSize: fontSizeBody1, fontWeight: FontWeight.w500, color: onSurface, fontFamily: 'Poppins'),
        titleMedium: TextStyle(fontSize: fontSizeBody2, fontWeight: FontWeight.w500, color: onSurface, fontFamily: 'Poppins'),
        titleSmall: TextStyle(fontSize: fontSizeCaption, fontWeight: FontWeight.w500, color: onSurface, fontFamily: 'Poppins'),
        bodyLarge: TextStyle(fontSize: fontSizeBody1, fontWeight: FontWeight.w400, color: onSurface, fontFamily: 'Poppins'),
        bodyMedium: TextStyle(fontSize: fontSizeBody2, fontWeight: FontWeight.w400, color: onSurface, fontFamily: 'Poppins'),
        bodySmall: TextStyle(fontSize: fontSizeCaption, fontWeight: FontWeight.w400, color: onSurface, fontFamily: 'Poppins'),
        labelLarge: TextStyle(fontSize: fontSizeButton, fontWeight: FontWeight.w500, color: onPrimary, fontFamily: 'Poppins'),
        labelMedium: TextStyle(fontSize: fontSizeCaption, fontWeight: FontWeight.w500, color: onSurface, fontFamily: 'Poppins'),
        labelSmall: TextStyle(fontSize: fontSizeCaption, fontWeight: FontWeight.w500, color: onSurface, fontFamily: 'Poppins'),
      ),
    );
  }
}

/// Screen type enum for responsive design
enum ScreenType {
  mobile,
  tablet,
  desktop,
}

