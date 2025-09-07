import 'package:flutter/material.dart';
import '../../../models/clearance_application.dart';

class ClearanceResultScreen extends StatelessWidget {
  final ClearanceApplication application;
  final String initialLanguage;

  const ClearanceResultScreen({
    super.key,
    required this.application,
    this.initialLanguage = 'EN',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Clearance Result'),
      ),
      body: Center(
        child: Text('Clearance result for ${application.shipName}'),
      ),
    );
  }
}