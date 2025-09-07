import 'package:flutter/material.dart';

class AccountVerificationListScreen extends StatelessWidget {
  final String initialLanguage;
  const AccountVerificationListScreen({super.key, this.initialLanguage = 'EN'});

  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text("Account Verification")));
  }
}