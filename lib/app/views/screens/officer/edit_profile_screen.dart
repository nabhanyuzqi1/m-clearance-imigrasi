import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../config/theme.dart';
import '../../../localization/app_localizations.dart';
import '../../../services/auth_service.dart';
import '../../../services/logging_service.dart';
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
  final _corporateNameController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();

  bool _isLoading = false;
  String? _currentProfileImageUrl;
  String _initialEmail = '';

  String _tr(String key) =>
      AppLocalizations.of(context).get('editOfficerProfile.$key');

  @override
  void initState() {
    super.initState();
    LoggingService().info('EditProfileScreen initialized for officer');
    _loadCurrentUserData();
  }

  @override
  void dispose() {
    LoggingService().debug('Disposing EditProfileScreen resources');
    _corporateNameController.dispose();
    _fullNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUserData() async {
    setState(() => _isLoading = true);
    try {
      final currentUser = await _userService.getCurrentUserAccount();
      if (currentUser != null) {
        final corporateName = currentUser.corporateName;
        final fullName = currentUser.fullName;
        _corporateNameController.text = corporateName.isNotEmpty
            ? corporateName
            : fullName;
        _fullNameController.text = fullName;
        _emailController.text = currentUser.email;
        _initialEmail = currentUser.email;
        _currentProfileImageUrl = currentUser.profileImageUrl;
      }
    } catch (e) {
      LoggingService().error('Error loading current user data: $e', e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      bool hasPermission = false;
      if (source == ImageSource.camera) {
        final status = await Permission.camera.request();
        hasPermission = status.isGranted;
        if (status.isPermanentlyDenied && mounted) {
          _showPermissionDialog('camera_permission_message');
          return;
        }
      } else {
        final status = await Permission.photos.request();
        hasPermission = status.isGranted;
        if (status.isPermanentlyDenied && mounted) {
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_tr('failed_to_pick_image')}: $e')),
      );
    }
  }

  void _showPermissionDialog(String messageKey) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final maxWidth = isTablet ? 400.0 : double.infinity;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
              _tr('permission_required'),
              style: TextStyle(
                fontSize: screenWidth * 0.045,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            content: Text(
              _tr(messageKey),
              style: TextStyle(
                fontSize: screenWidth * 0.04,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  _tr('cancel'),
                  style: TextStyle(
                    color: colorScheme.primary,
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
                    color: colorScheme.primary,
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
    final colorScheme = Theme.of(context).colorScheme;

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
              _tr('pick_image_source'),
              style: TextStyle(
                fontSize: screenWidth * 0.045,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
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
                    color: colorScheme.primary,
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
                    color: colorScheme.primary,
                    fontSize: screenWidth * 0.04,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  _tr('cancel'),
                  style: TextStyle(
                    color: colorScheme.primary,
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
      final corporateName = _corporateNameController.text.trim();
      final fullName = _fullNameController.text.trim();
      final newEmail = _emailController.text.trim();
      final emailChanged =
          _initialEmail.trim().toLowerCase() != newEmail.toLowerCase();

      final updatedUser = await _userService.updateUserProfile(
        corporateName: corporateName,
        fullName: fullName,
        email: newEmail,
        imagePath: UserService.currentProfileImagePath,
      );

      if (!mounted) return;

      if (updatedUser != null) {
        UserService.currentProfileImagePath = null;

        if (emailChanged) {
          await _showEmailChangedDialog();
          return;
        }

        setState(() {
          _currentProfileImageUrl = updatedUser.profileImageUrl;
          _initialEmail = updatedUser.email;
          _corporateNameController.text = updatedUser.corporateName;
          _fullNameController.text = updatedUser.fullName;
        });

        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text(_tr('profile_updated')),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true);
      } else {
        throw Exception('Update failed');
      }
    } catch (e) {
      LoggingService().error('Error updating profile: $e', e);
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text(_tr('error')), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showEmailChangedDialog() async {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final maxWidth = isTablet ? 400.0 : double.infinity;
    final colorScheme = Theme.of(context).colorScheme;

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
            _tr('email_changed_title'),
            style: TextStyle(
              fontSize: screenWidth * 0.045,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          content: Text(
            _tr('email_changed_body'),
            style: TextStyle(
              fontSize: screenWidth * 0.04,
              color: colorScheme.onSurface.withAlpha(179),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await AuthService().signOut();
                if (!mounted) return;
                Navigator.of(
                  context,
                ).pushNamedAndRemoveUntil('/login', (route) => false);
              },
              child: Text(
                _tr('ok'),
                style: TextStyle(
                  color: colorScheme.primary,
                  fontSize: screenWidth * 0.04,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
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
    final bottomPadding = screenWidth > 600
        ? AppTheme.spacing24
        : AppTheme.spacing16;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
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
          fillColor: colorScheme.surfaceContainerHighest.withAlpha(
            colorScheme.brightness == Brightness.dark ? 61 : 153,
          ),
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
        validator: validator,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = screenWidth * 0.06;
    final verticalPadding = screenWidth * 0.04;
    final avatarRadius = screenWidth > 600 ? 80.0 : 60.0;
    final iconSize = screenWidth > 600 ? 24.0 : 20.0;
    final buttonPadding = screenWidth > 600 ? 20.0 : 16.0;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: CustomAppBar(
        titleText: AppLocalizations.of(context).get('editOfficerProfile.title'),
        centerTitle: true,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
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
                      color: colorScheme.primary,
                    ),
                  )
                : Icon(Icons.save, color: colorScheme.primary, size: iconSize),
            tooltip: _tr('save_changes'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: verticalPadding,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    Center(
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: avatarRadius,
                            backgroundColor:
                                colorScheme.surfaceContainerHighest,
                            child: UserService.currentProfileImagePath != null
                                ? ClipOval(
                                    child: Image.file(
                                      File(
                                        UserService.currentProfileImagePath!,
                                      ),
                                      fit: BoxFit.cover,
                                      width: avatarRadius * 2,
                                      height: avatarRadius * 2,
                                    ),
                                  )
                                : (_currentProfileImageUrl != null
                                      ? ClipOval(
                                          child: Image.network(
                                            _currentProfileImageUrl!,
                                            fit: BoxFit.cover,
                                            width: avatarRadius * 2,
                                            height: avatarRadius * 2,
                                            errorBuilder:
                                                (context, error, stackTrace) {
                                                  return Icon(
                                                    Icons.person,
                                                    size: avatarRadius,
                                                    color: colorScheme
                                                        .onSurfaceVariant,
                                                  );
                                                },
                                          ),
                                        )
                                      : Icon(
                                          Icons.person,
                                          size: avatarRadius,
                                          color: colorScheme.onSurfaceVariant,
                                        )),
                          ),
                          InkWell(
                            onTap: _showImageSourceDialog,
                            child: Container(
                              decoration: BoxDecoration(
                                color: colorScheme.primary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: colorScheme.surface,
                                  width: 2,
                                ),
                              ),
                              padding: EdgeInsets.all(
                                screenWidth > 600 ? 10 : 8,
                              ),
                              child: Icon(
                                Icons.camera_alt,
                                color: colorScheme.onPrimary,
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
                          color: colorScheme.primary,
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
                    _buildTextField(
                      _tr('corporate_name'),
                      _corporateNameController,
                      validator: (value) => value?.trim().isNotEmpty == true
                          ? null
                          : _tr('corporate_name_empty'),
                    ),
                    _buildTextField(
                      _tr('full_name'),
                      _fullNameController,
                      validator: (value) => value?.trim().isNotEmpty == true
                          ? null
                          : _tr('full_name_empty'),
                    ),
                    _buildTextField(
                      _tr('email_address'),
                      _emailController,
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        final trimmed = value?.trim() ?? '';
                        if (trimmed.isEmpty) {
                          return _tr('email_empty');
                        }
                        final emailRegex = RegExp(
                          r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                        );
                        if (!emailRegex.hasMatch(trimmed)) {
                          return _tr('email_invalid');
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: verticalPadding * 2),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveProfile,
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                            vertical: buttonPadding,
                          ),
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
                                      color: colorScheme.onPrimary,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    _tr('saving'),
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
                                _tr('save_changes'),
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
  }
}
