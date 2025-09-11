import 'package:flutter/material.dart';
// PERBAIKAN: Mengimpor widget loader dari file terpusat.
import '../../widgets/bouncing_dots_loader.dart';
import '../../../services/auth_service.dart';
import '../../../config/routes.dart';
import 'package:m_clearance_imigrasi/app/localization/app_strings.dart';

class RegistrationPendingScreen extends StatefulWidget {
  final String initialLanguage;
  const RegistrationPendingScreen({super.key, this.initialLanguage = 'EN'});

  @override
  State<RegistrationPendingScreen> createState() => _RegistrationPendingScreenState();
}

class _RegistrationPendingScreenState extends State<RegistrationPendingScreen> {
  final AuthService _authService = AuthService();

  String _tr(String key) {
    return AppStrings.tr(context: context, screenKey: 'registrationPending', stringKey: key, langCode: widget.initialLanguage);
  }

  Future<void> _signOutAndGoToLogin() async {
    await _authService.signOut();
    if (mounted) {
      Navigator.pushReplacementNamed(context, AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {

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
              BouncingDotsLoader(),
              const SizedBox(height: 48),
              Text(_tr('title'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black)),
              const SizedBox(height: 16),
              Text(_tr('message'), textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Colors.grey.shade600, height: 1.5)),
              const Spacer(),
              ElevatedButton(
                onPressed: _signOutAndGoToLogin,
                child: Text(_tr('done_button')),
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
