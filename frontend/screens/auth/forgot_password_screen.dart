import 'package:flutter/material.dart';

class ForgotPasswordScreen extends StatefulWidget {
  final String initialLanguage;
  const ForgotPasswordScreen({super.key, this.initialLanguage = 'EN'});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController _emailController = TextEditingController();
  late String _selectedLanguage;

  final Map<String, Map<String, String>> _translations = {
    'EN': {
      'title': 'Forgot Password',
      'instruction': 'Enter your account email to receive a password recovery link.',
      'email_label': 'Email Address',
      'send_link_button': 'Send Reset Link',
      'success_dialog_title': 'Success',
      'success_dialog_content': 'A link to reset your password has been sent to the email:\n',
      'ok_button': 'OK',
      'invalid_email_message': 'Please enter a valid email address.',
    },
    'ID': {
      'title': 'Lupa Kata Sandi',
      'instruction': 'Masukkan email akun Anda untuk menerima link pemulihan kata sandi.',
      'email_label': 'Alamat Email',
      'send_link_button': 'Kirim Link Reset',
      'success_dialog_title': 'Berhasil',
      'success_dialog_content': 'Link untuk mereset kata sandi telah dikirim ke email:\n',
      'ok_button': 'OK',
      'invalid_email_message': 'Mohon masukkan alamat email yang valid.',
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
    _emailController.dispose();
    super.dispose();
  }

  void _sendResetLink() {
    if (_emailController.text.isNotEmpty && _emailController.text.contains('@')) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(_tr('success_dialog_title')),
          content: Text("${_tr('success_dialog_content')}${_emailController.text}"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Go back from Forgot Password screen
              },
              child: Text(_tr('ok_button')),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_tr('invalid_email_message')), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_tr('title')),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            Text(
              _tr('instruction'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: _tr('email_label'),
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.email_outlined),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _sendResetLink,
              child: Text(_tr('send_link_button')),
            ),
          ],
        ),
      ),
    );
  }
}
