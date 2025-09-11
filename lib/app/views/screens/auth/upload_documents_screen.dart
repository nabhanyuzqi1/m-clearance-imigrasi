import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:m_clearance_imigrasi/app/config/routes.dart';
import 'package:m_clearance_imigrasi/app/config/theme.dart';
import 'package:m_clearance_imigrasi/app/services/auth_service.dart';
import 'package:m_clearance_imigrasi/app/utils/image_utils.dart';
import 'package:m_clearance_imigrasi/app/localization/app_strings.dart';
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

  String _tr(String key) => AppStrings.tr(context: context, screenKey: 'uploadDocuments', stringKey: key, langCode: _selectedLanguage);

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
              SnackBar(content: Text('${_tr('nib')} ${_tr('upload_success')}'), backgroundColor: AppTheme.successColor),
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
              SnackBar(content: Text(_tr('select_file_failed')), backgroundColor: AppTheme.errorColor),
            );
          }
          return;
        }

        final picked = result.files.single;
        if (picked.bytes == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(_tr('select_file_failed')), backgroundColor: AppTheme.errorColor),
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
            SnackBar(content: Text('${_tr('nib')} ${_tr('upload_success')}'), backgroundColor: AppTheme.successColor),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_tr('select_file_failed')), backgroundColor: AppTheme.errorColor),
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
              SnackBar(content: Text('${_tr('ktp')} ${_tr('upload_success')}'), backgroundColor: AppTheme.successColor),
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
              SnackBar(content: Text(_tr('select_file_failed')), backgroundColor: AppTheme.errorColor),
            );
          }
          return;
        }

        final picked = result.files.single;
        if (picked.bytes == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(_tr('select_file_failed')), backgroundColor: AppTheme.errorColor),
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
            SnackBar(content: Text('${_tr('ktp')} ${_tr('upload_success')}'), backgroundColor: AppTheme.successColor),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_tr('select_file_failed')), backgroundColor: AppTheme.errorColor),
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
                title: Text(_tr('permission_required')),
                content: Text(_tr('camera_permission_message')),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(_tr('cancel')),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      openAppSettings();
                    },
                    child: Text(_tr('open_settings')),
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
                title: Text(_tr('permission_required')),
                content: Text(_tr('storage_permission_message')),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(_tr('cancel')),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      openAppSettings();
                    },
                    child: Text(_tr('open_settings')),
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
                title: Text(_tr('gallery')),
                onTap: () {
                  Navigator.of(context).pop();
                  onSourceSelected('gallery');
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: Text(_tr('camera')),
                onTap: () {
                  Navigator.of(context).pop();
                  onSourceSelected('camera');
                },
              ),
              ListTile(
                leading: const Icon(Icons.file_present),
                title: Text(_tr('choose_from_files')),
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
        SnackBar(content: Text(_tr('upload_all_docs')), backgroundColor: AppTheme.errorColor),
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
              SnackBar(content: Text(_tr('partial_upload_success')), backgroundColor: AppTheme.warningColor),
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
        backgroundColor: AppTheme.surfaceColor,
        elevation: 0,
        iconTheme: IconThemeData(color: AppTheme.onSurface),
      ),
      backgroundColor: AppTheme.backgroundColor,
      body: Padding(
        padding: EdgeInsets.all(AppTheme.spacing24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_tr('last_step'),
                style: TextStyle(fontSize: AppTheme.fontSizeH4, fontWeight: FontWeight.bold, fontFamily: 'Poppins', color: AppTheme.onSurface)),
            SizedBox(height: AppTheme.spacing8),
            Text(
              _tr('complete_req'),
              style: TextStyle(fontSize: AppTheme.fontSizeBody1, color: AppTheme.subtitleColor, fontFamily: 'Poppins'),
            ),
            SizedBox(height: AppTheme.spacing32),
            _buildUploadCard(
              title: _tr('nib_title'),
              subtitle: _tr('nib_subtitle'),
              fileName: _nibFileName,
              onTap: busy ? null : _pickNibFile,
            ),
            SizedBox(height: AppTheme.spacing20),
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
                    ? SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.onPrimary),
                      )
                    : Text(_tr('submit')),
              ),
            ),
            SizedBox(height: AppTheme.spacing20),
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
      padding: EdgeInsets.all(AppTheme.spacing16),
      decoration: BoxDecoration(
        color: AppTheme.greyShade50,
        borderRadius: BorderRadius.circular(AppTheme.radiusExtraLarge),
        border: Border.all(color: AppTheme.greyShade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 100,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppTheme.greyShade200,
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            ),
            child: isUploaded
                ? Icon(Icons.check_circle, color: AppTheme.successColor, size: 40)
                : Icon(Icons.image_outlined, color: AppTheme.greyShade600, size: 40),
          ),
          SizedBox(height: AppTheme.spacing16),
          Text(title, style: TextStyle(fontSize: AppTheme.fontSizeH6, fontWeight: FontWeight.bold, fontFamily: 'Poppins', color: AppTheme.onSurface)),
          SizedBox(height: AppTheme.spacing4),
          Text(subtitle, style: TextStyle(fontSize: AppTheme.fontSizeBody2, color: AppTheme.subtitleColor, fontFamily: 'Poppins')),
          SizedBox(height: AppTheme.spacing16),
          if (isUploaded)
            Row(
              children: [
                Icon(Icons.check_circle, color: AppTheme.successColor, size: 18),
                SizedBox(width: AppTheme.spacing8),
                Expanded(
                  child: Text(
                    fileName,
                    style: TextStyle(color: AppTheme.successColor, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(width: AppTheme.spacing8),
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
                  padding: EdgeInsets.symmetric(vertical: AppTheme.spacing12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMedium)),
                ),
                child: Text(_tr('upload')),
              ),
            ),
        ],
      ),
    );
  }
}
