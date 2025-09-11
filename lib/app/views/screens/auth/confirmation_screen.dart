import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../config/routes.dart';
import '../../../config/theme.dart';
import '../../../localization/app_strings.dart';
import '../../../models/user_model.dart';
import '../../../services/functions_service.dart';
import '../../../services/auth_service.dart';

/// ConfirmationScreen
///
/// Layar ini meminta pengguna untuk memasukkan kode verifikasi 4 digit
/// yang (disimulasikan) dikirim ke email mereka setelah registrasi.
class ConfirmationScreen extends StatefulWidget {
  final Map<String, String> userData;
  final String initialLanguage;
  const ConfirmationScreen({super.key, required this.userData, this.initialLanguage = 'EN'});

  @override
  State<ConfirmationScreen> createState() => _ConfirmationScreenState();
}

class _ConfirmationScreenState extends State<ConfirmationScreen> {
  final TextEditingController _codeController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  late String _selectedLanguage;
  static const int _defaultCooldown = 60; // keep in sync with server default
  int _cooldownSec = 0;
  Timer? _cooldownTimer;
  String _lastSentMasked = '';
  bool _isVerifying = false;
  bool _completed = false;

  // Helper untuk mendapatkan string terjemahan
  String _tr(String key) {
    return AppStrings.tr(context: context, screenKey: 'confirmation', stringKey: key, langCode: _selectedLanguage);
  }

