import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../../../config/theme.dart';
import '../../../services/user_service.dart';
import '../../../services/auth_service.dart';
import '../../../services/logging_service.dart';
import '../../../config/routes.dart';
import '../../../providers/language_provider.dart';
import '../../../localization/app_localizations.dart';

class EditAgentProfileScreen extends StatefulWidget {
  final String username;
  final String currentCorporateName;
  final String currentFullName;
  final String currentEmail;
  final String? currentProfileImageUrl;

  const EditAgentProfileScreen({
    super.key,
    required this.username,
    required this.currentCorporateName,
    required this.currentFullName,
    required this.currentEmail,
    this.currentProfileImageUrl,
  });

  @override
  State<EditAgentProfileScreen> createState() => _EditAgentProfileScreenState();
}

class _EditAgentProfileScreenState extends State<EditAgentProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userService = UserService();
  final _corporateNameController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();

  bool _isLoading = false;

  String _tr(BuildContext context, String key) {
    return AppLocalizations.of(context).get('editAgentProfile.$key');
  }

  @override
  void initState() {
    super.initState();
    LoggingService().info(
      'EditAgentProfileScreen initialized for user: ${widget.username}',
    );
    _corporateNameController.text = widget.currentCorporateName;
    _fullNameController.text = widget.currentFullName;
    _emailController.text = widget.currentEmail;
  }

  @override
  void dispose() {
    LoggingService().debug('Disposing EditAgentProfileScreen');
    _corporateNameController.dispose();
    _fullNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: source);

      if (pickedFile != null) {
        UserService.currentProfileImagePath = pickedFile.path;
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to pick image: $e')));
      }
    }
  }

  void _showImageSourceDialog() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final maxWidth = isTablet ? 400.0 : double.infinity;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Container(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              _tr(context, 'select_image_source'),
              style: TextStyle(
                fontSize: screenWidth * 0.045,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  final hasPermission = await _requestPermission(
                    ImageSource.camera,
                  );
                  if (hasPermission) {
                    _pickImage(ImageSource.camera);
                  }
                },
                child: Text(
                  _tr(context, 'camera'),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: screenWidth * 0.04,
                  ),
                ),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  final hasPermission = await _requestPermission(
                    ImageSource.gallery,
                  );
                  if (hasPermission) {
                    _pickImage(ImageSource.gallery);
                  }
                },
                child: Text(
                  _tr(context, 'gallery'),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: screenWidth * 0.04,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  _tr(context, 'cancel'),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: screenWidth * 0.04,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<bool> _requestPermission(ImageSource source) async {
    if (source == ImageSource.camera) {
      final status = await Permission.camera.request();
      if (status.isGranted) {
        return true;
      }
      if (status.isPermanentlyDenied && mounted) {
        _showPermissionDialog(_tr(context, 'camera_permission_message'));
      }
      return false;
    }

    final granted = await _requestGalleryPermission();
    if (!granted && mounted) {
      _showPermissionDialog(_tr(context, 'storage_permission_message'));
    }
    return granted;
  }

  Future<bool> _requestGalleryPermission() async {
    PermissionStatus status;
    if (Platform.isAndroid) {
      status = await Permission.photos.request();
      if (status.isDenied || status.isRestricted) {
        status = await Permission.storage.request();
      }
    } else {
      status = await Permission.photos.request();
    }

    if (status.isGranted) {
      return true;
    }

    if (status.isPermanentlyDenied && mounted) {
      _showPermissionDialog(_tr(context, 'storage_permission_message'));
    }

    return false;
  }

  void _showPermissionDialog(String message) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final maxWidth = isTablet ? 400.0 : double.infinity;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Container(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              _tr(context, 'permission_required'),
              style: TextStyle(
                fontSize: screenWidth * 0.045,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            content: Text(
              message,
              style: TextStyle(
                fontSize: screenWidth * 0.04,
                color: Theme.of(context).colorScheme.onSurface.withAlpha(179),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  _tr(context, 'cancel'),
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
                  _tr(context, 'open_settings'),
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

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final originalEmail = widget.currentEmail;
      final newEmail = _emailController.text.trim();
      final emailChanged = originalEmail != newEmail;

      final corporateName = _corporateNameController.text.trim();
      final fullName = _fullNameController.text.trim().isNotEmpty
          ? _fullNameController.text.trim()
          : corporateName;
      final updatedUser = await _userService.updateUserProfile(
        corporateName: corporateName,
        fullName: fullName,
        email: newEmail,
        imagePath: UserService.currentProfileImagePath,
      );

      if (updatedUser != null && mounted) {
        UserService.currentProfileImagePath = null; // Clear static path

        if (emailChanged) {
          final screenWidth = MediaQuery.of(context).size.width;
          final isTablet = screenWidth > 600;
          final maxWidth = isTablet ? 400.0 : double.infinity;

          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => Container(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: Text(
                  _tr(context, 'email_changed_title'),
                  style: TextStyle(
                    fontSize: screenWidth * 0.045,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                content: Text(
                  _tr(context, 'email_changed_body'),
                  style: TextStyle(
                    fontSize: screenWidth * 0.04,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withAlpha(179), // 0.7 * 255
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () async {
                      await AuthService().signOut();
                      Navigator.of(context).pushNamedAndRemoveUntil(
                        AppRoutes.login,
                        (route) => false,
                      );
                    },
                    child: Text(
                      _tr(context, 'ok'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: screenWidth * 0.04,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_tr(context, 'success')),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop(true);
        }
      } else {
        throw Exception('Update failed');
      }
    } catch (e) {
      LoggingService().error('Error updating profile: $e', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_tr(context, 'error')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = screenWidth * 0.06; // 6% of screen width
    final verticalPadding = screenWidth * 0.04; // 4% of screen width
    final avatarRadius = screenWidth > 600
        ? 80.0
        : 60.0; // Larger avatar on tablets
    final iconSize = screenWidth > 600 ? 24.0 : 20.0; // Larger icons on tablets
    final buttonPadding = screenWidth > 600
        ? 20.0
        : 16.0; // Larger button padding on tablets

    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            title: Text(
              _tr(context, 'title'),
              style: TextStyle(
                fontSize: AppTheme.responsiveFontSize(
                  context,
                  mobile: AppTheme.fontSizeH6,
                  tablet: AppTheme.fontSizeH5,
                  desktop: AppTheme.fontSizeH4,
                ),
                fontWeight: FontWeight.w600,
                fontFamily: 'Poppins',
              ),
            ),
            centerTitle: true,
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            elevation: 0,
            actions: [
              IconButton(
                onPressed: _isLoading ? null : _saveProfile,
                icon: _isLoading
                    ? SizedBox(
                        width: iconSize,
                        height: iconSize,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.blue,
                        ),
                      )
                    : Icon(Icons.save, color: Colors.blue, size: iconSize),
                tooltip: _tr(context, 'save_changes'),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: verticalPadding,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // Profile Picture Section
                  Center(
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: avatarRadius,
                          backgroundColor: Colors.grey.shade200,
                          child: UserService.currentProfileImagePath != null
                              ? ClipOval(
                                  child: Image.file(
                                    File(UserService.currentProfileImagePath!),
                                    fit: BoxFit.cover,
                                    width: avatarRadius * 2,
                                    height: avatarRadius * 2,
                                  ),
                                )
                              : (widget.currentProfileImageUrl != null
                                    ? ClipOval(
                                        child: Image.network(
                                          widget.currentProfileImageUrl!,
                                          fit: BoxFit.cover,
                                          width: avatarRadius * 2,
                                          height: avatarRadius * 2,
                                          errorBuilder:
                                              (context, error, stackTrace) {
                                                return Icon(
                                                  Icons.person,
                                                  size: avatarRadius,
                                                  color: Colors.grey,
                                                );
                                              },
                                        ),
                                      )
                                    : Icon(
                                        Icons.person,
                                        size: avatarRadius,
                                        color: Colors.grey,
                                      )),
                        ),
                        InkWell(
                          onTap: _showImageSourceDialog,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            padding: EdgeInsets.all(screenWidth > 600 ? 10 : 8),
                            child: Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: iconSize,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: verticalPadding),
                  TextButton(
                    onPressed: _showImageSourceDialog,
                    child: Text(
                      _tr(context, 'change_profile_photo'),
                      style: TextStyle(
                        color: Colors.blue,
                        fontSize: AppTheme.responsiveFontSize(
                          context,
                          mobile: AppTheme.fontSizeBody1,
                          tablet: AppTheme.fontSizeH6,
                          desktop: AppTheme.fontSizeH6,
                        ),
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ),

                  SizedBox(height: verticalPadding * 2),

                  // Form Fields
                  _buildTextField(
                    _tr(context, 'corporate_name'),
                    _corporateNameController,
                    validator: (value) => value?.trim().isNotEmpty ?? false
                        ? null
                        : _tr(context, 'corporate_name_req'),
                    enabled: false,
                    readOnly: true,
                  ),

                  _buildTextField(
                    _tr(context, 'full_name'),
                    _fullNameController,
                    validator: (value) => value?.trim().isNotEmpty ?? false
                        ? null
                        : _tr(context, 'full_name_empty'),
                  ),

                  _buildTextField(
                    _tr(context, 'email_address'),
                    _emailController,
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value?.isEmpty ?? true) {
                        return _tr(context, 'email_empty');
                      }
                      final emailRegex = RegExp(
                        r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                      );
                      if (!emailRegex.hasMatch(value!)) {
                        return _tr(context, 'email_invalid');
                      }
                      return null;
                    },
                    enabled: false,
                    readOnly: true,
                  ),

                  SizedBox(height: verticalPadding * 2),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _saveProfile,
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: buttonPadding),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: iconSize,
                                  height: iconSize,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  _tr(context, 'saving'),
                                  style: TextStyle(
                                    fontSize: AppTheme.responsiveFontSize(
                                      context,
                                      mobile: AppTheme.fontSizeButton,
                                      tablet: AppTheme.fontSizeBody1,
                                      desktop: AppTheme.fontSizeBody1,
                                    ),
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                              ],
                            )
                          : Text(
                              _tr(context, 'save'),
                              style: TextStyle(
                                fontSize: AppTheme.responsiveFontSize(
                                  context,
                                  mobile: AppTheme.fontSizeButton,
                                  tablet: AppTheme.fontSizeBody1,
                                  desktop: AppTheme.fontSizeBody1,
                                ),
                                fontFamily: 'Poppins',
                              ),
                            ),
                    ),
                  ),

                  SizedBox(height: verticalPadding),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    bool enabled = true,
    bool readOnly = false,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bottomPadding = screenWidth > 600
        ? AppTheme.spacing24
        : AppTheme.spacing16; // More spacing on tablets

    final fieldValidator = enabled ? validator : null;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        enabled: enabled,
        readOnly: readOnly || !enabled,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            fontSize: AppTheme.responsiveFontSize(
              context,
              mobile: AppTheme.fontSizeBody2,
              tablet: AppTheme.fontSizeBody1,
              desktop: AppTheme.fontSizeBody1,
            ),
            fontFamily: 'Poppins',
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          ),
          filled: true,
          fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
        style: TextStyle(
          fontSize: AppTheme.responsiveFontSize(
            context,
            mobile: AppTheme.fontSizeBody1,
            tablet: AppTheme.fontSizeH6,
            desktop: AppTheme.fontSizeH6,
          ),
          fontFamily: 'Poppins',
        ),
        validator: fieldValidator,
      ),
    );
  }
}
