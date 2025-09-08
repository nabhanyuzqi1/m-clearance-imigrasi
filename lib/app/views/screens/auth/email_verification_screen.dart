import 'dart:async';
import 'package:flutter/material.dart';
import 'package:m_clearance_imigrasi/app/config/routes.dart';
import 'package:m_clearance_imigrasi/app/services/auth_service.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String initialLanguage;
  const EmailVerificationScreen({super.key, this.initialLanguage = 'EN'});

  @override
  _EmailVerificationScreenState createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final AuthService _authService = AuthService();
  bool _isSendingVerificationEmail = false;
  bool _isVerifying = false;
  Timer? _timer;
  StreamSubscription? _authSub;

  @override
  void initState() {
    super.initState();
    _sendVerificationEmail();

    // Listen for sign-out and redirect to login defensively.
    _authSub = _authService.authStateChanges.listen((user) {
      if (user == null && mounted) {
        _timer?.cancel();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          Navigator.pushReplacementNamed(context, AppRoutes.login);
        });
      }
    });

    // Periodically poll to reload user, reflect verification to Firestore, and navigate when ready.
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _checkEmailVerification();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> _sendVerificationEmail() async {
    setState(() {
      _isSendingVerificationEmail = true;
    });
    await _authService.sendVerificationEmail();
    if (!mounted) return;
    setState(() {
      _isSendingVerificationEmail = false;
    });
  }

  Future<void> _checkEmailVerification() async {
    if (_isVerifying) return;

    if (mounted) {
      setState(() {
        _isVerifying = true;
      });
    }

    try {
      // Reload current user and reflect verification to Firestore.
      await _authService.reloadUser();
      final userModel = await _authService.updateEmailVerified();

      if (!mounted) return;

      if (userModel == null) {
        // If signed out, auth listener will navigate to login.
        // Otherwise, navigate conservatively.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          Navigator.pushReplacementNamed(context, AppRoutes.registrationPending,
              arguments: {'initialLanguage': widget.initialLanguage});
        });
        return;
      }

      switch (userModel.status) {
        case 'pending_documents':
          _timer?.cancel();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            Navigator.pushReplacementNamed(context, AppRoutes.uploadDocuments,
                arguments: {'initialLanguage': widget.initialLanguage});
          });
          return;
        case 'pending_email_verification':
          // Stay on this screen; keep polling.
          break;
        default:
          // Defensive navigation for any unexpected status.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            Navigator.pushReplacementNamed(context, AppRoutes.registrationPending,
                arguments: {'initialLanguage': widget.initialLanguage});
          });
          return;
      }
    } finally {
      if (mounted) {
        setState(() {
          _isVerifying = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Email Verification'),
        actions: [
          IconButton(
            onPressed: _checkEmailVerification,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh status',
          ),
        ],
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