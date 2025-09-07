import 'package:flutter/material.dart';

class DepartureVerificationScreen extends StatelessWidget {
  final String adminName;
  final String initialLanguage;

  const DepartureVerificationScreen({
    super.key,
    required this.adminName,
    this.initialLanguage = 'EN',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Departure Verification'),
      ),
      body: Center(
        child: Text('Departure Verification Screen for $adminName'),
      ),
    );
  }
}