import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/clearance_application.dart';
import '../../models/user_account.dart';
import '../../services/user_service.dart';
// PERBAIKAN: Mengimpor widget loader dari file terpusat.
import '../../widgets/bouncing_dots_loader.dart';
import 'user_home_screen.dart';

class VerificationLoadingScreen extends StatefulWidget {
  final ClearanceApplication application;
  final String initialLanguage;
  const VerificationLoadingScreen({
    super.key, 
    required this.application,
    this.initialLanguage = 'EN'
  });

  @override
  State<VerificationLoadingScreen> createState() => _VerificationLoadingScreenState();
}

class _VerificationLoadingScreenState extends State<VerificationLoadingScreen> {

  @override
  void initState() {
    super.initState();
    
    UserService.addApplicationToHistory(widget.application);

    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        UserAccount? account;
        try {
           account = UserService.agentAccounts.firstWhere(
            (acc) => acc.name == widget.application.agentName,
          );
        } catch(e) {
          account = null;
        }

        if (account != null) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => UserHomeScreen(username: account!.username)),
            (route) => false,
          );
        } else {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, Map<String, String>> translations = {
      'EN': {
        'title': 'Verifying Documents',
        'message': 'Your submission is being processed. The status will be updated on the history page after verification by the officer.',
      },
      'ID': {
        'title': 'Verifikasi Berkas',
        'message': 'Pengajuan Anda sedang diproses. Status akan diperbarui di halaman riwayat setelah diverifikasi oleh petugas.',
      }
    };

    String tr(String key) => translations[widget.initialLanguage]![key] ?? key;

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
              Text(
                tr('title'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black),
              ),
              const SizedBox(height: 16),
              Text(
                tr('message'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.grey, height: 1.5),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

// PERBAIKAN: Menghapus definisi BouncingDotsLoader dan _Dot dari file ini
// karena sudah dipindahkan ke file widget sendiri.
