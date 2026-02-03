// lib/app/views/screens/auth/register_screen.dart
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../config/routes.dart';
import '../../../config/theme.dart';
import '../../../localization/app_localizations.dart';
import '../../../models/user_model.dart';
import '../../../services/auth_service.dart';
import '../../../services/logging_service.dart';
import '../../widgets/bouncing_dots_loader.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();
  final TextEditingController _corporateNameController =
      TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _nationalityController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _agreeToTerms = false;
  bool _isRegistering = false;
  String _tr(String key) {
    return AppLocalizations.of(context).get('register.$key');
  }

  @override
  void dispose() {
    LoggingService().debug('Disposing RegisterScreen resources');
    _corporateNameController.dispose();
    _usernameController.dispose();
    _fullNameController.dispose();
    _nationalityController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _goToNextStep() {
    if (_isRegistering) return;
    LoggingService().info(
      'Registration next step attempted, terms agreed: $_agreeToTerms',
    );
    if (!_agreeToTerms) {
      LoggingService().warning('Terms not agreed to during registration');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_tr('terms_req')),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
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
    if (_isRegistering) return;
    LoggingService().info(
      'Starting user registration for email: ${_emailController.text}',
    );
    if (mounted) {
      setState(() {
        _isRegistering = true;
      });
    } else {
      _isRegistering = true;
    }
    try {
      final UserModel? user = await _authService.registerWithEmailAndPassword(
        _emailController.text,
        _passwordController.text,
        _corporateNameController.text,
        _usernameController.text,
        _fullNameController.text,
        _nationalityController.text.trim(),
      );
      if (user != null) {
        LoggingService().info(
          'Registration successful for user: ${user.email}, navigating to email verification',
        );
        if (mounted) {
          Navigator.pushReplacementNamed(
            context,
            AppRoutes.confirmation,
            arguments: {
              'userData': {'email': _emailController.text},
            },
          );
        }
      } else {
        LoggingService().warning(
          'Registration failed - no user returned for email: ${_emailController.text}',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_tr('registration_failed')),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      LoggingService().error(
        'Registration failed with FirebaseAuthException: ${e.code} - ${e.message}',
        e,
      );
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
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } catch (e) {
      LoggingService().error('Unexpected error during registration: $e', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_tr('registration_error')),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRegistering = false;
        });
      } else {
        _isRegistering = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_tr('sign_up')),
        centerTitle: true,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
      ),
      backgroundColor: colorScheme.surface,
      body: Stack(
        children: [
          Form(
            key: _formKey,
            child: ListView(
              padding: EdgeInsets.all(AppTheme.spacing24),
              children: [
            Text(
              _tr('create_account_subtitle'),
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(height: AppTheme.spacing12),
            _buildLabel(_tr('corporate_name')),
            TextFormField(
              controller: _corporateNameController,
              decoration: _buildInputDecoration(
                context,
                hintText: _tr('corporate_name_hint'),
              ),
              validator: (v) => v!.isEmpty ? _tr('corporate_name_req') : null,
            ),
            SizedBox(height: AppTheme.spacing20),
            _buildLabel(_tr('username')),
            TextFormField(
              controller: _usernameController,
              decoration: _buildInputDecoration(
                context,
                hintText: _tr('username_hint'),
              ),
              validator: (v) => v!.isEmpty ? _tr('username_req') : null,
            ),
            SizedBox(height: AppTheme.spacing20),
            _buildLabel(_tr('full_name')),
            TextFormField(
              controller: _fullNameController,
              decoration: _buildInputDecoration(
                context,
                hintText: _tr('full_name_hint'),
              ),
              validator: (v) => v!.isEmpty ? _tr('full_name_req') : null,
            ),
            SizedBox(height: AppTheme.spacing20),
            _buildLabel(_tr('nationality')),
            TextFormField(
              controller: _nationalityController,
              decoration: _buildInputDecoration(
                context,
                hintText: _tr('nationality_hint'),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (v) => v!.trim().isEmpty ? _tr('nationality_req') : null,
            ),
            SizedBox(height: AppTheme.spacing20),
            _buildLabel(_tr('email')),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: _buildInputDecoration(
                context,
                hintText: _tr('email_hint'),
              ),
              validator: (v) {
                if (v!.isEmpty) {
                  return _tr('email_req');
                }
                if (!RegExp(
                  r"^[a-zA-Z0-9.+]+@[a-zA-Z0-9]+\.[a-zA-Z]+",
                ).hasMatch(v)) {
                  return _tr('email_invalid');
                }
                return null;
              },
            ),
            SizedBox(height: AppTheme.spacing20),
            _buildLabel(_tr('password')),
            TextFormField(
              controller: _passwordController,
              obscureText: !_isPasswordVisible,
              decoration: _buildInputDecoration(
                context,
                hintText: _tr('password_hint'),
                suffixIcon: IconButton(
                  icon: Icon(
                    _isPasswordVisible
                        ? Icons.visibility
                        : Icons.visibility_off,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  onPressed: () =>
                      setState(() => _isPasswordVisible = !_isPasswordVisible),
                ),
              ),
              validator: (v) {
                if (v!.isEmpty) {
                  return _tr('password_req');
                }
                if (v.length < 6) {
                  return _tr('password_length');
                }
                return null;
              },
            ),
            SizedBox(height: AppTheme.spacing20),
            _buildLabel(_tr('confirm_password')),
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: !_isConfirmPasswordVisible,
              decoration: _buildInputDecoration(
                context,
                hintText: _tr('confirm_password_hint'),
                suffixIcon: IconButton(
                  icon: Icon(
                    _isConfirmPasswordVisible
                        ? Icons.visibility
                        : Icons.visibility_off,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  onPressed: () => setState(
                    () =>
                        _isConfirmPasswordVisible = !_isConfirmPasswordVisible,
                  ),
                ),
              ),
              validator: (v) {
                if (v!.isEmpty) {
                  return _tr('confirm_password_req');
                }
                if (v != _passwordController.text) {
                  return _tr('password_mismatch');
                }
                return null;
              },
            ),
            SizedBox(height: AppTheme.spacing20),
            _buildTermsCheckbox(),
            SizedBox(height: AppTheme.spacing12),
            ElevatedButton(
              onPressed: _goToNextStep,
              child: Text(
                _tr('continue'),
                style: TextStyle(
                  fontSize: AppTheme.responsiveFontSize(context),
                ),
              ),
            ),
            SizedBox(height: AppTheme.spacing12),
            _buildLoginRedirect(),
            SizedBox(height: AppTheme.spacing20),
              ],
            ),
          ),
          if (_isRegistering)
            Positioned.fill(
              child: AbsorbPointer(
                absorbing: true,
                child: Container(
                  color: colorScheme.surface.withAlpha(200),
                  child: const Center(child: BouncingDotsLoader()),
                ),
              ),
            ),
        ],
      ),
    );
  }


  Widget _buildLabel(String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppTheme.spacing8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }

  Widget _buildTermsCheckbox() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bodyStyle = theme.textTheme.bodySmall?.copyWith(
      color: colorScheme.onSurface,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Checkbox(
          value: _agreeToTerms,
          onChanged: (value) => setState(() => _agreeToTerms = value ?? false),
          activeColor: colorScheme.primary,
        ),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: bodyStyle,
              children: [
                TextSpan(text: _tr('terms_agree')),
                TextSpan(
                  text: _tr('terms_and_conditions'),
                  style: bodyStyle?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () =>
                        Navigator.pushNamed(context, AppRoutes.terms),
                ),
                TextSpan(text: _tr('and')),
                TextSpan(
                  text: _tr('privacy_policy'),
                  style: bodyStyle?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () =>
                        Navigator.pushNamed(context, AppRoutes.privacy),
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final baseStyle = theme.textTheme.bodyMedium?.copyWith(
      color: colorScheme.onSurfaceVariant,
    );
    return Center(
      child: RichText(
        text: TextSpan(
          style: baseStyle,
          children: [
            TextSpan(text: _tr('already_have_account')),
            TextSpan(
              text: _tr('login'),
              style: baseStyle?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
              recognizer: TapGestureRecognizer()
                ..onTap = () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(
    BuildContext context, {
    String? hintText,
    Widget? suffixIcon,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return InputDecoration(
      hintText: hintText,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: scheme.surfaceContainerHighest.withValues(
        alpha: scheme.brightness == Brightness.dark ? 0.24 : 0.6,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
    );
  }
}
