import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:m_clearance_imigrasi/app/views/widgets/bouncing_dots_loader.dart';
import '../../../config/routes.dart';
import '../../../config/theme.dart';
import '../../../localization/app_strings.dart';
import '../../../providers/language_provider.dart';

/// SplashScreen
///
/// Layar pertama yang dilihat pengguna. Menampilkan logo dan nama aplikasi
/// selama beberapa detik sebelum secara otomatis mengarahkan pengguna
/// ke halaman login.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String _tr(String key) {
    final langCode = Provider.of<LanguageProvider>(context, listen: false).locale.languageCode;
    return AppStrings.tr(context: context, screenKey: 'splash', stringKey: key, langCode: langCode.toUpperCase());
  }

  @override
  void initState() {
    super.initState();
    // Atur gaya System UI Overlay agar sesuai dengan latar belakang splash screen
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark, // Ikon status bar menjadi gelap
      ),
    );

    // Navigasi setelah penundaan singkat
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        Navigator.of(context).pushReplacementNamed(AppRoutes.login);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo aplikasi
            Image.asset(
              'assets/images/logo.png',
              width: 150,
              height: 150,
              // Fallback jika gambar gagal dimuat
              errorBuilder: (context, error, stackTrace) =>
                  Icon(Icons.directions_boat, size: 150, color: AppTheme.primaryColor),
            ),
            SizedBox(height: AppTheme.spacing24),
            Text(
              _tr('app_name'),
              style: TextStyle(
                color: AppTheme.onSurface,
                fontSize: AppTheme.responsiveFontSize(context, mobile: 28, tablet: 32, desktop: 36),
                fontWeight: FontWeight.bold,
                fontFamily: 'Poppins',
              ),
            ),
            SizedBox(height: AppTheme.spacing24),
            const BouncingDotsLoader(),
          ],
        ),
      ),
    );
  }
}