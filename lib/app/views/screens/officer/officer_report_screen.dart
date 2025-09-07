// lib/app/views/screens/officer/officer_report_screen.dart

import 'package:flutter/material.dart';

class OfficerReportScreen extends StatelessWidget {
  final String initialLanguage;

  const OfficerReportScreen({super.key, this.initialLanguage = 'EN'});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Officer Report'),
      ),
      body: const Center(
        child: Text('Officer Report Screen'),
      ),
    );
  }
}