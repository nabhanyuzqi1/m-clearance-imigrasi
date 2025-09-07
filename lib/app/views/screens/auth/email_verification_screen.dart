import 'dart:async';
import 'package:flutter/material.dart';
import 'package:m_clearance_imigrasi/app/config/routes.dart';
import 'package:m_clearance_imigrasi/app/services/auth_service.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({Key? key}) : super(key: key);

  @override
  _EmailVerificationScreenState createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final AuthService _authService = AuthService();
  bool _isSendingVerificationEmail = false;
  bool _isVerifying = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _sendVerificationEmail();
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _checkEmailVerification();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _sendVerificationEmail() async {
    setState(() {
      _isSendingVerificationEmail = true;
    });
    await _authService.sendVerificationEmail();
    setState(() {
      _isSendingVerificationEmail = false;
    });
  }

  Future<void> _checkEmailVerification() async {
    setState(() {
      _isVerifying = true;
    });
    final isVerified = await _authService.isEmailVerified();
    if (isVerified) {
      _timer?.cancel();
      Navigator.pushReplacementNamed(context, AppRoutes.uploadDocuments);
    }
    setState(() {
      _isVerifying = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Email Verification'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'A verification email has been sent to your email address. Please check your inbox and follow the instructions.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            _isVerifying
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _checkEmailVerification,
                    child: const Text('I have verified my email'),
                  ),
            const SizedBox(height: 10),
            _isSendingVerificationEmail
                ? const CircularProgressIndicator()
                : TextButton(
                    onPressed: _sendVerificationEmail,
                    child: const Text('Resend verification email'),
                  ),
          ],
        ),
      ),
    );
  }
}