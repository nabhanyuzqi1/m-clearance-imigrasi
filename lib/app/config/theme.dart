import 'package:flutter/material.dart';

/// AppTheme centralises spacing, typography helpers, and the shared
/// light/dark ThemeData built on top of the Wisdom Blue palette.
class AppTheme {
  // --- RESPONSIVE BREAKPOINTS ---
  static const double mobileBreakpoint = 600.0;
  static const double tabletBreakpoint = 1024.0;

  static double responsivePadding(
    BuildContext context, {
    double mobile = paddingSmall,
    double tablet = paddingMedium,
    double desktop = paddingLarge,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth >= tabletBreakpoint) return desktop;
    if (screenWidth >= mobileBreakpoint) return tablet;
    return mobile;
  }

  static double responsiveFontSize(
    BuildContext context, {
    double mobile = fontSizeMedium,
    double tablet = fontSizeLarge,
    double desktop = fontSizeExtraLarge,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth >= tabletBreakpoint) return desktop;
    if (screenWidth >= mobileBreakpoint) return tablet;
    return mobile;
  }

  static ScreenType getScreenType(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth >= tabletBreakpoint) return ScreenType.desktop;
    if (screenWidth >= mobileBreakpoint) return ScreenType.tablet;
    return ScreenType.mobile;
  }

  // --- CORE PALETTE (WISDOM BLUE) ---
  static const Color wisdomBlue = Color(0xFF043666);
  static const Color wisdomBlueBright = Color(0xFF0B4F8C);
  static const Color wisdomBlueDeep = Color(0xFF021A33);
  static const Color sunriseAmber = Color(0xFFF5A524);
  static const Color oceanTeal = Color(0xFF27B2A5);
  static const Color cloudWhite = Color(0xFFF4F7FD);
  static const Color duskSlate = Color(0xFF1F2933);
  static const Color mistGrey = Color(0xFF5F6C7B);

  static final ColorScheme lightColorScheme = ColorScheme.fromSeed(
    seedColor: wisdomBlue,
    brightness: Brightness.light,
    primary: wisdomBlue,
    secondary: sunriseAmber,
    tertiary: oceanTeal,
    surface: Colors.white,
    onSurface: duskSlate,
    error: const Color(0xFFBA1A1A),
  );

  static final ColorScheme darkColorScheme = ColorScheme.fromSeed(
    seedColor: wisdomBlue,
    brightness: Brightness.dark,
    primary: const Color(0xFF9EC6FF),
    secondary: const Color(0xFFFFC970),
    tertiary: const Color(0xFF4ED8C4),
    surface: const Color(0xFF152238),
    onSurface: const Color(0xFFE4EBFA),
    error: const Color(0xFFFFB4AB),
  );

  // Legacy colour aliases mapped into the Wisdom Blue palette so existing
  // widgets continue to compile while the codebase is migrated to the
  // dynamic colour scheme accessors.
  static const Color primaryColor = wisdomBlue;
  static const Color primaryVariant = wisdomBlueBright;
  static const Color secondaryColor = sunriseAmber;
  static const Color secondaryVariant = Color(0xFFCF8415);
  static const Color accentColor = sunriseAmber;

  static const Color backgroundColor = cloudWhite;
  static const Color surfaceColor = Colors.white;
  static const Color scaffoldBackgroundColor = cloudWhite;

  static const Color textColor = duskSlate;
  static const Color headingColor = duskSlate;
  static const Color subtitleColor = mistGrey;
  static const Color onSurface = duskSlate;
  static const Color onBackground = duskSlate;

  static const Color successColor = Color(0xFF2E7D32);
  static const Color warningColor = Color(0xFFF1A208);
  static const Color errorColor = Color(0xFFBA1A1A);
  static const Color errorShade100 = Color(0xFFFFDAD6);
  static const Color errorShade200 = Color(0xFFFFB4AB);
  static const Color errorShade400 = Color(0xFFBA1A1A);
  static const Color infoColor = wisdomBlue;
  static const Color infoShade800 = wisdomBlueBright;

  static const Color whiteColor = Colors.white;
  static const Color whiteColor70 = Color(0xB3FFFFFF);
  static const Color blackColor = Color(0xFF0B1626);
  static const Color blackColor12 = Color(0x1F0B1626);
  static const Color blackColor26 = Color(0x420B1626);
  static const Color blackColor38 = Color(0x610B1626);
  static const Color blackColor45 = Color(0x730B1626);
  static const Color blackColor54 = Color(0x8A0B1626);
  static const Color blackColor87 = Color(0xDD0B1626);
  static const Color greyColor = Color(0xFF64748B);
  static const Color transparentColor = Colors.transparent;

  static const Color greyShade50 = Color(0xFFF8FAFC);
  static const Color greyShade100 = Color(0xFFF1F5F9);
  static const Color greyShade200 = Color(0xFFE2E8F0);
  static const Color greyShade300 = Color(0xFFCBD5E1);
  static const Color greyShade400 = Color(0xFF94A3B8);
  static const Color greyShade500 = Color(0xFF64748B);
  static const Color greyShade600 = Color(0xFF475569);
  static const Color greyShade700 = Color(0xFF334155);
  static const Color greyShade800 = Color(0xFF1E293B);
  static const Color greyShade900 = Color(0xFF0F172A);

  static ThemeData get lightTheme => _buildTheme(lightColorScheme);
  static ThemeData get darkTheme => _buildTheme(darkColorScheme);

  static ThemeData _buildTheme(ColorScheme colorScheme) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: 'Poppins',
      visualDensity: VisualDensity.adaptivePlatformDensity,
      scaffoldBackgroundColor: colorScheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: colorScheme.onSurface,
          fontSize: fontSizeH6,
          fontWeight: FontWeight.w600,
          fontFamily: 'Poppins',
        ),
        iconTheme: IconThemeData(color: colorScheme.onSurface),
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surface,
        elevation: 1,
        margin: const EdgeInsets.only(bottom: spacing16),
        shadowColor: colorScheme.shadow.withAlpha(20),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            vertical: spacing12,
            horizontal: spacing24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusLarge),
          ),
          textStyle: TextStyle(
            fontSize: fontSizeButton,
            fontWeight: FontWeight.w600,
            fontFamily: 'Poppins',
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          textStyle: TextStyle(
            fontSize: fontSizeBody1,
            fontWeight: FontWeight.w500,
            fontFamily: 'Poppins',
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          side: BorderSide(color: colorScheme.primary.withAlpha(102)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusLarge),
          ),
          padding: const EdgeInsets.symmetric(
            vertical: spacing12,
            horizontal: spacing20,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: BorderSide(color: colorScheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: BorderSide(color: colorScheme.error, width: 2),
        ),
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withAlpha(
          colorScheme.brightness == Brightness.dark ? 61 : 153,
        ),
        contentPadding: const EdgeInsets.symmetric(
          vertical: spacing16,
          horizontal: spacing16,
        ),
        labelStyle: TextStyle(
          color: colorScheme.onSurfaceVariant,
          fontSize: fontSizeBody2,
          fontFamily: 'Poppins',
        ),
        hintStyle: TextStyle(
          color: colorScheme.onSurfaceVariant.withAlpha(179),
          fontSize: fontSizeBody1,
          fontFamily: 'Poppins',
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: TextStyle(
          color: colorScheme.onInverseSurface,
          fontFamily: 'Poppins',
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.primary.withAlpha(26),
        selectedColor: colorScheme.primary.withAlpha(51),
        disabledColor: colorScheme.surfaceContainerHighest,
        side: BorderSide(color: colorScheme.outlineVariant),
        labelStyle: TextStyle(
          color: colorScheme.onSurface,
          fontFamily: 'Poppins',
        ),
        secondaryLabelStyle: TextStyle(
          color: colorScheme.onPrimary,
          fontFamily: 'Poppins',
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: spacing12,
          vertical: spacing8,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: 1,
        space: spacing8,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colorScheme.primary
              : colorScheme.outlineVariant,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colorScheme.primary.withAlpha(128)
              : colorScheme.outlineVariant.withAlpha(102),
        ),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colorScheme.primary
              : colorScheme.outlineVariant,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
        ),
        side: BorderSide(color: colorScheme.outlineVariant),
        checkColor: WidgetStateProperty.all(colorScheme.onPrimary),
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colorScheme.primary
              : Colors.transparent,
        ),
      ),
    );

    return base.copyWith(
      textTheme: _buildTextTheme(base.textTheme, colorScheme),
    );
  }

  static TextTheme _buildTextTheme(TextTheme base, ColorScheme scheme) {
    final textTheme = base.apply(fontFamily: 'Poppins');
    return textTheme.copyWith(
      displayLarge: textTheme.displayLarge?.copyWith(color: scheme.onSurface),
      displayMedium: textTheme.displayMedium?.copyWith(color: scheme.onSurface),
      displaySmall: textTheme.displaySmall?.copyWith(color: scheme.onSurface),
      headlineLarge: textTheme.headlineLarge?.copyWith(color: scheme.onSurface),
      headlineMedium: textTheme.headlineMedium?.copyWith(
        color: scheme.onSurface,
      ),
      headlineSmall: textTheme.headlineSmall?.copyWith(color: scheme.onSurface),
      titleLarge: textTheme.titleLarge?.copyWith(color: scheme.onSurface),
      titleMedium: textTheme.titleMedium?.copyWith(color: scheme.onSurface),
      titleSmall: textTheme.titleSmall?.copyWith(color: scheme.onSurface),
      bodyLarge: textTheme.bodyLarge?.copyWith(color: scheme.onSurface),
      bodyMedium: textTheme.bodyMedium?.copyWith(color: scheme.onSurface),
      bodySmall: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
      labelLarge: textTheme.labelLarge?.copyWith(color: scheme.onPrimary),
      labelMedium: textTheme.labelMedium?.copyWith(
        color: scheme.onSurfaceVariant,
      ),
      labelSmall: textTheme.labelSmall?.copyWith(
        color: scheme.onSurfaceVariant,
      ),
    );
  }

  // --- SPACING SCALE ---
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

  static const double paddingSmall = spacing8;
  static const double paddingMedium = spacing16;
  static const double paddingLarge = spacing24;

  // --- RADIUS SCALE ---
  static const double radiusSmall = spacing4;
  static const double radiusMedium = spacing8;
  static const double radiusLarge = spacing12;
  static const double radiusExtraLarge = spacing16;

  // --- TYPOGRAPHY SCALE ---
  static const double fontSizeCaption = 12.0;
  static const double fontSizeBody2 = 14.0;
  static const double fontSizeBody1 = 16.0;
  static const double fontSizeButton = 14.0;
  static const double fontSizeH6 = 20.0;
  static const double fontSizeH5 = 24.0;
  static const double fontSizeH4 = 32.0;
  static const double fontSizeH3 = 48.0;
  static const double fontSizeH2 = 60.0;
  static const double fontSizeH1 = 96.0;

  static const double fontSizeExtraSmall = fontSizeCaption;
  static const double fontSizeSmall = fontSizeBody2;
  static const double fontSizeMedium = fontSizeBody1;
  static const double fontSizeLarge = fontSizeBody1;
  static const double fontSizeExtraLarge = fontSizeH6;
  static const double fontSizeXXLarge = fontSizeH5;
  static const double fontSizeXXXLarge = fontSizeH4;
  static const double fontSizeXXXXLarge = fontSizeH3;
  static const double fontSizeXXXXXLarge = fontSizeH2;

  // --- RESPONSIVE TEXT STYLES ---
  static TextStyle headingLarge(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TextStyle(
      fontSize: responsiveFontSize(
        context,
        mobile: fontSizeH4,
        tablet: fontSizeH3,
        desktop: fontSizeH2,
      ),
      fontWeight: FontWeight.bold,
      color: scheme.onSurface,
      fontFamily: 'Poppins',
    );
  }

  static TextStyle headingMedium(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TextStyle(
      fontSize: responsiveFontSize(
        context,
        mobile: fontSizeH5,
        tablet: fontSizeH4,
        desktop: fontSizeH3,
      ),
      fontWeight: FontWeight.bold,
      color: scheme.onSurface,
      fontFamily: 'Poppins',
    );
  }

  static TextStyle headingSmall(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TextStyle(
      fontSize: responsiveFontSize(
        context,
        mobile: fontSizeH6,
        tablet: fontSizeH5,
        desktop: fontSizeH4,
      ),
      fontWeight: FontWeight.bold,
      color: scheme.onSurface,
      fontFamily: 'Poppins',
    );
  }

  static TextStyle bodyLarge(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TextStyle(
      fontSize: responsiveFontSize(
        context,
        mobile: fontSizeBody1,
        tablet: fontSizeBody1,
        desktop: fontSizeH6,
      ),
      fontWeight: FontWeight.w400,
      color: scheme.onSurface,
      fontFamily: 'Poppins',
    );
  }

  static TextStyle bodyMedium(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TextStyle(
      fontSize: responsiveFontSize(
        context,
        mobile: fontSizeBody2,
        tablet: fontSizeBody1,
        desktop: fontSizeBody1,
      ),
      fontWeight: FontWeight.w400,
      color: scheme.onSurface,
      fontFamily: 'Poppins',
    );
  }

  static TextStyle bodySmall(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TextStyle(
      fontSize: responsiveFontSize(
        context,
        mobile: fontSizeCaption,
        tablet: fontSizeBody2,
        desktop: fontSizeBody2,
      ),
      fontWeight: FontWeight.w400,
      color: scheme.onSurfaceVariant,
      fontFamily: 'Poppins',
    );
  }

  static TextStyle linkPrimary(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TextStyle(
      fontSize: responsiveFontSize(
        context,
        mobile: fontSizeLarge,
        tablet: fontSizeExtraLarge,
        desktop: fontSizeH6,
      ),
      fontWeight: FontWeight.w600,
      color: scheme.primary,
      fontFamily: 'Poppins',
    );
  }

  static TextStyle linkSecondary(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TextStyle(
      fontSize: responsiveFontSize(
        context,
        mobile: fontSizeBody2,
        tablet: fontSizeBody1,
        desktop: fontSizeBody1,
      ),
      fontWeight: FontWeight.w500,
      color: scheme.onSurfaceVariant,
      fontFamily: 'Poppins',
    );
  }

  static TextStyle buttonText(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TextStyle(
      fontSize: responsiveFontSize(
        context,
        mobile: fontSizeButton,
        tablet: fontSizeBody1,
        desktop: fontSizeBody1,
      ),
      fontWeight: FontWeight.w600,
      color: scheme.onPrimary,
      fontFamily: 'Poppins',
    );
  }

  static TextStyle labelLarge(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TextStyle(
      fontSize: responsiveFontSize(
        context,
        mobile: fontSizeBody1,
        tablet: fontSizeH6,
        desktop: fontSizeH6,
      ),
      fontWeight: FontWeight.w600,
      color: scheme.onSurface,
      fontFamily: 'Poppins',
    );
  }

  static TextStyle labelMedium(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TextStyle(
      fontSize: responsiveFontSize(
        context,
        mobile: fontSizeBody2,
        tablet: fontSizeBody1,
        desktop: fontSizeBody1,
      ),
      fontWeight: FontWeight.w500,
      color: scheme.onSurfaceVariant,
      fontFamily: 'Poppins',
    );
  }

  static TextStyle labelSmall(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TextStyle(
      fontSize: responsiveFontSize(
        context,
        mobile: fontSizeCaption,
        tablet: fontSizeBody2,
        desktop: fontSizeBody2,
      ),
      fontWeight: FontWeight.w500,
      color: scheme.onSurfaceVariant,
      fontFamily: 'Poppins',
    );
  }
}

/// Screen type enum for responsive design
enum ScreenType { mobile, tablet, desktop }

/// Removes the default overscroll glow on Android while preserving
/// platform-appropriate physics.
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    switch (getPlatform(context)) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        );
      default:
        return const ClampingScrollPhysics();
    }
  }
}
