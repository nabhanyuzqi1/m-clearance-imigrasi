// lib/app/views/screens/auth/register_screen.dart
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../config/routes.dart';
import '../../../config/theme.dart';
import '../../../localization/app_strings.dart';
import '../../../models/user_model.dart';
import '../../../services/auth_service.dart';
import '../../../services/logging_service.dart';

class RegisterScreen extends StatefulWidget {
  final String initialLanguage;
  const RegisterScreen({super.key, this.initialLanguage = 'EN'});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();
  final TextEditingController _corporateNameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _agreeToTerms = false;
  late String _selectedLanguage;

  String _tr(String key) {
    return AppStrings.tr(context: context, screenKey: 'register', stringKey: key, langCode: _selectedLanguage);
  }
  
  @override
  void initState() {
    super.initState();
    LoggingService().info('RegisterScreen initialized with language: ${widget.initialLanguage}');
    _selectedLanguage = widget.initialLanguage;
  }

  @override
  void dispose() {
    LoggingService().debug('Disposing RegisterScreen resources');
    _corporateNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _goToNextStep() {
    LoggingService().info('Registration next step attempted, terms agreed: $_agreeToTerms');
    if (!_agreeToTerms) {
      LoggingService().warning('Terms not agreed to during registration');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_tr('terms_req')), backgroundColor: AppTheme.errorColor),
        );
      }
      return;
    }

    final isValid = _formKey.currentState!.validate();
    LoggingService().debug('Registration form validation result: $isValid');
    if (isValid) {
      _performRegistration();
    }
  }

  Future<void> _performRegistration() async {
    LoggingService().info('Starting user registration for email: ${_emailController.text}');
    try {
      final UserModel? user = await _authService.registerWithEmailAndPassword(
        _emailController.text,
        _passwordController.text,
        _corporateNameController.text,
        _usernameController.text,
        '', // nationality removed from UI; pass empty to keep function signature unchanged
      );
      if (user != null) {
        LoggingService().info('Registration successful for user: ${user.email}, navigating to email verification');
        if (mounted) {
          Navigator.pushReplacementNamed(
            context,
            AppRoutes.confirmation,
            arguments: {
              'userData': {'email': _emailController.text},
              'initialLanguage': _selectedLanguage,
            },
          );
        }
      } else {
        LoggingService().warning('Registration failed - no user returned for email: ${_emailController.text}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_tr('registration_failed')),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      LoggingService().error('Registration failed with FirebaseAuthException: ${e.code} - ${e.message}', e);
      String errorMessage;
      switch (e.code) {
        case 'email-already-in-use':
          errorMessage = _tr('email_already_in_use');
          break;
        case 'weak-password':
          errorMessage = _tr('weak_password');
          break;
        default:
          errorMessage = _tr('registration_error');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } catch (e) {
      LoggingService().error('Unexpected error during registration: $e', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_tr('registration_error')),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_tr('sign_up')),
        centerTitle: true,
      ),
      backgroundColor: AppTheme.whiteColor,
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(AppTheme.spacing24),
          children: [
            Text(_tr('create_account_subtitle'), style: TextStyle(fontSize: AppTheme.responsiveFontSize(context), color: AppTheme.blackColor54)),
            const SizedBox(height: 10),
            _buildLabel(_tr('corporate_name')),
            TextFormField(
              controller: _corporateNameController,
              decoration:
                  _buildInputDecoration(hintText: _tr('corporate_name_hint')),
              validator: (v) => v!.isEmpty ? _tr('corporate_name_req') : null,
            ),
            const SizedBox(height: 20),
            _buildLabel(_tr('username')),
            TextFormField(
              controller: _usernameController,
              decoration: _buildInputDecoration(hintText: _tr('username_hint')),
              validator: (v) => v!.isEmpty ? _tr('username_req') : null,
            ),
            const SizedBox(height: 20),
            // Nationality field removed per requirement.
            _buildLabel(_tr('email')),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: _buildInputDecoration(hintText: _tr('email_hint')),
              validator: (v) {
                if (v!.isEmpty) return _tr('email_req');
                if (!RegExp(r"^[a-zA-Z0-9.+]+@[a-zA-Z0-9]+\.[a-zA-Z]+").hasMatch(v)) return _tr('email_invalid');
                return null;
              },
            ),
            const SizedBox(height: 20),
            _buildLabel(_tr('password')),
            TextFormField(
              controller: _passwordController,
              obscureText: !_isPasswordVisible,
              decoration: _buildInputDecoration(
                hintText: _tr('password_hint'),
                suffixIcon: IconButton(
                  icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off, color: AppTheme.greyColor),
                  onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                ),
              ),
              validator: (v) {
                if (v!.isEmpty) return _tr('password_req');
                if (v.length < 6) return _tr('password_length');
                return null;
              },
            ),
            const SizedBox(height: 20),
            _buildLabel(_tr('confirm_password')),
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: !_isConfirmPasswordVisible,
              decoration: _buildInputDecoration(
                hintText: _tr('confirm_password_hint'),
                suffixIcon: IconButton(
                  icon: Icon(_isConfirmPasswordVisible ? Icons.visibility : Icons.visibility_off, color: AppTheme.greyColor),
                  onPressed: () => setState(() => _isConfirmPasswordVisible = !_isConfirmPasswordVisible),
                ),
              ),
              validator: (v) {
                if (v!.isEmpty) return _tr('confirm_password_req');
                if (v != _passwordController.text) return _tr('password_mismatch');
                return null;
              },
            ),
            const SizedBox(height: 20),
            _buildTermsCheckbox(),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _goToNextStep,
              child: Text(_tr('continue'), style: TextStyle(fontSize: AppTheme.responsiveFontSize(context))),
            ),
            const SizedBox(height: 10),
            _buildLoginRedirect(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(text, style: TextStyle(fontWeight: FontWeight.bold, fontSize: AppTheme.responsiveFontSize(context), color: AppTheme.blackColor87)),
    );
  }

  Widget _buildTermsCheckbox() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Checkbox(
          value: _agreeToTerms,
          onChanged: (value) => setState(() => _agreeToTerms = value!),
          activeColor: AppTheme.primaryColor,
        ),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(fontSize: AppTheme.responsiveFontSize(context), color: AppTheme.blackColor54),
              children: [
                TextSpan(text: _tr('terms_agree')),
                TextSpan(
                  text: _tr('terms_and_conditions'),
                  style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w600),
                  recognizer: TapGestureRecognizer()..onTap = () {},
                ),
                TextSpan(text: _tr('and')),
                TextSpan(
                  text: _tr('privacy_policy'),
                  style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w600),
                  recognizer: TapGestureRecognizer()..onTap = () {},
                ),
                const TextSpan(text: '.'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginRedirect() {
    return Center(
      child: RichText(
        text: TextSpan(
          style: TextStyle(fontSize: AppTheme.responsiveFontSize(context), color: AppTheme.blackColor54),
          children: [
            TextSpan(text: _tr('already_have_account')),
            TextSpan(
              text: _tr('login'),
              style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
              recognizer: TapGestureRecognizer()..onTap = () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration({String? hintText, Widget? suffixIcon}) {
    return InputDecoration(
      hintText: hintText,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: AppTheme.greyShade100,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    );
  }
}
