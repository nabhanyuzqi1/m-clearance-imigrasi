import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:m_clearance_imigrasi/app/config/routes.dart';
import 'package:m_clearance_imigrasi/app/services/auth_service.dart';

class UploadDocumentsScreen extends StatefulWidget {
  final String initialLanguage;
  const UploadDocumentsScreen({super.key, this.initialLanguage = 'EN'});

  @override
  State<UploadDocumentsScreen> createState() => _UploadDocumentsScreenState();
}

class _UploadDocumentsScreenState extends State<UploadDocumentsScreen> {
  final AuthService _authService = AuthService();

  // Selected files
  Object? _nibFile;
  Object? _ktpFile;
  String? _nibFileName;
  String? _ktpFileName;

  // State
  bool _isUploading = false;
  bool _isMarking = false;
  bool _canUpload = false;
  StreamSubscription<User?>? _authSub;
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
      'upload_success': 'uploaded successfully.',
      'upload_all_docs': 'Please upload both documents.',
      'change': 'Change',
      'upload': 'Upload',
      'select_file_failed': 'Failed to select file.',
      'no_docs_uploaded': 'No documents were uploaded.',
      'select_at_least_one': 'Please select at least one document to upload.',
      'failed_upload': 'Failed to upload documents. Please try again.',
      'partial_upload_success': 'Some documents failed to upload, but proceeding with uploaded ones.',
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
      'upload_success': 'berhasil diunggah.',
      'upload_all_docs': 'Mohon unggah kedua dokumen.',
      'change': 'Ganti',
      'upload': 'Unggah',
      'select_file_failed': 'Gagal memilih file.',
      'no_docs_uploaded': 'Tidak ada dokumen yang diunggah.',
      'select_at_least_one': 'Pilih minimal satu dokumen untuk diunggah.',
      'failed_upload': 'Gagal mengunggah dokumen. Coba lagi.',
      'partial_upload_success': 'Beberapa dokumen gagal diunggah, tetapi melanjutkan dengan dokumen yang berhasil.',
    }
  };

  String _tr(String key) => _translations[_selectedLanguage]?[key] ?? key;

  @override
  void initState() {
    super.initState();
    _selectedLanguage = widget.initialLanguage;
    // Navigate to login if user signs out while on this screen
    _authSub = _authService.authStateChanges.listen((user) {
      if (user == null && mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.login);
      }
    });
    // Enforce preconditions on entry
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPreconditions(navigateOnFail: true);
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> _checkPreconditions({bool navigateOnFail = false}) async {
    try {
      await _authService.ensureCanUploadDocuments();
      if (mounted) {
        setState(() {
          _canUpload = true;
        });
      }
    } on StateError catch (e) {
      if (mounted) {
        setState(() {
          _canUpload = false;
        });
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
      if (navigateOnFail) {
        _routeForErrorMessage(e.message);
      }
    } catch (_) {
      // Keep UI responsive on unexpected errors
    }
  }

  void _routeForErrorMessage(String message) {
    if (!mounted) return;
    if (message.contains('Email is not verified')) {
      final email = FirebaseAuth.instance.currentUser?.email ?? '';
      Navigator.pushReplacementNamed(context, AppRoutes.confirmation,
          arguments: {'initialLanguage': _selectedLanguage, 'userData': {'email': email}});
    } else if (message.contains('No authenticated user') ||
        message.contains('User data not found')) {
      Navigator.pushReplacementNamed(context, AppRoutes.login);
    } else if (message.contains('Current status')) {
      Navigator.pushReplacementNamed(context, AppRoutes.registrationPending,
          arguments: {'initialLanguage': _selectedLanguage});
    }
  }

  Future<void> _pickNibFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
        withData: true,
      );
      if (result == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_tr('select_file_failed')), backgroundColor: Colors.red),
        );
        return;
      }

      final picked = result.files.single;
      final name = picked.name.isNotEmpty ? picked.name : 'nib.pdf';

      if (kIsWeb) {
        if (picked.bytes != null) {
          setState(() {
            _nibFile = picked.bytes;
            _nibFileName = name;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('NIB ${_tr('upload_success')}'), backgroundColor: Colors.green),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_tr('select_file_failed')), backgroundColor: Colors.red),
          );
        }
      } else {
        File? file;
        if (picked.path != null) {
          file = File(picked.path!);
        } else if (picked.bytes != null) {
          final tempPath =
              '${Directory.systemTemp.path}/nib-${DateTime.now().millisecondsSinceEpoch}.pdf';
          final tmp = File(tempPath);
          await tmp.writeAsBytes(picked.bytes!, flush: true);
          file = tmp;
        }

        if (file != null) {
          setState(() {
            _nibFile = file;
            _nibFileName = name;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('NIB ${_tr('upload_success')}'), backgroundColor: Colors.green),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_tr('select_file_failed')), backgroundColor: Colors.red),
          );
        }
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_tr('select_file_failed')), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _pickKtpFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'pdf'],
        withData: true,
      );
      if (result == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_tr('select_file_failed')), backgroundColor: Colors.red),
        );
        return;
      }

      final picked = result.files.single;
      var name = picked.name.isNotEmpty ? picked.name : 'ktp.jpg';

      if (kIsWeb) {
        if (picked.bytes != null) {
          setState(() {
            _ktpFile = picked.bytes;
            _ktpFileName = name;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('KTP ${_tr('upload_success')}'), backgroundColor: Colors.green),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_tr('select_file_failed')), backgroundColor: Colors.red),
          );
        }
      } else {
        File? file;
        if (picked.path != null) {
          file = File(picked.path!);
        } else if (picked.bytes != null) {
          // Preserve extension if any, fallback to .jpg
          final ext = name.contains('.') ? name.split('.').last : 'jpg';
          final tempPath =
              '${Directory.systemTemp.path}/ktp-${DateTime.now().millisecondsSinceEpoch}.$ext';
          final tmp = File(tempPath);
          await tmp.writeAsBytes(picked.bytes!, flush: true);
          file = tmp;
        }

        if (file != null) {
          setState(() {
            _ktpFile = file;
            _ktpFileName = name;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('KTP ${_tr('upload_success')}'), backgroundColor: Colors.green),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_tr('select_file_failed')), backgroundColor: Colors.red),
          );
        }
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_tr('select_file_failed')), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _finishRegistration() async {
    if (_nibFile == null || _ktpFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_tr('upload_all_docs')), backgroundColor: Colors.red),
      );
      return;
    }

    // Re-validate preconditions before uploading
    await _checkPreconditions(navigateOnFail: true);
    if (!_canUpload) return;

    setState(() {
      _isUploading = true;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Navigator.pushReplacementNamed(context, AppRoutes.login);
      setState(() {
        _isUploading = false;
      });
      return;
    }

    final List<String> uploadedPaths = [];
    try {
      // Upload NIB
      final nibUrl = await _authService.uploadDocument(
        user.uid,
        _nibFile!,
        _nibFileName ?? 'nib.pdf',
      );
      if (nibUrl != null && nibUrl.isNotEmpty) {
        uploadedPaths.add(nibUrl);
      }

      // Upload KTP
      final ktpUrl = await _authService.uploadDocument(
        user.uid,
        _ktpFile!,
        // Ensure a default extension when missing to avoid odd content-type behaviors
        _ktpFileName ?? 'ktp.jpg',
      );
      if (ktpUrl != null && ktpUrl.isNotEmpty) {
        uploadedPaths.add(ktpUrl);
      }

      if (uploadedPaths.isNotEmpty) {
        if (uploadedPaths.length < 2) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_tr('partial_upload_success')), backgroundColor: Colors.orange),
          );
        }
        setState(() {
          _isMarking = true;
        });
        // Mark completion and move to pending_approval (idempotent)
        final _ = await _authService.markDocumentsUploaded(
          storagePathsOrRefs: uploadedPaths,
        );

        if (!mounted) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          Navigator.pushReplacementNamed(context, AppRoutes.registrationPending,
              arguments: {'initialLanguage': _selectedLanguage});
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_tr('no_docs_uploaded'))),
        );
      }
    } on StateError catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
      _routeForErrorMessage(e.message);
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_tr('failed_upload'))),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isUploading = false;
        _isMarking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = _isUploading || _isMarking;
    return Scaffold(
      appBar: AppBar(
        title: Text(_tr('title')),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_tr('last_step'),
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              _tr('complete_req'),
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 32),
            _buildUploadCard(
              title: _tr('nib_title'),
              subtitle: _tr('nib_subtitle'),
              fileName: _nibFileName,
              onTap: busy ? null : _pickNibFile,
            ),
            const SizedBox(height: 20),
            _buildUploadCard(
              title: _tr('ktp_title'),
              subtitle: _tr('ktp_subtitle'),
              fileName: _ktpFileName,
              onTap: busy ? null : _pickKtpFile,
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: busy ? null : _finishRegistration,
                child: busy
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(_tr('submit')),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadCard({
    required String title,
    required String subtitle,
    String? fileName,
    required VoidCallback? onTap,
  }) {
    final isUploaded = fileName != null;
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 100,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
            child: isUploaded
                ? const Icon(Icons.check_circle, color: Colors.green, size: 40)
                : const Icon(Icons.image_outlined, color: Colors.grey, size: 40),
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
                Expanded(
                  child: Text(
                    fileName!,
                    style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 36,
                  child: OutlinedButton(onPressed: onTap, child: Text(_tr('change'))),
                ),
              ],
            )
          else
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onTap,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(_tr('upload')),
              ),
            ),
        ],
      ),
    );
  }
}
