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
import '../../../localization/app_strings.dart';
import '../../../localization/app_localizations.dart';

class EditAgentProfileScreen extends StatefulWidget {
  final String username;
  final String currentName;
  final String currentEmail;
  final String? currentProfileImageUrl;

  const EditAgentProfileScreen({
    super.key,
    required this.username,
    required this.currentName,
    required this.currentEmail,
    this.currentProfileImageUrl,
  });

  @override
  State<EditAgentProfileScreen> createState() => _EditAgentProfileScreenState();
}

class _EditAgentProfileScreenState extends State<EditAgentProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userService = UserService();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();

  bool _isLoading = false;

  String _tr(BuildContext context, String key) {
    return AppLocalizations.of(context).get('editAgentProfile.$key');
  }

  @override
  void initState() {
    super.initState();
    LoggingService().info('EditAgentProfileScreen initialized for user: ${widget.username}');
    _nameController.text = widget.currentName;
    _emailController.text = widget.currentEmail;
  }

  @override
  void dispose() {
    LoggingService().debug('Disposing EditAgentProfileScreen');
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      // Request permissions first
      bool hasPermission = false;
      if (source == ImageSource.camera) {
        final cameraStatus = await Permission.camera.request();
        hasPermission = cameraStatus.isGranted;
        if (cameraStatus.isPermanentlyDenied && mounted) {
          final screenWidth = MediaQuery.of(context).size.width;
          final isTablet = screenWidth > 600;
          final maxWidth = isTablet ? 400.0 : double.infinity;

          showDialog(
            context: context,
            builder: (BuildContext context) {
              return Container(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: Text(
                    _tr(context, 'permission_required'),
                    style: TextStyle(
                      fontSize: screenWidth * 0.045,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.onSurface,
                    ),
                  ),
                  content: Text(
                    _tr(context, 'camera_permission_message'),
                    style: TextStyle(
                      fontSize: screenWidth * 0.04,
                      color: AppTheme.onSurface.withAlpha(179), // 0.7 * 255
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        _tr(context,'cancel'),
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
                        _tr(context,'open_settings'),
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
          return;
        }
      } else {
        final storageStatus = await Permission.photos.request();
        hasPermission = storageStatus.isGranted;
        if (storageStatus.isPermanentlyDenied && mounted) {
          final screenWidth = MediaQuery.of(context).size.width;
          final isTablet = screenWidth > 600;
          final maxWidth = isTablet ? 400.0 : double.infinity;

          showDialog(
            context: context,
            builder: (BuildContext context) {
              return Container(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: Text(
                    _tr(context,'permission_required'),
                    style: TextStyle(
                      fontSize: screenWidth * 0.045,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.onSurface,
                    ),
                  ),
                  content: Text(
                    _tr(context,'storage_permission_message'),
                    style: TextStyle(
                      fontSize: screenWidth * 0.04,
                      color: AppTheme.onSurface.withAlpha(179), // 0.7 * 255
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        _tr(context,'cancel'),
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
                        _tr(context,'open_settings'),
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
          return;
        }
      }

      if (!hasPermission) return;

      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: source);

      if (pickedFile != null) {
        UserService.currentProfileImagePath = pickedFile.path;
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(
              _tr(context,'select_image_source'),
              style: TextStyle(
                fontSize: screenWidth * 0.045,
                fontWeight: FontWeight.bold,
                color: AppTheme.onSurface,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  final hasPermission = await _requestPermission(ImageSource.camera);
                  if (hasPermission) {
                    _pickImage(ImageSource.camera);
                  }
                },
                child: Text(
                  _tr(context,'camera'),
                  style: TextStyle(
                    color: AppTheme.primaryColor,
                    fontSize: screenWidth * 0.04,
                  ),
                ),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  final hasPermission = await _requestPermission(ImageSource.gallery);
                  if (hasPermission) {
                    _pickImage(ImageSource.gallery);
                  }
                },
                child: Text(
                  _tr(context,'gallery'),
                  style: TextStyle(
                    color: AppTheme.primaryColor,
                    fontSize: screenWidth * 0.04,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  _tr(context,'cancel'),
                  style: TextStyle(
                    color: AppTheme.greyColor,
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
      return status.isGranted;
    } else {
      final status = await Permission.photos.request();
      return status.isGranted;
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final originalEmail = widget.currentEmail;
      final newEmail = _emailController.text.trim();
      final emailChanged = originalEmail != newEmail;

      final updatedUser = await _userService.updateUserProfile(
        _nameController.text.trim(),
        newEmail,
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: Text(
                  _tr(context,'email_changed_title'),
                  style: TextStyle(
                    fontSize: screenWidth * 0.045,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.onSurface,
                  ),
                ),
                content: Text(
                  _tr(context,'email_changed_body'),
                  style: TextStyle(
                    fontSize: screenWidth * 0.04,
                    color: AppTheme.onSurface.withAlpha(179), // 0.7 * 255
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () async {
                      await AuthService().signOut();
                      Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
                    },
                    child: Text(
                      _tr(context,'ok'),
                      style: TextStyle(
                        color: AppTheme.primaryColor,
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
              content: Text(_tr(context,'success')),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop(updatedUser);
        }
      } else {
        throw Exception('Update failed');
      }
    } catch (e) {
      LoggingService().error('Error updating profile: $e', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_tr(context,'error')),
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
    final avatarRadius = screenWidth > 600 ? 80.0 : 60.0; // Larger avatar on tablets
    final iconSize = screenWidth > 600 ? 24.0 : 20.0; // Larger icons on tablets
    final buttonPadding = screenWidth > 600 ? 20.0 : 16.0; // Larger button padding on tablets

    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          _tr(context,'title'),
          style: TextStyle(
            fontSize: AppTheme.responsiveFontSize(context, mobile: AppTheme.fontSizeH6, tablet: AppTheme.fontSizeH5, desktop: AppTheme.fontSizeH4),
            fontWeight: FontWeight.w600,
            fontFamily: 'Poppins',
          ),
        ),
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
                : Icon(
                    Icons.save,
                    color: Colors.blue,
                    size: iconSize,
                  ),
            tooltip: _tr(context,'save_changes'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: verticalPadding),
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
                      backgroundImage: UserService.currentProfileImagePath != null
                          ? FileImage(File(UserService.currentProfileImagePath!))
                          : (widget.currentProfileImageUrl != null
                              ? NetworkImage(widget.currentProfileImageUrl!)
                              : null),
                      child: (UserService.currentProfileImagePath == null && widget.currentProfileImageUrl == null)
                          ? Icon(Icons.person, size: avatarRadius, color: Colors.grey)
                          : null,
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
                  _tr(context,'change_profile_photo'),
                  style: TextStyle(
                    color: Colors.blue,
                    fontSize: AppTheme.responsiveFontSize(context, mobile: AppTheme.fontSizeBody1, tablet: AppTheme.fontSizeH6, desktop: AppTheme.fontSizeH6),
                    fontFamily: 'Poppins',
                  ),
                ),
              ),

              SizedBox(height: verticalPadding * 2),

              // Form Fields
              _buildTextField(
                _tr(context,'full_name'),
                _nameController,
                validator: (value) =>
                    value?.isEmpty ?? true ? _tr(context,'full_name_empty') : null,
              ),

              _buildTextField(
                _tr(context,'email_address'),
                _emailController,
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value?.isEmpty ?? true) return _tr(context,'email_empty');
                  final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                  if (!emailRegex.hasMatch(value!)) return _tr(context,'email_invalid');
                  return null;
                },
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
                              _tr(context,'saving'),
                              style: TextStyle(
                                fontSize: AppTheme.responsiveFontSize(context, mobile: AppTheme.fontSizeButton, tablet: AppTheme.fontSizeBody1, desktop: AppTheme.fontSizeBody1),
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ],
                        )
                      : Text(
                          _tr(context,'save'),
                          style: TextStyle(
                            fontSize: AppTheme.responsiveFontSize(context, mobile: AppTheme.fontSizeButton, tablet: AppTheme.fontSizeBody1, desktop: AppTheme.fontSizeBody1),
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
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bottomPadding = screenWidth > 600 ? AppTheme.spacing24 : AppTheme.spacing16; // More spacing on tablets

    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            fontSize: AppTheme.responsiveFontSize(context, mobile: AppTheme.fontSizeBody2, tablet: AppTheme.fontSizeBody1, desktop: AppTheme.fontSizeBody1),
            fontFamily: 'Poppins',
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          ),
          filled: true,
          fillColor: AppTheme.greyShade50,
        ),
        style: TextStyle(
          fontSize: AppTheme.responsiveFontSize(context, mobile: AppTheme.fontSizeBody1, tablet: AppTheme.fontSizeH6, desktop: AppTheme.fontSizeH6),
          fontFamily: 'Poppins',
        ),
        validator: validator,
      ),
    );
  }
}