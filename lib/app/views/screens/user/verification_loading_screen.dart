import 'package:flutter/material.dart';
import '../../../models/clearance_application.dart';

class VerificationLoadingScreen extends StatelessWidget {
  final ClearanceApplication application;
  final String initialLanguage;

  const VerificationLoadingScreen({
    super.key,
    required this.application,
    this.initialLanguage = 'EN',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verifying...'),
      ),
      body: Center(
        child: Text('Verification loading for ${application.shipName}'),
      ),
    );
  }
}