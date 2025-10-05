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
        LoggingService().debug(
          'Auth subscription navigation: context.mounted=$mounted, context.hashCode=${context.hashCode}',
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
      LoggingService().debug(
        '_routeForErrorMessage navigation to confirmation: context.mounted=$mounted, context.hashCode=${context.hashCode}',
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
      LoggingService().debug(
        '_routeForErrorMessage navigation to login (no auth): context.mounted=$mounted, context.hashCode=${context.hashCode}',
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
        LoggingService().debug(
          '_routeForErrorMessage navigation to registrationPending: context.mounted=$mounted, context.hashCode=${context.hashCode}',
        );
        Navigator.pushReplacementNamed(
          context,
          AppRoutes.registrationPending,
          arguments: {'initialLanguage': _selectedLanguage},
        );
      } else if (status == 'approved') {
        LoggingService().info('User status approved, navigating to user home');
        LoggingService().debug(
          '_routeForErrorMessage navigation to userHome: context.mounted=$mounted, context.hashCode=${context.hashCode}',
        );
        Navigator.pushReplacementNamed(context, AppRoutes.userHome);
      } else {
        // For other statuses like pending_documents or unknown, navigate to login or handle gracefully
        LoggingService().warning(
          'Unknown user status: $status, navigating to login',
        );
        LoggingService().debug(
          '_routeForErrorMessage navigation to login (unknown status): context.mounted=$mounted, context.hashCode=${context.hashCode}',
        );
        Navigator.pushReplacementNamed(context, AppRoutes.login);
      }
    } else {
      // Handle unexpected errors gracefully
      LoggingService().error('Unexpected error during routing: $message');
      LoggingService().debug(
        '_routeForErrorMessage navigation to login (unexpected): context.mounted=$mounted, context.hashCode=${context.hashCode}',
      );
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
              allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf'],
              fallbackName: 'nib.jpg',
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
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  content: Text(
                    _tr('camera_permission_message'),
                    style: TextStyle(
                      fontSize: screenWidth * 0.04,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withAlpha(179),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        _tr('cancel'),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
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
                          color: Theme.of(context).colorScheme.primary,
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
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  content: Text(
                    _tr('storage_permission_message'),
                    style: TextStyle(
                      fontSize: screenWidth * 0.04,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withAlpha(179),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        _tr('cancel'),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
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
                          color: Theme.of(context).colorScheme.primary,
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
    LoggingService().debug('Starting camera capture for $fallbackName');
    final hasPermission = await _requestPermissions(ImageSource.camera);
    LoggingService().debug('Camera permission result: $hasPermission');
    if (!hasPermission) {
      LoggingService().warning(
        'Camera permission denied, cannot capture image',
      );
      return null;
    }

    try {
      LoggingService().debug('Calling ImagePicker.pickImage');
      final XFile? pickedFile = await _picker
          .pickImage(
            source: ImageSource.camera,
            imageQuality: 85, // Reduce quality to prevent memory issues
            maxWidth: 1920, // Limit dimensions
            maxHeight: 1080,
          )
          .catchError((error) {
            LoggingService().error('ImagePicker.pickImage failed: $error');
            throw Exception('Camera capture failed: $error');
          });

      LoggingService().debug('ImagePicker result: ${pickedFile?.name}');
      if (pickedFile == null) {
        LoggingService().debug('User cancelled camera capture');
        return null;
      }

      LoggingService().debug('Reading file bytes');
      final bytes = await pickedFile.readAsBytes().catchError((error) {
        LoggingService().error('Failed to read file bytes: $error');
        throw Exception('Failed to read captured image: $error');
      });

      LoggingService().debug('File bytes length: ${bytes.length}');
      if (bytes.isEmpty) {
        LoggingService().error('Captured image has no data');
        throw Exception('Captured image is empty');
      }

      final extension = _extensionFromName(pickedFile.name).isNotEmpty
          ? _extensionFromName(pickedFile.name)
          : _extensionFromName(fallbackName);
      LoggingService().debug('Extension determined: $extension');

      LoggingService().debug('Minifying image data');
      final processedBytes =
          await minifyImageData(bytes, fileExtension: extension).catchError((
            error,
          ) {
            LoggingService().error('Image minification failed: $error');
            // Return original bytes if minification fails
            return bytes;
          });

      LoggingService().debug(
        'Image processed, final size: ${processedBytes.length}',
      );

      final normalizedName = _ensureExtension(
        pickedFile.name.isNotEmpty ? pickedFile.name : fallbackName,
        extension.isNotEmpty ? extension : 'jpg',
      );
      LoggingService().debug('Normalized name: $normalizedName');

      return _DocumentPayload(bytes: processedBytes, name: normalizedName);
    } catch (e, stackTrace) {
      LoggingService().error('Error in _captureImage: $e', e, stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_tr('camera_error')),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
      return null;
    }
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
        backgroundColor: Theme.of(context).colorScheme.primary,
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
        LoggingService().debug(
          '_finishRegistration navigation to login (no user): context.mounted=$mounted, context.hashCode=${context.hashCode}',
        );
        Navigator.pushReplacementNamed(context, AppRoutes.login);
      }
      setState(() {
        _isUploading = false;
      });
      return;
    }

    final uploads = <UploadedDocumentDescriptor>[];
    try {
      // Upload NIB
      final nibUpload = await _authService.uploadDocument(
        user.uid,
        _nibFile!,
        _nibFileName ?? 'nib.pdf',
        docType: 'nib',
      );
      if (nibUpload != null) {
        uploads.add(nibUpload);
      }

      // Upload KTP
      final ktpUpload = await _authService.uploadDocument(
        user.uid,
        _ktpFile!,
        // Ensure a default extension when missing to avoid odd content-type behaviors
        _ktpFileName ?? 'ktp.jpg',
        docType: 'ktp',
      );
      if (ktpUpload != null) {
        uploads.add(ktpUpload);
      }

      if (uploads.isNotEmpty) {
        if (uploads.length < 2) {
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
        await _authService.markDocumentsUploaded(documents: uploads);

        if (!mounted) {
          return;
        }
        LoggingService().debug(
          '_finishRegistration navigation to registrationPending: context.mounted=$mounted, context.hashCode=${context.hashCode}',
        );
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
    LoggingService().debug(
      'UploadDocumentsScreen build: context.hashCode=${context.hashCode}, widget.hashCode=$hashCode, mounted=$mounted',
    );
    final busy = _isUploading || _isMarking;
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding =
        screenWidth * 0.06; // 6% of screen width for responsive padding
    final verticalPadding = AppTheme.spacing24;

    return Scaffold(
      appBar: AppBar(
        title: Text(_tr('title')),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        iconTheme: IconThemeData(
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
      backgroundColor: Theme.of(context).colorScheme.surface,
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
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  SizedBox(height: AppTheme.spacing8),
                  Text(
                    _tr('complete_req'),
                    style: TextStyle(
                      fontSize: AppTheme.fontSizeBody1,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
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
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppTheme.radiusExtraLarge),
        border: Border.all(
          color: Theme.of(context).colorScheme.surfaceContainerLowest,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: cardHeight,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            ),
            child: isUploaded
                ? Icon(
                    Icons.check_circle,
                    color: Theme.of(context).colorScheme.primary,
                    size: screenWidth > 600 ? 50 : 40,
                  )
                : Icon(
                    Icons.image_outlined,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
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
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          SizedBox(height: AppTheme.spacing4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: AppTheme.fontSizeBody2,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontFamily: 'Poppins',
            ),
          ),
          SizedBox(height: AppTheme.spacing16),
          if (isUploaded)
            Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: Theme.of(context).colorScheme.primary,
                  size: 18,
                ),
                SizedBox(width: AppTheme.spacing8),
                Expanded(
                  child: Text(
                    fileName,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
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
