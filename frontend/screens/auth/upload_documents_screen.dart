import 'package:flutter/material.dart';
import '../../services/user_service.dart';
import 'registration_pending_screen.dart';

class UploadDocumentsScreen extends StatefulWidget {
  final Map<String, String> userData;
  final String initialLanguage;
  const UploadDocumentsScreen({super.key, required this.userData, this.initialLanguage = 'EN'});

  @override
  State<UploadDocumentsScreen> createState() => _UploadDocumentsScreenState();
}

class _UploadDocumentsScreenState extends State<UploadDocumentsScreen> {
  String? _nibFileName;
  String? _ktpFileName;
  late String _selectedLanguage;

  final Map<String, Map<String, String>> _translations = {
    'EN': {
      'title': 'Submission',
      'last_step': 'Last Step',
      'complete_req': 'Complete the Requirements',
      'nib_title': 'Business Identification Number',
      'nib_subtitle': 'Only accept .pdf',
      'ktp_title': 'Identity Card',
      'ktp_subtitle': 'Only accept .jpg .pdf',
      'submit': 'Submit',
      'upload_success': 'uploaded successfully (simulation).',
      'upload_all_docs': 'Please upload both documents.',
      'change': 'Change',
      'upload': 'Upload',
    },
    'ID': {
      'title': 'Pengajuan',
      'last_step': 'Langkah Terakhir',
      'complete_req': 'Lengkapi Persyaratan',
      'nib_title': 'Nomor Induk Berusaha',
      'nib_subtitle': 'Hanya menerima .pdf',
      'ktp_title': 'Kartu Tanda Penduduk',
      'ktp_subtitle': 'Hanya menerima .jpg .pdf',
      'submit': 'Kirim',
      'upload_success': 'berhasil diunggah (simulasi).',
      'upload_all_docs': 'Mohon unggah kedua dokumen.',
      'change': 'Ganti',
      'upload': 'Unggah',
    }
  };

  String _tr(String key) => _translations[_selectedLanguage]![key] ?? key;

  @override
  void initState() {
    super.initState();
    _selectedLanguage = widget.initialLanguage;
  }

  void _pickFile(String docType) {
    setState(() {
      if (docType == 'NIB') {
        _nibFileName = 'dokumen_nib_anda.pdf';
      } else if (docType == 'KTP') {
        _ktpFileName = 'foto_ktp_anda.jpg';
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$docType ${_tr('upload_success')}'), backgroundColor: Colors.green),
    );
  }

  void _finishRegistration() {
    if (_nibFileName != null && _ktpFileName != null) {
      // PERBAIKAN: Mengirimkan nama file yang diunggah ke service
      // agar data pengguna yang disimpan akurat.
      UserService.addAgent(
        name: widget.userData['name']!,
        username: widget.userData['username']!,
        email: widget.userData['email']!,
        password: widget.userData['password']!,
        nibFileName: _nibFileName!,
        ktpFileName: _ktpFileName!,
      );
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => RegistrationPendingScreen(initialLanguage: _selectedLanguage)),
        (route) => route.isFirst,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_tr('upload_all_docs')), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_tr('title')), backgroundColor: Colors.white, elevation: 0, iconTheme: const IconThemeData(color: Colors.black)),
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_tr('last_step'), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(_tr('complete_req'), style: TextStyle(fontSize: 16, color: Colors.grey[600])),
            const SizedBox(height: 32),
            _buildUploadCard(title: _tr('nib_title'), subtitle: _tr('nib_subtitle'), fileName: _nibFileName, onTap: () => _pickFile('NIB')),
            const SizedBox(height: 20),
            _buildUploadCard(title: _tr('ktp_title'), subtitle: _tr('ktp_subtitle'), fileName: _ktpFileName, onTap: () => _pickFile('KTP')),
            const Spacer(),
            SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _finishRegistration, child: Text(_tr('submit')))),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadCard({required String title, required String subtitle, String? fileName, required VoidCallback onTap}) {
    bool isUploaded = fileName != null;
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 100,
            width: double.infinity,
            decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(12)),
            child: isUploaded ? const Icon(Icons.check_circle, color: Colors.green, size: 40) : const Icon(Icons.image_outlined, color: Colors.grey, size: 40),
          ),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
          const SizedBox(height: 16),
          if (isUploaded)
            Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(fileName, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 8),
                SizedBox(height: 36, child: OutlinedButton(onPressed: onTap, child: Text(_tr('change')))),
              ],
            )
          else
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(onPressed: onTap, style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), child: Text(_tr('upload'))),
            ),
        ],
      ),
    );
  }
}

