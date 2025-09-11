import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:m_clearance_imigrasi/app/config/routes.dart';
import 'package:m_clearance_imigrasi/app/services/auth_service.dart';
import 'package:m_clearance_imigrasi/app/utils/image_utils.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

class UploadDocumentsScreen extends StatefulWidget {
  final String initialLanguage;
  const UploadDocumentsScreen({super.key, this.initialLanguage = 'EN'});

  @override
  State<UploadDocumentsScreen> createState() => _UploadDocumentsScreenState();
}

class _UploadDocumentsScreenState extends State<UploadDocumentsScreen> {
  final AuthService _authService = AuthService();
  final ImagePicker _picker = ImagePicker();

  // Selected files
  Uint8List? _nibFile;
  Uint8List? _ktpFile;
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
    print('DEBUG: upload_documents_screen: _checkPreconditions called, navigateOnFail = $navigateOnFail');
    try {
      await _authService.ensureCanUploadDocuments();
      if (mounted) {
        setState(() {
          _canUpload = true;
        });
      }
    } on StateError catch (e) {
      print('DEBUG: upload_documents_screen: _checkPreconditions failed with: ${e.message}');
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
    print('DEBUG: upload_documents_screen: _routeForErrorMessage: $message');
    if (!mounted) return;
    if (message.contains('Email is not verified')) {
      final email = FirebaseAuth.instance.currentUser?.email ?? '';
      print('DEBUG: upload_documents_screen: navigating to confirmation');
      Navigator.pushReplacementNamed(context, AppRoutes.confirmation,
          arguments: {'initialLanguage': _selectedLanguage, 'userData': {'email': email}});
    } else if (message.contains('No authenticated user') ||
        message.contains('User data not found')) {
      print('DEBUG: upload_documents_screen: navigating to login');
      Navigator.pushReplacementNamed(context, AppRoutes.login);
    } else if (message.contains('Current status')) {
      // Parse the status from the message
      final statusMatch = RegExp(r'Current status: (\w+)').firstMatch(message);
      final status = statusMatch?.group(1);
      print('DEBUG: upload_documents_screen: parsed status = $status');
      if (status == 'pending_approval') {
        print('DEBUG: upload_documents_screen: navigating to registrationPending');
        Navigator.pushReplacementNamed(context, AppRoutes.registrationPending,
            arguments: {'initialLanguage': _selectedLanguage});
      } else if (status == 'approved') {
        print('DEBUG: upload_documents_screen: navigating to userHome');
        Navigator.pushReplacementNamed(context, AppRoutes.userHome);
      } else {
        // For other statuses like pending_documents or unknown, navigate to login or handle gracefully
        print('DEBUG: upload_documents_screen: unknown status, navigating to login');
        Navigator.pushReplacementNamed(context, AppRoutes.login);
      }
    } else {
      // Handle unexpected errors gracefully
      print('DEBUG: upload_documents_screen: unexpected error, navigating to login');
      Navigator.pushReplacementNamed(context, AppRoutes.login);
    }
  }

  Future<void> _pickNibFile() async {
    _showSourceActionSheet('NIB', (sourceType) => _handleNibFile(sourceType));
  }

