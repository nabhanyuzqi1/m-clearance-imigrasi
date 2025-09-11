import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../config/theme.dart';
import '../../../localization/app_strings.dart';
import '../../../services/auth_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  final String initialLanguage;
  const ForgotPasswordScreen({super.key, this.initialLanguage = 'EN'});
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController _emailController = TextEditingController();
  final AuthService _authService = AuthService();
  late String _selectedLanguage;
  String _tr(String key) {
    return AppStrings.tr(
        context: context, // showDialog is async
        screenKey: 'forgotPassword',
        stringKey: key,
        langCode: _selectedLanguage);
  }

  @override
  void initState() {
    super.initState();
    _selectedLanguage = widget.initialLanguage;
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _sendResetLink() async {
    if (_emailController.text.isNotEmpty &&
        _emailController.text.contains('@')) {
      try {
        await _authService.sendPasswordResetEmail(_emailController.text);
        showDialog(
          context: context, // showDialog is async
          builder: (context) => AlertDialog(
            title: Text(_tr('success_dialog_title')),
            content:
                Text("${_tr('success_dialog_content')}${_emailController.text}"),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context); // Go back from Forgot Password screen
                },
                child: Text(_tr('ok_button')),
              ),
            ],
          ),
        );
      } on FirebaseAuthException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(e.message ?? _tr('error_occurred')),
                backgroundColor: AppTheme.errorColor),
          );
        }
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(_tr('invalid_email_message')),
            backgroundColor: AppTheme.errorColor),
      );
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