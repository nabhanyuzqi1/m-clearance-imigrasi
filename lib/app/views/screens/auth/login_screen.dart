import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../config/routes.dart';
import '../../../config/theme.dart';
import '../../../localization/app_strings.dart';
import '../../../services/auth_service.dart';
import '../../../models/user_model.dart';

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
  String _selectedLanguage = 'EN';

  String _tr(String key) {
    return AppStrings.tr(context: context, screenKey: 'login', stringKey: key, langCode: _selectedLanguage);
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
      try {
        final userModel = await _authService.signInWithEmailAndPassword(
          _emailController.text,
          _passwordController.text,
        );
        if (userModel != null) {
          switch (userModel.status) {
            case 'approved':
              if (userModel.role == 'admin' || userModel.role == 'officer') {
                Navigator.pushReplacementNamed(context, AppRoutes.adminHome);
              } else {
                Navigator.pushReplacementNamed(context, AppRoutes.userHome);
              }
              break;
            case 'pending_email_verification':
              Navigator.pushNamed(context, AppRoutes.emailVerification, arguments: {'uid': userModel.uid});
              break;
            case 'pending_documents':
              Navigator.pushNamed(context, AppRoutes.uploadDocuments, arguments: {'uid': userModel.uid});
              break;
            case 'pending_approval':
              Navigator.pushNamed(context, AppRoutes.registrationPending);
              break;
            case 'rejected':
              _showErrorSnackbar(
                  'Your account has been rejected. Please contact support for more information.');
              await _authService.signOut();
              break;
            default:
              _showErrorSnackbar('Unknown user status.');
              await _authService.signOut();
          }
        } else {
          _showErrorSnackbar('Invalid username or password.');
        }
      } on FirebaseAuthException catch (e) {
        _showErrorSnackbar(e.message ?? 'An unknown error occurred.');
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
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: AppTheme.backgroundColor,
      body: SizedBox(
        height: MediaQuery.of(context).size.height,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _buildLoginForm(),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final screenHeight = MediaQuery.of(context).size.height;
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final headerHeight = screenHeight * 0.28;
    final logoSize = screenHeight * 0.14;

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Image.asset(
          'assets/images/dermaga.png',
          height: headerHeight,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            height: headerHeight,
            color: AppTheme.primaryColor.withOpacity(0.1),
            child: const Icon(Icons.image_not_supported, color: AppTheme.subtitleColor, size: 50),
          ),
        ),
        Positioned(
          top: statusBarHeight + 10,
          right: 20,
          child: _buildLanguageSwitcher(),
        ),
        Positioned(
          bottom: -(logoSize / 2),
          child: Container(
            padding: const EdgeInsets.all(AppTheme.paddingSmall),
            decoration: const BoxDecoration(
              color: AppTheme.backgroundColor,
              shape: BoxShape.circle,
              boxShadow: [ BoxShadow( color: Colors.black26, blurRadius: 10, offset: Offset(0, 4)) ],
            ),
            child: Image.asset(
              'assets/images/logo.png',
              height: logoSize,
              errorBuilder: (context, error, stackTrace) => Icon( Icons.directions_boat, size: logoSize, color: AppTheme.primaryColor),
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildLoginForm() {
    final topPadding = (MediaQuery.of(context).size.height * 0.14 / 2) + AppTheme.paddingLarge;

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.fromLTRB(AppTheme.paddingLarge, topPadding, AppTheme.paddingLarge, AppTheme.paddingMedium),
        child: Form(
          key: _formKey,
          child: Column(
            key: ValueKey(_selectedLanguage),
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _tr('welcome'),
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppTheme.paddingLarge),
              TextFormField(
                controller: _emailController,
                decoration: _buildInputDecoration(
                  hintText: _tr('email_hint'),
                  labelText: _tr('email'),
                ),
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
              TextFormField(
                controller: _passwordController,
                obscureText: !_isPasswordVisible,
                decoration: _buildInputDecoration(
                  hintText: _tr('password_hint'),
                  labelText: _tr('password'),
                  suffixIcon: IconButton(
                    icon: Icon(_isPasswordVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: AppTheme.subtitleColor),
                    onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                  ),
                ),
                validator: (v) => v!.isEmpty ? _tr('password_req') : null,
              ),
              const SizedBox(height: AppTheme.paddingSmall),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pushNamed(context, AppRoutes.forgotPassword, arguments: {'initialLanguage': _selectedLanguage}),
                  child: Text(_tr('forgot_password'), style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: AppTheme.paddingMedium),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _performLogin,
                  child: Text(_tr('login_button')),
                ),
              ),
              const SizedBox(height: AppTheme.paddingMedium),
              Center(
                child: RichText(
                  text: TextSpan(
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.black54),
                    children: [
                      TextSpan(text: _tr('not_a_member')),
                      TextSpan(
                        text: _tr('register_now'),
                        style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
                        recognizer: TapGestureRecognizer()..onTap = () => Navigator.pushNamed(context, AppRoutes.register, arguments: {'initialLanguage': _selectedLanguage}),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildFooter() {
     return Image.asset(
      'assets/images/shipping.png',
      width: double.infinity,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => const SizedBox(height: 100),
    );
  }

  Widget _buildLanguageSwitcher() {
     return Container(
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [ BoxShadow( color: Colors.black.withOpacity(0.1), blurRadius: 5) ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _languageButton('EN'),
          _languageButton('ID'),
        ],
      ),
    );
  }
   Widget _languageButton(String lang) {
    bool isSelected = _selectedLanguage == lang;
    return InkWell(
      onTap: () => setState(() => _selectedLanguage = lang),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.paddingMedium, vertical: AppTheme.paddingSmall),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          lang,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : AppTheme.subtitleColor,
          ),
        ),
      ),
    );
  }
  
  InputDecoration _buildInputDecoration({required String labelText, required String hintText, Widget? suffixIcon}) {
     return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      suffixIcon: suffixIcon,
    );
  }
}