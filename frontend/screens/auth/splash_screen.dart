import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // PERBAIKAN: Mengatur UI Overlay untuk splash screen dengan ikon gelap
    // agar terlihat di latar belakang yang terang.
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark, // Ikon status bar menjadi gelap
      ),
    );

    Future.delayed(const Duration(seconds: 3), () {
      // Memastikan context masih valid sebelum navigasi untuk menghindari error.
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const LoginScreen(),
          ),
        );
      }
    });
  }
  
  // PERBAIKAN: Menghapus dispose untuk menghindari perubahan UI Overlay yang tidak perlu
  // saat meninggalkan splash screen. Pengaturan UI akan ditangani oleh layar berikutnya.

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Latar belakang putih
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/logo.png',
              width: 150,
              height: 150,
              // Menambahkan error builder jika gambar gagal dimuat.
              errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.directions_boat, size: 150, color: Colors.blue),
            ),
            const SizedBox(height: 24),
            const Text(
              'M-Clearance ISam',
              style: TextStyle(
                // PERBAIKAN: Mengubah warna teks menjadi gelap agar terlihat.
                color: Colors.black87,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
             const SizedBox(height: 16),
            const CircularProgressIndicator(
              // PERBAIKAN: Mengubah warna progress indicator agar terlihat.
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
          ],
        ),
      ),
    );
  }
}
