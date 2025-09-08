// lib/screens/officer/officer_verification_screen.dart

import 'package:flutter/material.dart';
import '../../models/clearance_application.dart';

class OfficerVerificationScreen extends StatelessWidget {
  final ClearanceApplication application;

  const OfficerVerificationScreen({super.key, required this.application});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(application.shipName)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Verifikasi Permohonan', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Text('Nama Kapal: ${application.shipName}', style: const TextStyle(fontSize: 16)),
            Text('Bendera: ${application.flag}', style: const TextStyle(fontSize: 16)),
            Text('Nama Agen: ${application.agentName}', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 24),
            const Text('Dokumen Terlampir:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const ListTile(leading: Icon(Icons.check_circle, color: Colors.green), title: Text('Port Clearance.pdf')),
            const ListTile(leading: Icon(Icons.check_circle, color: Colors.green), title: Text('Crew List.pdf')),
            const ListTile(leading: Icon(Icons.check_circle, color: Colors.green), title: Text('Surat Pemberitahuan.pdf')),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Permohonan ditolak. Notifikasi dikirim ke pengguna.')),
                    );
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.close),
                  label: const Text('Tolak'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                     ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Permohonan disetujui.')),
                    );
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.check),
                  label: const Text('Setujui'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                ),
              ],
            ),
             const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}