import 'package:flutter/material.dart';
import '../../models/user_account.dart';

enum VerificationAction { verified, rejected }

class AccountDetailScreen extends StatelessWidget {
  final UserAccount user;
  final String initialLanguage;
  const AccountDetailScreen({
    super.key, 
    required this.user,
    this.initialLanguage = 'EN'
  });

  void _showDocumentDialog(BuildContext context, String docType, String fileName, String lang) {
    final Map<String, Map<String, String>> translations = {
      'EN': {
        'viewing_doc': 'Viewing Document:',
        'simulation_text': 'This is a simulation of viewing the file:\n',
        'close': 'Close',
      },
      'ID': {
        'viewing_doc': 'Melihat Dokumen:',
        'simulation_text': 'Ini adalah simulasi melihat file:\n',
        'close': 'Tutup',
      }
    };
    String tr(String key) => translations[lang]![key] ?? key;

    showDialog(context: context, builder: (context) => AlertDialog(
      title: Text("${tr('viewing_doc')} $docType"), 
      content: Column(
        mainAxisSize: MainAxisSize.min, 
        children: [
          const Icon(Icons.file_present, size: 60, color: Colors.grey), 
          const SizedBox(height: 16), 
          Text("${tr('simulation_text')}$fileName")
        ]
      ), 
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('close')))
      ]
    ));
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, Map<String, String>> translations = {
      'EN': {
        'user_details': 'User Details',
        'full_name': 'Full Name',
        'username': 'Username',
        'email': 'Email',
        'registration_docs': 'Registration Documents',
        'view_nib': 'View NIB File',
        'view_ktp': 'View KTP File',
        'reject': 'Reject',
        'verify_account': 'Verify Account',
        'rejected_message': 'Account rejected.',
        'verified_message': 'Account successfully verified.',
      },
      'ID': {
        'user_details': 'Detail Pengguna',
        'full_name': 'Nama Lengkap',
        'username': 'Username',
        'email': 'Email',
        'registration_docs': 'Dokumen Registrasi',
        'view_nib': 'Lihat File NIB',
        'view_ktp': 'Lihat File KTP',
        'reject': 'Tolak',
        'verify_account': 'Verifikasi Akun',
        'rejected_message': 'Akun ditolak.',
        'verified_message': 'Akun berhasil diverifikasi.',
      }
    };

    String tr(String key) => translations[initialLanguage]![key] ?? key;

    return Scaffold(
      appBar: AppBar(title: Text(user.name)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('user_details'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Card(child: ListTile(leading: const Icon(Icons.person), title: Text(user.name), subtitle: Text(tr('full_name')))),
            Card(child: ListTile(leading: const Icon(Icons.account_circle), title: Text(user.username), subtitle: Text(tr('username')))),
            Card(child: ListTile(leading: const Icon(Icons.email), title: Text(user.email), subtitle: Text(tr('email')))),
            const Divider(height: 32),
            Text(tr('registration_docs'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(children: [Expanded(child: OutlinedButton.icon(onPressed: () => _showDocumentDialog(context, "NIB", user.nibFileName, initialLanguage), icon: const Icon(Icons.description), label: Text(tr('view_nib')))), const SizedBox(width: 12), Expanded(child: OutlinedButton.icon(onPressed: () => _showDocumentDialog(context, "KTP", user.ktpFileName, initialLanguage), icon: const Icon(Icons.badge), label: Text(tr('view_ktp'))))]),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                ElevatedButton.icon(onPressed: () { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('rejected_message')))); Navigator.pop(context, VerificationAction.rejected); }, icon: const Icon(Icons.close), label: Text(tr('reject')), style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white)),
                ElevatedButton.icon(onPressed: () { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('verified_message')))); Navigator.pop(context, VerificationAction.verified); }, icon: const Icon(Icons.check), label: Text(tr('verify_account')), style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white)),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
