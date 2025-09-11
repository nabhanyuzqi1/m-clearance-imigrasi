import 'package:flutter/material.dart';
// PERBAIKAN: Mengimpor widget loader dari file terpusat.
import '../../widgets/bouncing_dots_loader.dart';
import '../../../services/auth_service.dart';
import '../../../config/routes.dart';
import '../../../config/theme.dart';
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
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(AppTheme.spacing24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              BouncingDotsLoader(),
              SizedBox(height: AppTheme.spacing48),
              Text(_tr('title'), textAlign: TextAlign.center, style: TextStyle(fontSize: AppTheme.fontSizeH5, fontWeight: FontWeight.bold, color: AppTheme.onSurface, fontFamily: 'Poppins')),
              SizedBox(height: AppTheme.spacing16),
              Text(_tr('message'), textAlign: TextAlign.center, style: TextStyle(fontSize: AppTheme.fontSizeBody1, color: AppTheme.subtitleColor, height: 1.5, fontFamily: 'Poppins')),
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
