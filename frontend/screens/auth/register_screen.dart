import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'confirmation_screen.dart';

class RegisterScreen extends StatefulWidget {
  final String initialLanguage;
  const RegisterScreen({super.key, this.initialLanguage = 'EN'});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _corporateNameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _agreeToTerms = false;
  late String _selectedLanguage;

  final Map<String, Map<String, String>> _translations = {
    'EN': {
      'sign_up': 'Sign up',
      'create_account_subtitle': 'Create an account to get started',
      'corporate_name': 'Corporate Name',
      'corporate_name_hint': 'PT. Example Corporation',
      'corporate_name_req': 'Corporate Name is required',
      'username': 'Username',
      'username_hint': 'example_name',
      'username_req': 'Username is required',
      'email': 'Email Address',
      'email_hint': 'name@email.com',
      'email_req': 'Email is required',
      'email_invalid': 'Invalid email format',
      'password': 'Password',
      'password_hint': 'Create a password',
      'password_req': 'Password is required',
      'password_length': 'Password must be at least 6 characters',
      'confirm_password': 'Confirm Password',
      'confirm_password_hint': 'Confirm password',
      'confirm_password_req': 'Please confirm your password',
      'password_mismatch': 'Passwords do not match',
      'terms_agree': "I've read and agree with the ",
      'terms_and_conditions': 'Terms and Conditions',
      'and': ' and the ',
      'privacy_policy': 'Privacy Policy',
      'terms_req': 'You must agree to the Terms & Conditions and Privacy Policy.',
      'continue': 'Continue',
      'already_have_account': 'Already have an account? ',
      'login': 'Login',
    },
    'ID': {
      'sign_up': 'Daftar',
      'create_account_subtitle': 'Buat akun untuk memulai',
      'corporate_name': 'Nama Perusahaan',
      'corporate_name_hint': 'PT. Contoh Korporasi',
      'corporate_name_req': 'Nama Perusahaan harus diisi',
      'username': 'Nama Pengguna',
      'username_hint': 'contoh_nama',
      'username_req': 'Nama Pengguna harus diisi',
      'email': 'Alamat Email',
      'email_hint': 'nama@email.com',
      'email_req': 'Email harus diisi',
      'email_invalid': 'Format email tidak valid',
      'password': 'Kata Sandi',
      'password_hint': 'Buat kata sandi',
      'password_req': 'Kata Sandi harus diisi',
      'password_length': 'Kata Sandi minimal 6 karakter',
      'confirm_password': 'Konfirmasi Kata Sandi',
      'confirm_password_hint': 'Konfirmasi kata sandi',
      'confirm_password_req': 'Mohon konfirmasi kata sandi Anda',
      'password_mismatch': 'Kata sandi tidak cocok',
      'terms_agree': "Saya telah membaca dan setuju dengan ",
      'terms_and_conditions': 'Syarat & Ketentuan',
      'and': ' dan ',
      'privacy_policy': 'Kebijakan Privasi',
      'terms_req': 'Anda harus menyetujui Syarat & Ketentuan serta Kebijakan Privasi.',
      'continue': 'Lanjutkan',
      'already_have_account': 'Sudah punya akun? ',
      'login': 'Masuk',
    }
  };

  String _tr(String key) {
    return _translations[_selectedLanguage]![key] ?? key;
  }
  
  @override
  void initState() {
    super.initState();
    _selectedLanguage = widget.initialLanguage;
  }

  @override
  void dispose() {
    _corporateNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _goToNextStep() {
    if (!_agreeToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_tr('terms_req')), backgroundColor: Colors.red),
      );
      return;
    }

    if (_formKey.currentState!.validate()) {
      final Map<String, String> userData = {
        "name": _corporateNameController.text,
        "username": _usernameController.text,
        "email": _emailController.text,
        "password": _passwordController.text,
      };

      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ConfirmationScreen(userData: userData, initialLanguage: _selectedLanguage)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_tr('sign_up'), style: const TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      backgroundColor: Colors.white,
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24.0),
          children: [
            Text(_tr('create_account_subtitle'), style: const TextStyle(fontSize: 16, color: Colors.black54)),
            const SizedBox(height: 10),
            _buildLabel(_tr('corporate_name')),
            TextFormField(
              controller: _corporateNameController,
              decoration: _buildInputDecoration(hintText: _tr('corporate_name_hint')),
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
            _buildLabel(_tr('email')),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: _buildInputDecoration(hintText: _tr('email_hint')),
              validator: (v) {
                if (v!.isEmpty) return _tr('email_req');
                if (!v.contains('@') || !v.contains('.')) return _tr('email_invalid');
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
                  icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off, color: Colors.grey),
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
                  icon: Icon(_isConfirmPasswordVisible ? Icons.visibility : Icons.visibility_off, color: Colors.grey),
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Checkbox(
                  value: _agreeToTerms,
                  onChanged: (value) => setState(() => _agreeToTerms = value!),
                  activeColor: Colors.blue,
                ),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(fontSize: 14, color: Colors.black54),
                      children: [
                        TextSpan(text: _tr('terms_agree')),
                        TextSpan(
                          text: _tr('terms_and_conditions'),
                          style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.w600),
                          recognizer: TapGestureRecognizer()..onTap = () {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Membuka Syarat & Ketentuan...")));
                          },
                        ),
                        TextSpan(text: _tr('and')),
                        TextSpan(
                          text: _tr('privacy_policy'),
                          style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.w600),
                          recognizer: TapGestureRecognizer()..onTap = () {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Membuka Kebijakan Privasi...")));
                          },
                        ),
                        const TextSpan(text: '.'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _goToNextStep,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(_tr('continue'), style: const TextStyle(fontSize: 17)),
            ),
            const SizedBox(height: 10),
            Center(
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(fontSize: 16, color: Colors.black54),
                  children: [
                    TextSpan(text: _tr('already_have_account')),
                    TextSpan(
                      text: _tr('login'),
                      style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                      recognizer: TapGestureRecognizer()..onTap = () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
    );
  }

  InputDecoration _buildInputDecoration({String? hintText, Widget? suffixIcon}) {
    return InputDecoration(
      hintText: hintText,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.blue, width: 2)),
      filled: true,
      fillColor: Colors.grey[100],
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      suffixIcon: suffixIcon,
    );
  }
}
