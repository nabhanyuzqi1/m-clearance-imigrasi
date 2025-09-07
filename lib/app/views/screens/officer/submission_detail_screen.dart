import 'package:flutter/material.dart';
import '../../../models/clearance_application.dart';

class SubmissionDetailScreen extends StatelessWidget {
  final ClearanceApplication application;
  final String adminName;
  final String initialLanguage;

  const SubmissionDetailScreen({
    super.key,
    required this.application,
    required this.adminName,
    this.initialLanguage = 'EN',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Submission Detail'),
      ),
      body: Center(
        child: Text('Submission detail for ${application.shipName}'),
      ),
    );
  }
}