  @override
  void initState() {
    super.initState();
    _selectedLanguage = widget.initialLanguage;
    // Otomatis fokus ke input PIN saat layar dimuat
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_focusNode);
    });
    // Ensure user authenticated; if not, go to login
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pushReplacementNamed(context, AppRoutes.login);
      });
    }
    // Automatically send verification code on first load
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _resendCode(silent: true);
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    _focusNode.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  // Verifikasi kode dan navigasi ke langkah berikutnya
  void _verifyCode() {
    final code = _codeController.text.trim();
    if (code.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_tr('code_invalid')), backgroundColor: AppTheme.errorColor),
      );
      return;
    }
    final fx = FunctionsService();
    if (_isVerifying || _completed) return;
    setState(() {
      _isVerifying = true;
    });
    fx.verifyEmailCode(code).then((_) async {
      if (!mounted) return;
      // Refresh client user to reflect verification
      UserModel? updatedUser;
      try {
        updatedUser = await AuthService().updateEmailVerified();
        print('DEBUG: confirmation_screen: updateEmailVerified returned status = ${updatedUser?.status}');
      } catch (_) {}
      setState(() {
        _isVerifying = false;
        _completed = true;
      });

      // Navigate based on user status
      String nextRoute;
      Map<String, dynamic> arguments = {'initialLanguage': _selectedLanguage};
      if (updatedUser != null) {
        final status = updatedUser.status;
        if (status == 'pending_documents') {
          nextRoute = AppRoutes.uploadDocuments;
          arguments['userData'] = widget.userData;
        } else if (status == 'pending_approval') {
          nextRoute = AppRoutes.registrationPending;
        } else if (status == 'approved') {
          nextRoute = AppRoutes.userHome;
        } else {
          // For unknown statuses, default to login
          nextRoute = AppRoutes.login;
        }
      } else {
        // If no user data, go to login
        nextRoute = AppRoutes.login;
      }

      if (mounted) {
        Navigator.pushReplacementNamed(context, nextRoute, arguments: arguments);
      }
    }).catchError((e) {
      if (!mounted) return;
      setState(() {
        _isVerifying = false;
      });
      String msg = _tr('verification_failed');
      if (e is FirebaseFunctionsException) {
        msg = e.message ?? msg;
      } else {
        msg = e.toString();
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppTheme.errorColor));
    });
  }

  Future<void> _resendCode({bool silent = false}) async {
    try {
      // Ensure signed-in state
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, AppRoutes.login);
        return;
      }
      final resp = await FunctionsService().issueEmailVerificationCodeEx();
      if (resp.isNotEmpty && resp['ok'] == false && resp['reason'] == 'cooldown') {
        final remain = resp['retryAfterSec'] ?? 0;
        if (!mounted || silent) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_tr('please_wait_cooldown').replaceAll('{seconds}', remain.toString())), backgroundColor: AppTheme.warningColor),
        );
        _startCooldown(remain is int && remain > 0 ? remain : _defaultCooldown);
        return;
      }
      if (!mounted || silent) return;
      // Set a client-side cooldown after successful enqueue
      _startCooldown(_defaultCooldown);
      // Mask email hint
      final email = FirebaseAuth.instance.currentUser?.email ?? widget.userData['email'] ?? '';
      setState(() {
        _lastSentMasked = _maskEmail(email);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_tr('resend_success')), backgroundColor: AppTheme.infoColor),
      );
    } catch (e) {
      if (!mounted || silent) return;
      String msg = _tr('internal_error');
      if (e is FirebaseFunctionsException) {
        msg = e.message ?? msg;
      } else {
        msg = e.toString();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_tr('failed_to_resend_code')}: $msg'), backgroundColor: AppTheme.errorColor),
      );
    }
  }

  void _startCooldown(int seconds) {
    if (seconds <= 0) return;
    _cooldownTimer?.cancel();
    setState(() => _cooldownSec = seconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        _cooldownSec = (_cooldownSec - 1).clamp(0, 9999);
        if (_cooldownSec <= 0) {
          t.cancel();
        }
      });
    });
  }

  String _maskEmail(String email) {
    if (email.isEmpty || !email.contains('@')) return '';
    final parts = email.split('@');
    final local = parts[0];
    final domain = parts[1];
    String maskPart(String s) {
      if (s.length <= 2) return s;
      return s[0] + '*' * (s.length - 2) + s[s.length - 1];
    }
    final maskedLocal = maskPart(local);
    final domainParts = domain.split('.');
    if (domainParts.isEmpty) return '$maskedLocal@$domain';
    domainParts[0] = maskPart(domainParts[0]);
    final maskedDomain = domainParts.join('.');
    return '$maskedLocal@$maskedDomain';
  }

  @override
  Widget build(BuildContext context) {
    final String userEmail = widget.userData['email'] ??
        FirebaseAuth.instance.currentUser?.email ??
        'your.email@example.com';
    return Scaffold(
      appBar: AppBar(
        title: Text(_tr('title')),
        automaticallyImplyLeading: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              Navigator.pushReplacementNamed(context, AppRoutes.login);
            }
          },
        ),
      ),
      backgroundColor: AppTheme.backgroundColor,
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: AppTheme.spacing24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(height: AppTheme.spacing24),
            Text(
              _tr('header'),
              style: TextStyle(
                fontSize: AppTheme.fontSizeH5,
                fontWeight: FontWeight.bold,
                fontFamily: 'Poppins',
                color: AppTheme.onSurface,
              ),
            ),
            SizedBox(height: AppTheme.spacing12),
            Text(
              "${_tr('subtitle')}$userEmail",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppTheme.fontSizeBody1,
                color: AppTheme.subtitleColor,
                fontFamily: 'Poppins',
              ),
            ),
            if (_lastSentMasked.isNotEmpty) ...[
              SizedBox(height: AppTheme.spacing8),
              Text(
                _tr('sent_to') + _lastSentMasked,
                style: TextStyle(
                  fontSize: AppTheme.fontSizeCaption,
                  color: AppTheme.subtitleColor,
                  fontFamily: 'Poppins',
                ),
              ),
            ],
            SizedBox(height: AppTheme.spacing40),
            _buildPinInput(),
            SizedBox(height: AppTheme.spacing24),
            _buildResendButton(),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isVerifying || _completed ? null : _verifyCode,
                child: _isVerifying
                    ? SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.onPrimary))
                    : Text(_tr('continue')),
              ),
            ),
            SizedBox(height: AppTheme.spacing40),
          ],
        ),
      ),
    );
  }

  // Widget kustom untuk input PIN 4 digit
  Widget _buildPinInput() {
    return GestureDetector(
      onTap: () => _focusNode.requestFocus(),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // TextField tersembunyi untuk menangani input keyboard
          Opacity(
            opacity: 0,
            child: TextField(
              controller: _codeController,
              focusNode: _focusNode,
              keyboardType: TextInputType.number,
              maxLength: 4,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (value) {
                setState(() {});
                if (value.length == 4 && !_isVerifying && !_completed) {
                  _verifyCode();
                }
              },
              decoration: const InputDecoration(counterText: ''),
            ),
          ),
          // Tampilan visual dari kotak-kotak PIN
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (index) {
              final text = _codeController.text;
              final hasChar = index < text.length;
              final isFocused = index == text.length && _focusNode.hasFocus;
              return Container(
                width: 50,
                height: 60,
                margin: EdgeInsets.symmetric(horizontal: AppTheme.spacing8),
                decoration: BoxDecoration(
                  color: hasChar ? AppTheme.primaryColor.withAlpha(12) : AppTheme.whiteColor,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  border: Border.all(color: isFocused ? AppTheme.primaryColor : AppTheme.greyShade300, width: 2),
                ),
                child: Center(
                  child: hasChar
                      ? Text(text[index], style: TextStyle(fontSize: AppTheme.fontSizeH5, fontWeight: FontWeight.bold, fontFamily: 'Poppins', color: AppTheme.onSurface))
                      : null,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildResendButton() {
    final disabled = _cooldownSec > 0;
    final label = disabled ? '${_tr('resend_in')}${_cooldownSec}s' : _tr('resend_code');
    return TextButton(
      onPressed: disabled ? null : () => _resendCode(),
      child: Text(
        label,
        style: TextStyle(color: disabled ? AppTheme.greyShade600 : AppTheme.primaryColor, fontFamily: 'Poppins'),
      ),
    );
  }
}
