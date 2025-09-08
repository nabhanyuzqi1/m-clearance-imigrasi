// lib/app/views/screens/user/clearance_form_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../models/clearance_application.dart';
import '../../../repositories/application_repository.dart';

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

    final repo = ApplicationRepository();
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: Center(
        child: Text('Clearance form for $agentName'),
      ),
      floatingActionButton: user == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () async {
                final normalizedType = type == ApplicationType.kedatangan ? 'arrival' : 'departure';
                final appId = await repo.createApplication(
                  agentUid: user.uid,
                  agentName: agentName,
                  type: normalizedType,
                  shipName: 'KM. Bahari Indah',
                  flag: 'ID',
                  location: 'Sampit',
                );
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Application submitted: $appId')));
              },
              icon: const Icon(Icons.send),
              label: const Text('Submit'),
            ),
    );
  }
}
