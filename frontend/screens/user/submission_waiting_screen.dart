// PERBAIKAN: Memperbaiki path komentar agar sesuai dengan nama file.
// lib/screens/user/submission_waiting_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/clearance_application.dart';
import '../../models/user_account.dart';
import '../../services/user_service.dart';
import 'user_home_screen.dart';

// PERBAIKAN: Mengganti nama kelas dari 'VerificationLoadingScreen' menjadi 'SubmissionWaitingScreen'
// untuk menghindari konflik nama dengan kelas di file 'verification_loading_screen.dart'.
class SubmissionWaitingScreen extends StatefulWidget {
  final ClearanceApplication application;
  const SubmissionWaitingScreen({super.key, required this.application});

  @override
  State<SubmissionWaitingScreen> createState() => _SubmissionWaitingScreenState();
}

// PERBAIKAN: Mengganti nama State agar sesuai dengan nama kelas Widget yang baru.
class _SubmissionWaitingScreenState extends State<SubmissionWaitingScreen> {
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
    // Teks di sini masih hardcoded karena file ini tampaknya duplikat
    // dan tidak menerima 'initialLanguage'. Jika file ini digunakan,
    // sebaiknya tambahkan fungsionalitas terjemahan seperti di layar lainnya.
    return const Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Spacer(),
              BouncingDotsLoader(),
              SizedBox(height: 48),
              Text(
                'Verifikasi Berkas',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black),
              ),
              SizedBox(height: 16),
              Text(
                'Pengajuan Anda sedang diproses. Status akan diperbarui di halaman riwayat setelah diverifikasi oleh petugas.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey, height: 1.5),
              ),
              Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

class BouncingDotsLoader extends StatefulWidget {
  const BouncingDotsLoader({super.key});
  @override
  State<BouncingDotsLoader> createState() => _BouncingDotsLoaderState();
}

class _BouncingDotsLoaderState extends State<BouncingDotsLoader> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
  }
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        final delay = index * 0.1;
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final animationValue = CurveTween(curve: Curves.easeInOutSine).transform((_controller.value - delay).clamp(0.0, 1.0));
            final yOffset = -20 * (animationValue * 2 - 1).abs();
            return Transform.translate(offset: Offset(0, yOffset), child: _Dot(color: index == 1 || index == 4 ? Colors.blue : index == 2 ? Colors.black87 : Colors.grey.shade300));
          },
        );
      }),
    );
  }
}

class _Dot extends StatelessWidget {
  final Color color;
  const _Dot({required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(margin: const EdgeInsets.symmetric(horizontal: 6), width: 15, height: 15, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
  }
}
