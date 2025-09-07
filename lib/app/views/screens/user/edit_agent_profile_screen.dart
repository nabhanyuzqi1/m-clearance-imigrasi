import 'package:flutter/material.dart';

class EditAgentProfileScreen extends StatelessWidget {
  final String username;
  final String currentName;
  final String currentEmail;
  final String initialLanguage;

  const EditAgentProfileScreen({
    super.key,
    required this.username,
    required this.currentName,
    required this.currentEmail,
    this.initialLanguage = 'EN',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Agent Profile'),
      ),
      body: Center(
        child: Text('Editing profile for $username'),
      ),
    );
  }
}