  Future<void> _handleNibFile(String sourceType) async {
    try {
      if (sourceType == 'camera' || sourceType == 'gallery') {
        final source = sourceType == 'camera' ? ImageSource.camera : ImageSource.gallery;
        final hasPermission = await _requestPermissions(source);
        if (!hasPermission) return;

        final XFile? pickedFile = await _picker.pickImage(source: source);
        if (pickedFile != null) {
          final minifiedFile = await minifyImage(File(pickedFile.path));
          final bytes = await minifiedFile.readAsBytes();
          final name = pickedFile.name.isNotEmpty ? pickedFile.name : 'nib.jpg';
          setState(() {
            _nibFile = bytes;
            _nibFileName = name;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('NIB ${_tr('upload_success')}'), backgroundColor: Colors.green),
            );
          }
        }
      } else {
        // File picker
        final result = await FilePicker.platform.pickFiles(
          allowMultiple: false,
          type: FileType.custom,
          allowedExtensions: const ['pdf'],
          withData: true,
        );
        if (result == null || result.files.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(_tr('select_file_failed')), backgroundColor: Colors.red),
            );
          }
          return;
        }

        final picked = result.files.single;
        if (picked.bytes == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(_tr('select_file_failed')), backgroundColor: Colors.red),
            );
          }
          return;
        }

        final name = picked.name.isNotEmpty ? picked.name : 'nib.pdf';
        setState(() {
          _nibFile = picked.bytes;
          _nibFileName = name;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('NIB ${_tr('upload_success')}'), backgroundColor: Colors.green),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_tr('select_file_failed')), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _pickKtpFile() async {
    _showSourceActionSheet('KTP', (sourceType) => _handleKtpFile(sourceType));
  }

  Future<void> _handleKtpFile(String sourceType) async {
    try {
      if (sourceType == 'camera' || sourceType == 'gallery') {
        final source = sourceType == 'camera' ? ImageSource.camera : ImageSource.gallery;
        final hasPermission = await _requestPermissions(source);
        if (!hasPermission) return;

        final XFile? pickedFile = await _picker.pickImage(source: source);
        if (pickedFile != null) {
          final minifiedFile = await minifyImage(File(pickedFile.path));
          final bytes = await minifiedFile.readAsBytes();
          final name = pickedFile.name.isNotEmpty ? pickedFile.name : 'ktp.jpg';
          setState(() {
            _ktpFile = bytes;
            _ktpFileName = name;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('KTP ${_tr('upload_success')}'), backgroundColor: Colors.green),
            );
          }
        }
      } else {
        // File picker
        final result = await FilePicker.platform.pickFiles(
          allowMultiple: false,
          type: FileType.custom,
          allowedExtensions: const ['jpg', 'jpeg', 'pdf'],
          withData: true,
        );
        if (result == null || result.files.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(_tr('select_file_failed')), backgroundColor: Colors.red),
            );
          }
          return;
        }

        final picked = result.files.single;
        if (picked.bytes == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(_tr('select_file_failed')), backgroundColor: Colors.red),
            );
          }
          return;
        }

        var name = picked.name.isNotEmpty ? picked.name : 'ktp.jpg';
        setState(() {
          _ktpFile = picked.bytes;
          _ktpFileName = name;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('KTP ${_tr('upload_success')}'), backgroundColor: Colors.green),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_tr('select_file_failed')), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<bool> _requestPermissions(ImageSource source) async {
    if (source == ImageSource.camera) {
      final cameraStatus = await Permission.camera.request();
      if (cameraStatus.isGranted) {
        return true;
      } else if (cameraStatus.isPermanentlyDenied) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Text('Permission Required'),
                content: Text('Camera permission is required to take photos. Please enable it in app settings.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      openAppSettings();
                    },
                    child: Text('Open Settings'),
                  ),
                ],
              );
            },
          );
        }
        return false;
      } else {
        return false;
      }
    } else {
      // For gallery, request storage permissions
      final storageStatus = await Permission.photos.request();
      if (storageStatus.isGranted) {
        return true;
      } else if (storageStatus.isPermanentlyDenied) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Text('Permission Required'),
                content: Text('Storage permission is required to access photos. Please enable it in app settings.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      openAppSettings();
                    },
                    child: Text('Open Settings'),
                  ),
                ],
              );
            },
          );
        }
        return false;
      } else {
        return false;
      }
    }
  }

  void _showSourceActionSheet(String docType, Function(String) onSourceSelected) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext bc) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: Text('Gallery'),
                onTap: () {
                  Navigator.of(context).pop();
                  onSourceSelected('gallery');
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: Text('Camera'),
                onTap: () {
                  Navigator.of(context).pop();
                  onSourceSelected('camera');
                },
              ),
              ListTile(
                leading: const Icon(Icons.file_present),
                title: Text('Choose from Files'),
                onTap: () {
                  Navigator.of(context).pop();
                  onSourceSelected('file');
                },
              ),
            ],
          ),
        );
      },
    );
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
      if (mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.login);
      }
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
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(_tr('partial_upload_success')), backgroundColor: Colors.orange),
            );
          }
        }
        setState(() {
          _isMarking = true;
        });
        // Mark completion and move to pending_approval (idempotent)
        final _ = await _authService.markDocumentsUploaded(
          storagePathsOrRefs: uploadedPaths,
        );

        if (!mounted) {
          return;
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }
          Navigator.pushReplacementNamed(context, AppRoutes.registrationPending,
              arguments: {'initialLanguage': _selectedLanguage});
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_tr('no_docs_uploaded'))),
          );
        }
      }
    } on StateError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
      _routeForErrorMessage(e.message);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_tr('failed_upload'))),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _isMarking = false;
        });
      }
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
                    fileName,
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
