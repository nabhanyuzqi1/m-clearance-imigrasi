import 'package:flutter/material.dart';
// PERBAIKAN: Mengimpor widget loader dari file terpusat.
import '../../widgets/bouncing_dots_loader.dart';

class RegistrationPendingScreen extends StatelessWidget {
  final String initialLanguage;
  const RegistrationPendingScreen({super.key, this.initialLanguage = 'EN'});
  
  @override
  Widget build(BuildContext context) {

    final Map<String, Map<String, String>> translations = {
      'EN': {
        'title': 'Waiting for Verification',
        'message': 'You have successfully registered, please wait for verification. Check your email regularly.',
        'done_button': 'Done',
      },
      'ID': {
        'title': 'Menunggu Verifikasi',
        'message': 'Anda telah berhasil mendaftar, mohon tunggu verifikasi. Periksa email Anda secara berkala.',
        'done_button': 'Selesai',
      }
    };
    
    String tr(String key) {
      return translations[initialLanguage]![key] ?? key;
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const BouncingDotsLoader(),
              const SizedBox(height: 48),
              Text(tr('title'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black)),
              const SizedBox(height: 16),
              Text(tr('message'), textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Colors.grey.shade600, height: 1.5)),
              const Spacer(),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                child: Text(tr('done_button')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// PERBAIKAN: Menghapus definisi BouncingDotsLoader dan _Dot dari file ini
// karena sudah dipindahkan ke file widget sendiri.
