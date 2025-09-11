import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../../config/routes.dart';
import '../../../config/theme.dart';
import '../../../localization/app_strings.dart';
import '../../../services/auth_service.dart';
import '../../../services/logging_service.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_textfield.dart';
import '../../../providers/language_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;

  String _tr(String key) {
    final langCode = Provider.of<LanguageProvider>(context, listen: false).locale.languageCode;
    return AppStrings.tr(context: context, screenKey: 'login', stringKey: key, langCode: langCode.toUpperCase());
  }

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
    super.dispose();
  }

  void _performLogin() async {
    if (_formKey.currentState!.validate()) {
      LoggingService().info('Login attempt for email: ${_emailController.text}');
      setState(() {
        _isLoading = true;
      });
      try {
        final userModel = await _authService.signInWithEmailAndPassword(
          _emailController.text,
          _passwordController.text,
        );
        if (userModel != null) {
          LoggingService().info('Login successful for user: ${userModel.email}, status: ${userModel.status}');
          switch (userModel.status) {
            case 'approved':
              if (userModel.role == 'admin' || userModel.role == 'officer') {
                if (mounted) {
                  LoggingService().info('Navigating to admin home for officer/admin: ${userModel.email}');
                  Navigator.pushReplacementNamed(context, AppRoutes.adminHome, arguments: {
                    'adminName': userModel.username,
                    'adminUsername': userModel.email,
                  });
                }
              } else {
                if (mounted) {
                  LoggingService().info('Navigating to user home for user: ${userModel.email}');
                  Navigator.pushReplacementNamed(context, AppRoutes.userHome);
                }
              }
              break;
            case 'pending_email_verification':
              if (mounted) {
                LoggingService().info('Navigating to email verification for user: ${userModel.email}');
                Navigator.pushNamed(context, AppRoutes.confirmation, arguments: {
                  'userData': {'email': userModel.email},
                });
              }
              break;
            case 'pending_documents':
              if (mounted) {
                LoggingService().info('Navigating to document upload for user: ${userModel.email}');
                Navigator.pushNamed(context, AppRoutes.uploadDocuments, arguments: {'uid': userModel.uid});
              }
              break;
            case 'pending_approval':
              if (mounted) {
                LoggingService().info('Navigating to registration pending for user: ${userModel.email}');
                Navigator.pushNamed(context, AppRoutes.registrationPending);
              }
              break;
            case 'rejected':
              LoggingService().warning('Login attempt for rejected user: ${userModel.email}');
              _showErrorSnackbar(_tr('account_rejected_full'));
              await _authService.signOut();
              break;
            default:
              LoggingService().error('Unknown user status for user: ${userModel.email}, status: ${userModel.status}');
              _showErrorSnackbar(_tr('unknown_user_status'));
              await _authService.signOut();
          }
        } else {
          LoggingService().warning('Login failed: Invalid credentials for email: ${_emailController.text}');
          _showErrorSnackbar('Invalid username or password.');
        }
      } on FirebaseAuthException catch (e) {
        LoggingService().error('Login failed with FirebaseAuthException: ${e.message}', e);
        _showErrorSnackbar(e.message ?? _tr('unknown_error'));
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.errorColor),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final responsivePadding = AppTheme.responsivePadding(context);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Stack(
        children: [
          Scaffold(
            resizeToAvoidBottomInset: true,
            backgroundColor: AppTheme.backgroundColor,
            body: Stack(
              fit: StackFit.expand,
              children: [
                // Harbor image (top)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Image.asset(
                    'assets/images/dermaga.png',
                    fit: BoxFit.cover,
                    width: screenWidth,
                    errorBuilder: (context, error, stackTrace) =>
                        const SizedBox.shrink(),
                  ),
                ),
                // Ship image (bottom)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Image.asset(
                    'assets/images/shipping.png',
                    fit: BoxFit.cover,
                    width: screenWidth,
                    errorBuilder: (context, error, stackTrace) =>
                        const SizedBox.shrink(),
                  ),
                ),
                // Scrollable content
                SafeArea(
                  child: Center(
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: responsivePadding * 2),
                        child: Container(
                          padding: EdgeInsets.all(responsivePadding * 2),
                          decoration: BoxDecoration(
                            color: AppTheme.whiteColor,
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusLarge),
                          ),
                          child: _buildLoginForm(),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: MediaQuery.of(context).padding.top + AppTheme.paddingSmall,
                  right: responsivePadding * 2,
                  child: _buildLanguageSwitcher(),
                ),
              ],
            ),
          ),
          if (_isLoading)
            Container(
              color: AppTheme.blackColor.withAlpha(128),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: AppTheme.paddingLarge),
                    Text(
                      _tr('logging_in'),
                      style: const TextStyle(
                        color: AppTheme.whiteColor,
                        fontSize: AppTheme.fontSizeLarge,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLoginForm() {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return Form(
          key: _formKey,
          child: Column(
            key: ValueKey(languageProvider.locale),
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Image.asset(
                  'assets/images/logo.png',
                  height: AppTheme.fontSizeXXXXLarge * 3,
                  errorBuilder: (context, error, stackTrace) => Icon(
                      Icons.directions_boat,
                      size: AppTheme.fontSizeXXXXLarge * 2,
                      color: AppTheme.primaryColor),
                ),
              ),
              const SizedBox(height: AppTheme.paddingLarge),
              Text(
                _tr('welcome'),
                style: TextStyle(
                  fontSize: AppTheme.responsiveFontSize(context,
                      mobile: AppTheme.fontSizeLarge,
                      tablet: AppTheme.fontSizeExtraLarge,
                      desktop: AppTheme.fontSizeXXLarge),
                  fontWeight: FontWeight.bold,
                  color: AppTheme.headingColor,
                  fontFamily: 'Poppins',
                ),
              ),
              const SizedBox(height: AppTheme.paddingLarge),
              CustomTextField(
                controller: _emailController,
                label: _tr('email'),
                hint: _tr('email_hint'),
                prefixIcon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v!.isEmpty) return _tr('email_req');
                  if (!RegExp(r"^[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-zA-Z]+")
                      .hasMatch(v)) {
                    return _tr('email_invalid');
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppTheme.paddingMedium),
              CustomTextField(
                controller: _passwordController,
                label: _tr('password'),
                hint: _tr('password_hint'),
                prefixIcon: Icons.lock_outline,
                obscureText: !_isPasswordVisible,
                suffixIcon: IconButton(
                  icon: Icon(
                      _isPasswordVisible
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: AppTheme.subtitleColor),
                  onPressed: () =>
                      setState(() => _isPasswordVisible = !_isPasswordVisible),
                ),
                validator: (v) => v!.isEmpty ? _tr('password_req') : null,
              ),
              const SizedBox(),
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: CustomButton(
                    text: _tr('forgot_password'),
                    type: CustomButtonType.text,
                    onPressed: () =>
                        Navigator.pushNamed(context, AppRoutes.forgotPassword),
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.paddingMedium),
              CustomButton(
                text: _tr('login_button'),
                type: CustomButtonType.elevated,
                isFullWidth: true,
                onPressed: _performLogin,
              ),
              const SizedBox(height: AppTheme.paddingMedium),
              Center(
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: AppTheme.fontSizeLarge,
                      color: AppTheme.blackColor54,
                      fontFamily: 'Poppins',
                    ),
                    children: [
                      TextSpan(text: _tr('not_a_member')),
                      TextSpan(
                        text: _tr('register_now'),
                        style: TextStyle(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Poppins',
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap =
                              () => Navigator.pushNamed(context, AppRoutes.register),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLanguageSwitcher() {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.language, color: AppTheme.whiteColor),
      onSelected: (String newValue) {
        final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
        languageProvider.setLocale(Locale(newValue.toLowerCase()));
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          value: 'EN',
          child: Text(_tr('english')),
        ),
        PopupMenuItem<String>(
          value: 'ID',
          child: Text(_tr('indonesian')),
        ),
      ],
      color: AppTheme.whiteColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
    );
  }
}
