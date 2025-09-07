import 'package:flutter/material.dart';

class ArrivalVerificationScreen extends StatelessWidget {
  final String adminName;
  final String initialLanguage;

  const ArrivalVerificationScreen({
    super.key,
    required this.adminName,
    this.initialLanguage = 'EN',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Arrival Verification'),
      ),
      body: Center(
        child: Text('Arrival Verification Screen for $adminName'),
      ),
    );
  }
}