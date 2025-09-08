import 'package:flutter/material.dart';

class ChangePasswordScreen extends StatefulWidget {
  // PERBAIKAN: Menambahkan parameter initialLanguage untuk mendukung terjemahan.
  final String initialLanguage;
  const ChangePasswordScreen({super.key, this.initialLanguage = 'EN'});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController(); 
  final _confirmPasswordController = TextEditingController();

  bool _isCurrentPasswordVisible = false;
  bool _isNewPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  // PERBAIKAN: Menambahkan state untuk bahasa yang dipilih.
  late String _selectedLanguage;

  // PERBAIKAN: Menambahkan map terjemahan.
  final Map<String, Map<String, String>> _translations = {
    'EN': {
      'title': 'Change Password',
      'instruction': 'For security, please enter your old password and create a new one.',
      'current_password': 'Current Password',
      'current_password_empty': 'Current password cannot be empty',
      'new_password': 'New Password',
      'new_password_empty': 'New password cannot be empty',
      'password_length': 'Password must be at least 6 characters',
      'confirm_new_password': 'Confirm New Password',
      'confirm_password_empty': 'Please confirm your new password',
      'passwords_do_not_match': 'Passwords do not match',
      'save_new_password': 'Save New Password',
      'password_updated': 'Password updated successfully!',
    },
    'ID': {
      'title': 'Ubah Password',
      'instruction': 'Untuk keamanan, silakan masukkan password lama Anda dan buat password baru.',
      'current_password': 'Password Saat Ini',
      'current_password_empty': 'Password saat ini tidak boleh kosong',
      'new_password': 'Password Baru',
      'new_password_empty': 'Password baru tidak boleh kosong',
      'password_length': 'Password minimal harus 6 karakter',
      'confirm_new_password': 'Konfirmasi Password Baru',
      'confirm_password_empty': 'Mohon konfirmasi password baru Anda',
      'passwords_do_not_match': 'Password tidak cocok',
      'save_new_password': 'Simpan Password Baru',
      'password_updated': 'Password berhasil diperbarui!',
    }
  };

  String _tr(String key) => _translations[_selectedLanguage]![key] ?? key;

  @override
  void initState() {
    super.initState();
    _selectedLanguage = widget.initialLanguage;
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _submitChangePassword() {
    if (_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_tr('password_updated')),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_tr("title")),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            const SizedBox(height: 16),
            Text(_tr("instruction")),
            const SizedBox(height: 24),
            TextFormField(
              controller: _currentPasswordController,
              obscureText: !_isCurrentPasswordVisible,
              decoration: InputDecoration(
                labelText: _tr('current_password'),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_isCurrentPasswordVisible ? Icons.visibility : Icons.visibility_off),
                  onPressed: () {
                    setState(() {
                      _isCurrentPasswordVisible = !_isCurrentPasswordVisible;
                    });
                  },
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return _tr('current_password_empty');
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _newPasswordController,
              obscureText: !_isNewPasswordVisible,
              decoration: InputDecoration(
                labelText: _tr('new_password'),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_isNewPasswordVisible ? Icons.visibility : Icons.visibility_off),
                  onPressed: () {
                    setState(() {
                      _isNewPasswordVisible = !_isNewPasswordVisible;
                    });
                  },
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return _tr('new_password_empty');
                }
                if (value.length < 6) {
                  return _tr('password_length');
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: !_isConfirmPasswordVisible,
              decoration: InputDecoration(
                labelText: _tr('confirm_new_password'),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_isConfirmPasswordVisible ? Icons.visibility : Icons.visibility_off),
                  onPressed: () {
                    setState(() {
                      _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                    });
                  },
                ),
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
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _submitChangePassword,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(_tr('save_new_password')),
            ),
          ],
        ),
      ),
    );
  }
}
