import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:m_clearance_imigrasi/app/config/routes.dart';
import 'package:m_clearance_imigrasi/app/config/theme.dart';
import 'package:m_clearance_imigrasi/app/services/auth_service.dart';
import '../../../localization/app_localizations.dart';
import 'package:m_clearance_imigrasi/app/services/logging_service.dart';
import 'package:m_clearance_imigrasi/app/utils/image_utils.dart';
import 'package:permission_handler/permission_handler.dart';

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

  String _tr(String key) =>
      AppLocalizations.of(context).get('uploadDocuments.$key');

  @override
  void initState() {
    super.initState();
    LoggingService().info(
      'UploadDocumentsScreen initialized with language: ${widget.initialLanguage}',
    );
    _selectedLanguage = widget.initialLanguage;

    // Navigate to login if user signs out while on this screen
    _authSub = _authService.authStateChanges.listen((user) {
      if (user == null && mounted) {
        LoggingService().info(
          'User signed out, navigating to login from upload documents screen',
        );
        Navigator.pushReplacementNamed(context, AppRoutes.login);
      }
    });

    // Enforce preconditions on entry
    WidgetsBinding.instance.addPostFrameCallback((_) {
      LoggingService().info('Checking preconditions for document upload');
      _checkPreconditions(navigateOnFail: true);
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> _checkPreconditions({bool navigateOnFail = false}) async {
    LoggingService().debug(
      'Checking preconditions for document upload, navigateOnFail: $navigateOnFail',
    );
    try {
      await _authService.ensureCanUploadDocuments();
      if (mounted) {
        setState(() {
          _canUpload = true;
        });
      }
    } on StateError catch (e) {
      LoggingService().error('Precondition check failed: ${e.message}', e);
      if (mounted) {
        setState(() {
          _canUpload = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
      if (navigateOnFail) {
        _routeForErrorMessage(e.message);
      }
    } catch (e) {
      LoggingService().error(
        'Unexpected error during precondition check: $e',
        e,
      );
      // Keep UI responsive on unexpected errors
    }
  }

  void _routeForErrorMessage(String message) {
    LoggingService().debug('Routing based on error message: $message');
    if (!mounted) return;

    if (message.contains('Email is not verified')) {
      final email = FirebaseAuth.instance.currentUser?.email ?? '';
      LoggingService().info(
        'Email not verified, navigating to confirmation screen',
      );
      Navigator.pushReplacementNamed(
        context,
        AppRoutes.confirmation,
        arguments: {
          'initialLanguage': _selectedLanguage,
          'userData': {'email': email},
        },
      );
    } else if (message.contains('No authenticated user') ||
        message.contains('User data not found')) {
      LoggingService().warning(
        'No authenticated user or user data not found, navigating to login',
      );
      Navigator.pushReplacementNamed(context, AppRoutes.login);
    } else if (message.contains('Current status')) {
      // Parse the status from the message
      final statusMatch = RegExp(r'Current status: (\w+)').firstMatch(message);
      final status = statusMatch?.group(1);
      LoggingService().debug('Parsed user status: $status');

      if (status == 'pending_approval') {
        LoggingService().info(
          'User status pending_approval, navigating to registration pending',
        );
        Navigator.pushReplacementNamed(
          context,
          AppRoutes.registrationPending,
          arguments: {'initialLanguage': _selectedLanguage},
        );
      } else if (status == 'approved') {
        LoggingService().info('User status approved, navigating to user home');
        Navigator.pushReplacementNamed(context, AppRoutes.userHome);
      } else {
        // For other statuses like pending_documents or unknown, navigate to login or handle gracefully
        LoggingService().warning(
          'Unknown user status: $status, navigating to login',
        );
        Navigator.pushReplacementNamed(context, AppRoutes.login);
      }
    } else {
      // Handle unexpected errors gracefully
      LoggingService().error('Unexpected error during routing: $message');
      Navigator.pushReplacementNamed(context, AppRoutes.login);
    }
  }

  Future<void> _pickNibFile() async {
    _showSourceActionSheet((sourceType) => _handleNibFile(sourceType));
  }

  Future<void> _pickKtpFile() async {
    _showSourceActionSheet((sourceType) => _handleKtpFile(sourceType));
  }

  Future<void> _handleNibFile(String sourceType) async {
    try {
      final payload = sourceType == 'camera'
          ? await _captureImage(fallbackName: 'nib.jpg')
          : await _pickFromFiles(
              allowedExtensions: const ['pdf'],
              fallbackName: 'nib.pdf',
            );

      if (payload == null) return;

      setState(() {
        _nibFile = payload.bytes;
        _nibFileName = payload.name;
      });

      _showSuccessSnack(_tr('nib'));
    } catch (e) {
      LoggingService().error('Failed to handle NIB file', e);
      _showPickError();
    }
  }

  Future<void> _handleKtpFile(String sourceType) async {
    try {
      final payload = sourceType == 'camera'
          ? await _captureImage(fallbackName: 'ktp.jpg')
          : await _pickFromFiles(
              allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf'],
              fallbackName: 'ktp.jpg',
            );

      if (payload == null) return;

      setState(() {
        _ktpFile = payload.bytes;
        _ktpFileName = payload.name;
      });

      _showSuccessSnack(_tr('ktp'));
    } catch (e) {
      LoggingService().error('Failed to handle KTP file', e);
      _showPickError();
    }
  }

  Future<bool> _requestPermissions(ImageSource source) async {
    if (source == ImageSource.camera) {
      final cameraStatus = await Permission.camera.request();
      if (cameraStatus.isGranted) {
        return true;
      } else if (cameraStatus.isPermanentlyDenied) {
        if (mounted) {
          final screenWidth = MediaQuery.of(context).size.width;
          final isTablet = screenWidth > 600;
          final maxWidth = isTablet ? 400.0 : double.infinity;

          showDialog(
            context: context,
            builder: (BuildContext context) {
              return Container(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: AlertDialog(
                  title: Text(
                    _tr('permission_required'),
                    style: TextStyle(
                      fontSize: screenWidth * 0.045,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.onSurface,
                    ),
                  ),
                  content: Text(
                    _tr('camera_permission_message'),
                    style: TextStyle(
                      fontSize: screenWidth * 0.04,
                      color: AppTheme.onSurface.withAlpha(179),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        _tr('cancel'),
                        style: TextStyle(
                          color: AppTheme.primaryColor,
                          fontSize: screenWidth * 0.04,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        openAppSettings();
                      },
                      child: Text(
                        _tr('open_settings'),
                        style: TextStyle(
                          color: AppTheme.primaryColor,
                          fontSize: screenWidth * 0.04,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
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
          final screenWidth = MediaQuery.of(context).size.width;
          final isTablet = screenWidth > 600;
          final maxWidth = isTablet ? 400.0 : double.infinity;

          showDialog(
            context: context,
            builder: (BuildContext context) {
              return Container(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: AlertDialog(
                  title: Text(
                    _tr('permission_required'),
                    style: TextStyle(
                      fontSize: screenWidth * 0.045,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.onSurface,
                    ),
                  ),
                  content: Text(
                    _tr('storage_permission_message'),
                    style: TextStyle(
                      fontSize: screenWidth * 0.04,
                      color: AppTheme.onSurface.withAlpha(179),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        _tr('cancel'),
                        style: TextStyle(
                          color: AppTheme.primaryColor,
                          fontSize: screenWidth * 0.04,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        openAppSettings();
                      },
                      child: Text(
                        _tr('open_settings'),
                        style: TextStyle(
                          color: AppTheme.primaryColor,
                          fontSize: screenWidth * 0.04,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
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

  Future<_DocumentPayload?> _captureImage({
    required String fallbackName,
  }) async {
    final hasPermission = await _requestPermissions(ImageSource.camera);
    if (!hasPermission) return null;

    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.camera,
    );
    if (pickedFile == null) return null;

    final bytes = await pickedFile.readAsBytes();
    final extension = _extensionFromName(pickedFile.name).isNotEmpty
        ? _extensionFromName(pickedFile.name)
        : _extensionFromName(fallbackName);

    final processedBytes = await minifyImageData(
      bytes,
      fileExtension: extension,
    );

    final normalizedName = _ensureExtension(
      pickedFile.name.isNotEmpty ? pickedFile.name : fallbackName,
      extension.isNotEmpty ? extension : 'jpg',
    );

    return _DocumentPayload(bytes: processedBytes, name: normalizedName);
  }

  Future<_DocumentPayload?> _pickFromFiles({
    required List<String> allowedExtensions,
    required String fallbackName,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      return null;
    }

    final picked = result.files.single;
    final bytes = picked.bytes;
    if (bytes == null) return null;

    final extension = _extensionFromName(picked.name).isNotEmpty
        ? _extensionFromName(picked.name)
        : _extensionFromName(fallbackName);

    final processedBytes = _isImageExtension(extension)
        ? await minifyImageData(bytes, fileExtension: extension)
        : bytes;

    final normalizedName = _ensureExtension(
      picked.name.isNotEmpty ? picked.name : fallbackName,
      extension,
    );

    return _DocumentPayload(bytes: processedBytes, name: normalizedName);
  }

  void _showSuccessSnack(String documentLabel) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$documentLabel ${_tr('upload_success')}'),
        backgroundColor: AppTheme.successColor,
      ),
    );
  }

  void _showPickError() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_tr('select_file_failed')),
        backgroundColor: AppTheme.errorColor,
      ),
    );
  }

  bool _isImageExtension(String extension) {
    final normalized = extension.toLowerCase();
    return ['jpg', 'jpeg', 'png', 'webp', 'heic'].contains(normalized);
  }

  String _extensionFromName(String name) {
    final index = name.lastIndexOf('.');
    if (index == -1 || index == name.length - 1) {
      return '';
    }
    return name.substring(index + 1).toLowerCase();
  }

  String _ensureExtension(String name, String extension) {
    if (extension.isEmpty) return name;
    if (name.toLowerCase().endsWith('.$extension')) {
      return name;
    }
    final index = name.lastIndexOf('.');
    final baseName = index == -1 ? name : name.substring(0, index);
    return '$baseName.$extension';
  }

  void _showSourceActionSheet(Function(String) onSourceSelected) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext bc) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
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
        SnackBar(
          content: Text(_tr('upload_all_docs')),
          backgroundColor: AppTheme.errorColor,
        ),
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
        docType: 'nib',
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
        docType: 'ktp',
      );
      if (ktpUrl != null && ktpUrl.isNotEmpty) {
        uploadedPaths.add(ktpUrl);
      }

      if (uploadedPaths.isNotEmpty) {
        if (uploadedPaths.length < 2) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(_tr('partial_upload_success')),
                backgroundColor: AppTheme.warningColor,
              ),
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
          Navigator.pushReplacementNamed(
            context,
            AppRoutes.registrationPending,
            arguments: {'initialLanguage': _selectedLanguage},
          );
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(_tr('no_docs_uploaded'))));
        }
      }
    } on StateError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
      _routeForErrorMessage(e.message);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_tr('failed_upload'))));
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
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding =
        screenWidth * 0.06; // 6% of screen width for responsive padding
    final verticalPadding = AppTheme.spacing24;

    return Scaffold(
      appBar: AppBar(
        title: Text(_tr('title')),
        backgroundColor: AppTheme.surfaceColor,
        elevation: 0,
        iconTheme: IconThemeData(color: AppTheme.onSurface),
      ),
      backgroundColor: AppTheme.backgroundColor,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: verticalPadding,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _tr('last_step'),
                    style: TextStyle(
                      fontSize: AppTheme.fontSizeH4,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Poppins',
                      color: AppTheme.onSurface,
                    ),
                  ),
                  SizedBox(height: AppTheme.spacing8),
                  Text(
                    _tr('complete_req'),
                    style: TextStyle(
                      fontSize: AppTheme.fontSizeBody1,
                      color: AppTheme.subtitleColor,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  SizedBox(height: AppTheme.spacing32),
                  _buildUploadCard(
                    title: _tr('nib_title'),
                    subtitle: _tr('nib_subtitle'),
                    fileName: _nibFileName,
                    onTap: busy ? null : _pickNibFile,
                    screenWidth: screenWidth,
                  ),
                  SizedBox(height: AppTheme.spacing24),
                  _buildUploadCard(
                    title: _tr('ktp_title'),
                    subtitle: _tr('ktp_subtitle'),
                    fileName: _ktpFileName,
                    onTap: busy ? null : _pickKtpFile,
                    screenWidth: screenWidth,
                  ),
                  SizedBox(height: AppTheme.spacing32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: busy ? null : _finishRegistration,
                      child: busy
                          ? SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                            )
                          : Text(_tr('submit')),
                    ),
                  ),
                  SizedBox(height: AppTheme.spacing20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildUploadCard({
    required String title,
    required String subtitle,
    String? fileName,
    required VoidCallback? onTap,
    required double screenWidth,
  }) {
    final isUploaded = fileName != null;
    final cardHeight = screenWidth > 600
        ? 120.0
        : 100.0; // Responsive height for tablets
    final horizontalPadding =
        screenWidth * 0.04; // Responsive padding for card content

    return Container(
      padding: EdgeInsets.all(horizontalPadding),
      decoration: BoxDecoration(
        color: AppTheme.greyShade50,
        borderRadius: BorderRadius.circular(AppTheme.radiusExtraLarge),
        border: Border.all(color: AppTheme.greyShade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: cardHeight,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppTheme.greyShade200,
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            ),
            child: isUploaded
                ? Icon(
                    Icons.check_circle,
                    color: AppTheme.successColor,
                    size: screenWidth > 600 ? 50 : 40,
                  )
                : Icon(
                    Icons.image_outlined,
                    color: AppTheme.greyShade600,
                    size: screenWidth > 600 ? 50 : 40,
                  ),
          ),
          SizedBox(height: AppTheme.spacing16),
          Text(
            title,
            style: TextStyle(
              fontSize: AppTheme.fontSizeH6,
              fontWeight: FontWeight.bold,
              fontFamily: 'Poppins',
              color: AppTheme.onSurface,
            ),
          ),
          SizedBox(height: AppTheme.spacing4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: AppTheme.fontSizeBody2,
              color: AppTheme.subtitleColor,
              fontFamily: 'Poppins',
            ),
          ),
          SizedBox(height: AppTheme.spacing16),
          if (isUploaded)
            Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: AppTheme.successColor,
                  size: 18,
                ),
                SizedBox(width: AppTheme.spacing8),
                Expanded(
                  child: Text(
                    fileName,
                    style: TextStyle(
                      color: AppTheme.successColor,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Poppins',
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(width: AppTheme.spacing8),
                SizedBox(
                  height: 36,
                  child: OutlinedButton(
                    onPressed: onTap,
                    child: Text(_tr('change')),
                  ),
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                ),
                child: Text(_tr('upload')),
              ),
            ),
        ],
      ),
    );
  }
}

class _DocumentPayload {
  final Uint8List bytes;
  final String name;

  const _DocumentPayload({required this.bytes, required this.name});
}
