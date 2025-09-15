import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../localization/app_localizations.dart';
import '../../../localization/app_strings.dart';
import '../../../services/logging_service.dart';
import '../../../config/theme.dart';
import '../../../services/auth_service.dart';
import '../../../services/user_service.dart';
import '../../widgets/custom_app_bar.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userService = UserService();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();

  bool _isLoading = false;
  String? _currentProfileImageUrl;

  String _tr(String key) => AppLocalizations.of(context).get('editOfficerProfile.$key');

  @override
  void initState() {
    super.initState();
    LoggingService().info('EditProfileScreen initialized for officer');
    _loadCurrentUserData();
  }

  Future<void> _loadCurrentUserData() async {
    setState(() => _isLoading = true);
    try {
      final currentUser = await _userService.getCurrentUserAccount();
      if (currentUser != null) {
        _nameController.text = currentUser.name;
        _emailController.text = currentUser.email;
        _currentProfileImageUrl = currentUser.profileImageUrl;
      }
    } catch (e) {
      LoggingService().error('Error loading current user data: $e', e);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      bool hasPermission = false;
      if (source == ImageSource.camera) {
        final cameraStatus = await Permission.camera.request();
        hasPermission = cameraStatus.isGranted;
        if (cameraStatus.isPermanentlyDenied && mounted) {
          _showPermissionDialog('camera_permission_message');
          return;
        }
      } else {
        final storageStatus = await Permission.photos.request();
        hasPermission = storageStatus.isGranted;
        if (storageStatus.isPermanentlyDenied && mounted) {
          _showPermissionDialog('storage_permission_message');
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
          SnackBar(content: Text('${_tr('failed_to_pick_image')}: $e')),
        );
      }
    }
  }

  void _showPermissionDialog(String messageKey) {
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
              _tr('permission_required'),
              style: TextStyle(
                fontSize: screenWidth * 0.045,
                fontWeight: FontWeight.bold,
                color: AppTheme.onSurface,
              ),
            ),
            content: Text(
              _tr(messageKey),
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
              _tr('pick_image_source'),
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
                  await _pickImage(ImageSource.camera);
                },
                child: Text(
                  _tr('camera'),
                  style: TextStyle(
                    color: AppTheme.primaryColor,
                    fontSize: screenWidth * 0.04,
                  ),
                ),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await _pickImage(ImageSource.gallery);
                },
                child: Text(
                  _tr('gallery'),
                  style: TextStyle(
                    color: AppTheme.primaryColor,
                    fontSize: screenWidth * 0.04,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  _tr('cancel'),
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

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final originalEmail = _emailController.text.trim();
      final newEmail = _emailController.text.trim();
      final emailChanged = originalEmail != newEmail;

      final updatedUser = await _userService.updateUserProfile(
        _nameController.text.trim(),
        newEmail,
        imagePath: UserService.currentProfileImagePath,
      );

      if (updatedUser != null && mounted) {
        UserService.currentProfileImagePath = null;

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
                  _tr('email_changed_title'),
                  style: TextStyle(
                    fontSize: screenWidth * 0.045,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.onSurface,
                  ),
                ),
                content: Text(
                  _tr('email_changed_body'),
                  style: TextStyle(
                    fontSize: screenWidth * 0.04,
                    color: AppTheme.onSurface.withAlpha(179),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () async {
                      await AuthService().signOut();
                      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                    },
                    child: Text(
                      _tr('ok'),
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
          setState(() {
            _currentProfileImageUrl = updatedUser.profileImageUrl;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_tr('profile_updated')),
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
            content: Text(_tr('error')),
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
    final horizontalPadding = screenWidth * 0.06;
    final verticalPadding = screenWidth * 0.04;
    final avatarRadius = screenWidth > 600 ? 80.0 : 60.0;
    final iconSize = screenWidth > 600 ? 24.0 : 20.0;
    final buttonPadding = screenWidth > 600 ? 20.0 : 16.0;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: CustomAppBar(
        titleText: AppLocalizations.of(context).get('editOfficerProfile.title'),
        backgroundColor: AppTheme.whiteColor,
        foregroundColor: AppTheme.blackColor,
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
            tooltip: _tr('save_changes'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
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
                                : (_currentProfileImageUrl != null
                                    ? NetworkImage(_currentProfileImageUrl!)
                                    : null),
                            child: (UserService.currentProfileImagePath == null && _currentProfileImageUrl == null)
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
                        _tr('change_profile_photo'),
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
                      _tr('full_name'),
                      _nameController,
                      validator: (value) =>
                          value?.isEmpty ?? true ? _tr('full_name_empty') : null,
                    ),

                    _buildTextField(
                      _tr('email_address'),
                      _emailController,
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value?.isEmpty ?? true) return _tr('email_empty');
                        final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                        if (!emailRegex.hasMatch(value!)) return _tr('email_invalid');
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
                                    _tr('saving'),
                                    style: TextStyle(
                                      fontSize: AppTheme.responsiveFontSize(context, mobile: AppTheme.fontSizeButton, tablet: AppTheme.fontSizeBody1, desktop: AppTheme.fontSizeBody1),
                                      fontFamily: 'Poppins',
                                    ),
                                  ),
                                ],
                              )
                            : Text(
                                _tr('save_changes'),
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
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bottomPadding = screenWidth > 600 ? AppTheme.spacing24 : AppTheme.spacing16;

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

  @override
  void dispose() {
    LoggingService().debug('Disposing EditProfileScreen resources');
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }
}