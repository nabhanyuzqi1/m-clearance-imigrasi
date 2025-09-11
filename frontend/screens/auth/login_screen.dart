import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/user_account.dart';
import '../../services/user_service.dart';
import '../officer/admin_home_screen.dart';
import '../user/user_home_screen.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  String _selectedLanguage = 'EN';

  final String _adminUsername = "admin";
  final String _adminPassword = "admin";
  final String _adminFullName = "Admin Utama";

  final Map<String, Map<String, String>> _translations = {
    'EN': {
      'welcome': 'Welcome!',
      'username': 'Username',
      'username_hint': 'Enter your username',
      'username_req': 'Username is required',
      'password': 'Password',
      'password_hint': 'Enter your password',
      'password_req': 'Password is required',
      'forgot_password': 'Forgot password?',
      'login_button': 'Login',
      'not_a_member': 'Not a member?  ',
      'register_now': 'Register now',
      'invalid_credentials': 'Invalid username or password.',
      'account_pending': 'Your account is pending verification.',
      'account_rejected': 'Your account registration was rejected.',
    },
    'ID': {
      'welcome': 'Selamat Datang!',
      'username': 'Nama Pengguna',
      'username_hint': 'Masukkan nama pengguna Anda',
      'username_req': 'Nama pengguna harus diisi',
      'password': 'Kata Sandi',
      'password_hint': 'Masukkan kata sandi Anda',
      'password_req': 'Kata sandi harus diisi',
      'forgot_password': 'Lupa kata sandi?',
      'login_button': 'Masuk',
      'not_a_member': 'Bukan anggota?  ',
      'register_now': 'Daftar sekarang',
      'invalid_credentials': 'Nama pengguna atau kata sandi salah.',
      'account_pending': 'Akun Anda sedang menunggu verifikasi.',
      'account_rejected': 'Pendaftaran akun Anda ditolak.',
    }
  };

  String _tr(String key) => _translations[_selectedLanguage]![key] ?? key;
  
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
    _usernameController.dispose();
    _passwordController.dispose();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
    super.dispose();
  }

  void _performLogin() {
    if (_formKey.currentState!.validate()) {
      final username = _usernameController.text;
      final password = _passwordController.text;

      if (username == _adminUsername && password == _adminPassword) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => AdminHomeScreen(
              adminName: _adminFullName,
              adminUsername: _adminUsername,
            ),
          ),
        );
        return;
      }

      try {
        final userAccount = UserService.agentAccounts.firstWhere(
          (acc) => acc.username == username && acc.password == password,
        );

        switch (userAccount.status) {
          case AccountStatus.verified:
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => UserHomeScreen(username: userAccount.username)),
            );
            break;
          case AccountStatus.pending:
            _showErrorSnackbar(_tr('account_pending'));
            break;
          case AccountStatus.rejected:
            _showErrorSnackbar(_tr('account_rejected'));
            break;
        }
      } catch (e) {
        _showErrorSnackbar(_tr('invalid_credentials'));
      }
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.white,
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
          'assets/images/dermaga.jpg',
          height: headerHeight,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            height: headerHeight,
            color: Colors.blue.shade100,
            child: const Icon(Icons.image_not_supported, color: Colors.grey, size: 50),
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
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [ BoxShadow( color: Colors.black26, blurRadius: 10, offset: Offset(0, 4)) ],
            ),
            child: Image.asset(
              'assets/images/logo.png',
              height: logoSize,
              errorBuilder: (context, error, stackTrace) => Icon( Icons.directions_boat, size: logoSize, color: Colors.blue),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginForm() {
    final topPadding = (MediaQuery.of(context).size.height * 0.14 / 2) + 24;

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.fromLTRB(24.0, topPadding, 24.0, 12.0),
        child: Form(
          key: _formKey,
          child: Column(
            // PERBAIKAN: Menambahkan ValueKey untuk memastikan widget ini
            // dan semua turunannya digambar ulang saat bahasa berubah.
            key: ValueKey(_selectedLanguage),
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _tr('welcome'),
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _usernameController,
                decoration: _buildInputDecoration(hintText: _tr('username_hint'), labelText: _tr('username')),
                validator: (v) => v!.isEmpty ? _tr('username_req') : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: !_isPasswordVisible,
                decoration: _buildInputDecoration(
                  hintText: _tr('password_hint'),
                  labelText: _tr('password'),
                  suffixIcon: IconButton(
                    icon: Icon(_isPasswordVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.grey),
                    onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                  ),
                ),
                validator: (v) => v!.isEmpty ? _tr('password_req') : null,
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ForgotPasswordScreen(initialLanguage: _selectedLanguage))),
                  child: Text(_tr('forgot_password'), style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _performLogin,
                  child: Text(_tr('login_button'), style: const TextStyle(fontSize: 16, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(fontSize: 16, color: Colors.black54),
                    children: [
                      TextSpan(text: _tr('not_a_member')),
                      TextSpan(
                        text: _tr('register_now'),
                        style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                        recognizer: TapGestureRecognizer()..onTap = () => Navigator.push(context, MaterialPageRoute(builder: (context) => RegisterScreen(initialLanguage: _selectedLanguage))),
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
      errorBuilder: (context, error, stackTrace) => Container(
        height: 100,
        color: Colors.transparent,
      ),
    );
  }

  Widget _buildLanguageSwitcher() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(230),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [ BoxShadow( color: Colors.black.withAlpha(25), blurRadius: 5) ],
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
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          lang,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : Colors.grey.shade700,
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
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.blue, width: 2),
      ),
      filled: true,
      fillColor: Colors.grey.shade50,
    );
  }
}

