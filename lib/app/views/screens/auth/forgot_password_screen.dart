import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../../config/theme.dart';
import '../../../localization/app_localizations.dart';
import '../../../providers/language_provider.dart';
import '../../../services/auth_service.dart';
import '../../../services/logging_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController _emailController = TextEditingController();
  final AuthService _authService = AuthService();
  String _tr(String key) {
    return AppLocalizations.of(context)!.get('forgotPassword.$key');
  }

  @override
  void dispose() {
    LoggingService().debug('Disposing ForgotPasswordScreen resources');
    _emailController.dispose();
    super.dispose();
  }

  void _sendResetLink() async {
    LoggingService().info('Password reset link requested for email: ${_emailController.text}');

    if (_emailController.text.isNotEmpty &&
        _emailController.text.contains('@')) {
      try {
        await _authService.sendPasswordResetEmail(_emailController.text);
        LoggingService().info('Password reset email sent successfully to: ${_emailController.text}');
        if (mounted) {
          final screenWidth = MediaQuery.of(context).size.width;
          final isTablet = screenWidth > 600;
          final maxWidth = isTablet ? 400.0 : double.infinity;

          showDialog(
            context: context, // showDialog is async
            builder: (context) => Container(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: Text(
                  _tr('success_dialog_title'),
                  style: TextStyle(
                    fontSize: screenWidth * 0.045,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.onSurface,
                  ),
                ),
                content: Text(
                  "${_tr('success_dialog_content')}${_emailController.text}",
                  style: TextStyle(
                    fontSize: screenWidth * 0.04,
                    color: AppTheme.onSurface.withAlpha(179), // 0.7 * 255
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context); // Close dialog
                      Navigator.pop(context); // Go back from Forgot Password screen
                    },
                    child: Text(
                      _tr('ok_button'),
                      style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontSize: screenWidth * 0.04,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      } on FirebaseAuthException catch (e) {
        LoggingService().error('Failed to send password reset email: ${e.message}', e);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(e.message ?? _tr('error_occurred')),
                backgroundColor: AppTheme.errorColor),
          );
        }
      }
    } else {
      LoggingService().warning('Invalid email format provided: ${_emailController.text}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(_tr('invalid_email_message')),
              backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_tr('title')),
      ),
      body: Padding(
        padding: EdgeInsets.all(AppTheme.paddingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: AppTheme.paddingLarge),
            Text(
              _tr('instruction'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: AppTheme.responsiveFontSize(context, mobile: AppTheme.fontSizeBody1, tablet: AppTheme.fontSizeBody1, desktop: AppTheme.fontSizeH6)),
            ),
            SizedBox(height: AppTheme.paddingLarge),
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: _tr('email_label'),
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.email_outlined),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            SizedBox(height: AppTheme.paddingLarge),
            ElevatedButton(
              onPressed: _sendResetLink,
              child: Text(_tr('send_link_button')),
            ),
          ],
        ),
      ),
    );
  }
}