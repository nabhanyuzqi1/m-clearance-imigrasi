import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../config/routes.dart';
import '../../../config/theme.dart';
import '../../../localization/app_localizations.dart';
import '../../../models/user_model.dart';
import '../../../services/auth_service.dart';
import '../../../services/logging_service.dart';
import '../../../services/security_service.dart';
import '../../../utils/device_utils.dart';
import '../../widgets/custom_button.dart';

class TwoFactorScreenArgs {
  const TwoFactorScreenArgs({
    required this.email,
    required this.password,
    required this.challenge,
    required this.deviceIdentity,
    required this.rememberDeviceDays,
  });

  final String email;
  final String password;
  final TwoFactorChallenge challenge;
  final DeviceIdentity deviceIdentity;
  final int rememberDeviceDays;
}

class TwoFactorScreen extends StatefulWidget {
  const TwoFactorScreen({super.key, required this.args});

  final TwoFactorScreenArgs args;

  @override
  State<TwoFactorScreen> createState() => _TwoFactorScreenState();
}

class _TwoFactorScreenState extends State<TwoFactorScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _codeController = TextEditingController();
  bool _isVerifying = false;
  bool _trustDevice = true;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  String _tr(String key) =>
      AppLocalizations.of(context).get('twoFactor.$key');

  Future<void> _submit() async {
    final code = _codeController.text.trim();
    if (code.length < 4) {
      setState(() => _error = _tr('invalid_code'));
      return;
    }
    setState(() {
      _isVerifying = true;
      _error = null;
    });

    try {
      final user = await _authService.completeTwoFactorSignIn(
        email: widget.args.email,
        password: widget.args.password,
        challengeId: widget.args.challenge.id,
        code: code,
        deviceIdentity: widget.args.deviceIdentity,
        trustDevice: _trustDevice,
        rememberDeviceDays: widget.args.rememberDeviceDays,
      );
      if (user == null) {
        setState(() {
          _error = _tr('unknown_error');
          _isVerifying = false;
        });
        return;
      }
      await _navigateAfterLogin(user);
    } on TwoFactorVerificationFailedException {
      setState(() {
        _error = _tr('invalid_code');
        _isVerifying = false;
      });
    } catch (error, stackTrace) {
      LoggingService().error('Two-factor verification failed', error, stackTrace);
      setState(() {
        _error = _tr('unknown_error');
        _isVerifying = false;
      });
    }
  }

  Future<void> _navigateAfterLogin(UserModel userModel) async {
    if (!mounted) return;
    switch (userModel.status) {
      case 'approved':
        if (userModel.role == 'admin' || userModel.role == 'officer') {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt('officer_selected_index', 0);
          final corporateName = userModel.corporateName.trim();
          final fullName = userModel.fullName.trim();
          final displayName = fullName.isNotEmpty
              ? fullName
              : (corporateName.isNotEmpty ? corporateName : userModel.username);
          if (!mounted) return;
          Navigator.pushReplacementNamed(
            context,
            AppRoutes.adminHome,
            arguments: {
              'adminName': displayName,
              'adminUsername': userModel.username,
              'adminCorporateName': corporateName,
              'photoURL': userModel.photoURL,
            },
          );
        } else {
          if (!mounted) return;
          Navigator.pushReplacementNamed(context, AppRoutes.userHome);
        }
        break;
      case 'pending_email_verification':
        if (!mounted) return;
        Navigator.pushNamed(
          context,
          AppRoutes.confirmation,
          arguments: {
            'userData': {'email': userModel.email},
          },
        );
        break;
      case 'pending_documents':
        if (!mounted) return;
        Navigator.pushNamed(
          context,
          AppRoutes.uploadDocuments,
          arguments: {'uid': userModel.uid},
        );
        break;
      case 'pending_approval':
        if (!mounted) return;
        Navigator.pushNamed(context, AppRoutes.registrationPending);
        break;
      case 'rejected':
        setState(() => _error = _tr('account_rejected'));
        break;
      default:
        setState(() => _error = _tr('unknown_status'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final challenge = widget.args.challenge;
    final displayEmail = challenge.deliveryTarget.isNotEmpty
        ? challenge.deliveryTarget
        : widget.args.email;

    return Scaffold(
      appBar: AppBar(
        title: Text(_tr('title')),
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _tr('subtitle').replaceFirst('{email}', displayEmail),
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppTheme.spacing24),
            TextField(
              controller: _codeController,
              enabled: !_isVerifying,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: InputDecoration(
                labelText: _tr('code_label'),
                hintText: _tr('code_hint'),
                counterText: '',
                errorText: _error,
              ),
            ),
            const SizedBox(height: AppTheme.spacing12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _tr('trust_device'),
                  style: textTheme.bodyMedium,
                ),
                Switch(
                  value: _trustDevice,
                  onChanged:
                      _isVerifying ? null : (value) => setState(() => _trustDevice = value),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacing12),
            Text(
              _tr('expires_at').replaceFirst(
                '{time}',
                challenge.expiresAt.toLocal().toString(),
              ),
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const Spacer(),
            CustomButton(
              text: _isVerifying ? _tr('verifying') : _tr('verify'),
              isFullWidth: true,
              onPressed: _isVerifying ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}
