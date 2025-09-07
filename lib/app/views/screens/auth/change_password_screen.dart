import 'package:flutter/material.dart';
import '../../../localization/app_strings.dart';

/// ChangePasswordScreen
///
/// Layar yang memungkinkan pengguna yang sudah login untuk mengubah password mereka.
/// Memerlukan input password saat ini dan password baru beserta konfirmasinya.
class ChangePasswordScreen extends StatefulWidget {
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

  late String _selectedLanguage;

  // Helper untuk mendapatkan string terjemahan
  String _tr(String key) => AppStrings.tr(context: context, screenKey: 'changePassword', stringKey: key, langCode: _selectedLanguage);

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

  // Memvalidasi form dan (disimulasikan) menyimpan password baru
  void _submitChangePassword() {
    if (_formKey.currentState!.validate()) {
      // TODO: Implementasi logika ganti password sesungguhnya
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
            // Input untuk password saat ini
            TextFormField(
              controller: _currentPasswordController,
              obscureText: !_isCurrentPasswordVisible,
              decoration: InputDecoration(
                labelText: _tr('current_password'),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_isCurrentPasswordVisible ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _isCurrentPasswordVisible = !_isCurrentPasswordVisible),
                ),
              ),
              validator: (value) => value == null || value.isEmpty ? _tr('current_password_empty') : null,
            ),
            const SizedBox(height: 16),
            // Input untuk password baru
            TextFormField(
              controller: _newPasswordController,
              obscureText: !_isNewPasswordVisible,
              decoration: InputDecoration(
                labelText: _tr('new_password'),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_isNewPasswordVisible ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _isNewPasswordVisible = !_isNewPasswordVisible),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) return _tr('new_password_empty');
                if (value.length < 6) return _tr('password_length');
                return null;
              },
            ),
            const SizedBox(height: 16),
            // Input untuk konfirmasi password baru
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: !_isConfirmPasswordVisible,
              decoration: InputDecoration(
                labelText: _tr('confirm_new_password'),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_isConfirmPasswordVisible ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _isConfirmPasswordVisible = !_isConfirmPasswordVisible),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) return _tr('confirm_password_empty');
                if (value != _newPasswordController.text) return _tr('passwords_do_not_match');
                return null;
              },
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _submitChangePassword,
              child: Text(_tr('save_new_password')),
            ),
          ],
        ),
      ),
    );
  }
}