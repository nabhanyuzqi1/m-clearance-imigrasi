// lib/app/views/screens/user/clearance_form_screen.dart

import 'package:flutter/material.dart';
import '../../../models/clearance_application.dart';

class ClearanceFormScreen extends StatelessWidget {
  final ApplicationType type;
  final String agentName;
  final ClearanceApplication? existingApplication;
  final String initialLanguage;

  const ClearanceFormScreen({
    super.key,
    required this.type,
    required this.agentName,
    this.existingApplication,
    this.initialLanguage = 'EN',
  });

  @override
  Widget build(BuildContext context) {
    // Teks judul akan disesuaikan berdasarkan tipe clearance (Kedatangan/Keberangkatan)
    final title = type == ApplicationType.kedatangan ? 'Arrival Details' : 'Departure Details';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: Center(
        child: Text('Clearance form for $agentName'),
      ),
    );
  }
}