import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../../localization/app_strings.dart';
import '../../../services/auth_service.dart';
import '../../../services/logging_service.dart';
import '../../widgets/custom_app_bar.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key, required this.initialLanguage});

  final String initialLanguage;

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isSubmitting = false;
  bool _isCurrentPasswordVisible = false;
  bool _isNewPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  String _tr(String key) => AppStrings.tr(
    screenKey: 'changePassword',
    stringKey: key,
    langCode: widget.initialLanguage,
  );

  @override
  void dispose() {
    LoggingService().debug('Disposing ChangePasswordScreen resources');
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submitChangePassword() async {
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) {
      LoggingService().warning('Password change form validation failed');
      return;
    }

    LoggingService().info('Password change attempt initiated');
    setState(() => _isSubmitting = true);

    try {
      final authService = AuthService();
      final success = await authService.changePassword(
        _currentPasswordController.text.trim(),
        _newPasswordController.text.trim(),
      );

      if (!mounted) return;
      if (success) {
        final snackColor = Theme.of(context).colorScheme.primary;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_tr('password_updated')),
            backgroundColor: snackColor,
          ),
        );
        Navigator.pop(context);
      }
    } on ChangePasswordException catch (e) {
      if (!mounted) return;
      final errorColor = Theme.of(context).colorScheme.error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_errorMessageFor(e.code)),
          backgroundColor: errorColor,
        ),
      );
    } catch (error, stackTrace) {
      LoggingService().error(
        'Unexpected error changing password',
        error,
        stackTrace,
      );
      if (!mounted) return;
      final errorColor = Theme.of(context).colorScheme.error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_tr('change_password_generic_error')),
          backgroundColor: errorColor,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: CustomAppBar(
        titleText: _tr('title'),
        centerTitle: true,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
      ),
      body: Stack(
        children: [
          Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(AppTheme.spacing20),
              children: [
                Text(
                  _tr('instruction'),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppTheme.spacing24),
                _buildPasswordField(
                  context,
                  controller: _currentPasswordController,
                  label: _tr('current_password'),
                  obscure: !_isCurrentPasswordVisible,
                  toggle: () => setState(
                    () =>
                        _isCurrentPasswordVisible = !_isCurrentPasswordVisible,
                  ),
                  validator: (value) => value == null || value.isEmpty
                      ? _tr('current_password_empty')
                      : null,
                ),
                const SizedBox(height: AppTheme.spacing16),
                _buildPasswordField(
                  context,
                  controller: _newPasswordController,
                  label: _tr('new_password'),
                  obscure: !_isNewPasswordVisible,
                  toggle: () => setState(
                    () => _isNewPasswordVisible = !_isNewPasswordVisible,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return _tr('new_password_empty');
                    }
                    if (value.length < 6) return _tr('password_length');
                    return null;
                  },
                ),
                const SizedBox(height: AppTheme.spacing16),
                _buildPasswordField(
                  context,
                  controller: _confirmPasswordController,
                  label: _tr('confirm_new_password'),
                  obscure: !_isConfirmPasswordVisible,
                  toggle: () => setState(
                    () =>
                        _isConfirmPasswordVisible = !_isConfirmPasswordVisible,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return _tr('confirm_password_empty');
                    }
                    if (value != _newPasswordController.text) {
                      return _tr('passwords_do_not_match');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppTheme.spacing32),
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitChangePassword,
                  child: Text(_tr('save_new_password')),
                ),
              ],
            ),
          ),
          if (_isSubmitting) const _LoadingOverlay(),
        ],
      ),
    );
  }

  Widget _buildPasswordField(
    BuildContext context, {
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback toggle,
    String? Function(String?)? validator,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
          onPressed: toggle,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  String _errorMessageFor(String code) {
    switch (code) {
      case 'invalid-current-password':
        return _tr('invalid_current_password');
      case 'requires-recent-login':
        return _tr('requires_recent_login');
      case 'weak-password':
        return _tr('password_length');
      default:
        return _tr('change_password_generic_error');
    }
  }
}

class _LoadingOverlay extends StatelessWidget {
  const _LoadingOverlay();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: AbsorbPointer(
        absorbing: true,
        child: Container(
          alignment: Alignment.center,
          color: Colors.black.withValues(alpha: 0.35),
          child: const SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(strokeWidth: 4),
          ),
        ),
      ),
    );
  }
}
