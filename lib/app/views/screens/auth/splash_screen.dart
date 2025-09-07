import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../config/routes.dart';

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

    // Atur timer untuk navigasi otomatis setelah 3 detik
    Timer(const Duration(seconds: 3), () {
      // Pastikan widget masih ada di tree sebelum navigasi
      if (mounted) {
        Navigator.of(context).pushReplacementNamed(AppRoutes.login);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
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
                  const Icon(Icons.directions_boat, size: 150, color: Colors.blue),
            ),
          ],
        ),
      ),
    );
  }
}