import 'package:flutter/material.dart';

class AccountDetailScreen extends StatelessWidget {
  final String initialLanguage;
  const AccountDetailScreen({super.key, this.initialLanguage = 'EN'});

  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text("Account Detail")));
  }
}