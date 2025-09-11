import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'upload_documents_screen.dart';

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

  final Map<String, Map<String, String>> _translations = {
    'EN': {
      'title': 'Email Verification',
      'header': 'Enter confirmation code',
      'subtitle': 'A 4-digit code was sent to\n',
      'code_invalid': 'Confirmation code must be 4 digits.',
      'resend_code': 'Resend code',
      'resend_success': 'A new code has been sent.',
      'continue': 'Continue',
    },
    'ID': {
      'title': 'Verifikasi Email',
      'header': 'Masukkan kode konfirmasi',
      'subtitle': 'Kode 4 digit telah dikirim ke\n',
      'code_invalid': 'Kode konfirmasi harus 4 digit.',
      'resend_code': 'Kirim ulang kode',
      'resend_success': 'Kode baru telah dikirim.',
      'continue': 'Lanjutkan',
    }
  };

  String _tr(String key) {
    return _translations[_selectedLanguage]![key] ?? key;
  }

  @override
  void initState() {
    super.initState();
    _selectedLanguage = widget.initialLanguage;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_focusNode);
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _verifyCode() {
    if (_codeController.text.length == 4) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => UploadDocumentsScreen(userData: widget.userData, initialLanguage: _selectedLanguage)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_tr('code_invalid')), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final String userEmail = widget.userData['email'] ?? 'your.email@example.com';

    return Scaffold(
      appBar: AppBar(
        title: Text(_tr('title')),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              _tr('header'),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              "${_tr('subtitle')}$userEmail",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 40),
            buildPinInput(),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(_tr('resend_success')), backgroundColor: Colors.blue),
                );
              },
              child: Text(_tr('resend_code'), style: const TextStyle(color: Colors.blue)),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _verifyCode,
                child: Text(_tr('continue')),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget buildPinInput() {
    return GestureDetector(
      onTap: () => _focusNode.requestFocus(),
      child: Stack(
        alignment: Alignment.center,
        children: [
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
                if (value.length == 4) {
                  _verifyCode();
                }
              },
              decoration: const InputDecoration(counterText: ''),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (index) {
              final text = _codeController.text;
              final hasChar = index < text.length;
              final isFocused = index == text.length && _focusNode.hasFocus;
              return Container(
                width: 50,
                height: 60,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: hasChar ? Colors.blue.withAlpha(12) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isFocused ? Colors.blue : Colors.grey.shade300, width: 2),
                ),
                child: Center(
                  child: hasChar
                      ? Text(text[index], style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold))
                      : null,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
