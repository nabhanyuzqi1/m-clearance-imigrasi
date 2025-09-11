import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../../../services/user_service.dart';
import '../../../services/auth_service.dart';
import '../../../config/routes.dart';
import '../../../providers/language_provider.dart';
import '../../../localization/app_strings.dart';

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
    final langCode = Provider.of<LanguageProvider>(context, listen: false).locale.languageCode;
    return AppStrings.tr(
      context: context,
      screenKey: 'editAgentProfile',
      stringKey: key,
      langCode: langCode.toUpperCase(),
    );
  }

  @override
  void initState() {
    super.initState();
    debugPrint('[EditAgentProfileScreen] initState');
    _nameController.text = widget.currentName;
    _emailController.text = widget.currentEmail;
  }

  @override
  void dispose() {
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
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Text(_tr(context, 'permission_required')),
                content: Text(_tr(context, 'camera_permission_message')),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(_tr(context,'cancel')),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      openAppSettings();
                    },
                    child: Text(_tr(context,'open_settings')),
                  ),
                ],
              );
            },
          );
          return;
        }
      } else {
        final storageStatus = await Permission.photos.request();
        hasPermission = storageStatus.isGranted;
        if (storageStatus.isPermanentlyDenied && mounted) {
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Text(_tr(context,'permission_required')),
                content: Text(_tr(context,'storage_permission_message')),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(_tr(context,'cancel')),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      openAppSettings();
                    },
                    child: Text(_tr(context,'open_settings')),
                  ),
                ],
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
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(_tr(context,'select_image_source')),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                final hasPermission = await _requestPermission(ImageSource.camera);
                if (hasPermission) {
                  _pickImage(ImageSource.camera);
                }
              },
              child: Text(_tr(context,'camera')),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                final hasPermission = await _requestPermission(ImageSource.gallery);
                if (hasPermission) {
                  _pickImage(ImageSource.gallery);
                }
              },
              child: Text(_tr(context,'gallery')),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(_tr(context,'cancel')),
            ),
          ],
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

      final success = await _userService.updateUserProfile(
        _nameController.text.trim(),
        newEmail,
        imagePath: UserService.currentProfileImagePath,
      );

      if (success && mounted) {
        UserService.currentProfileImagePath = null; // Clear static path

        if (emailChanged) {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: Text(_tr(context,'email_changed_title')),
              content: Text(_tr(context,'email_changed_body')),
              actions: [
                TextButton(
                  onPressed: () async {
                    await AuthService().signOut();
                    Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
                  },
                  child: Text(_tr(context,'ok')),
                ),
              ],
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_tr(context,'success')),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop(true);
        }
      } else {
        throw Exception('Update failed');
      }
    } catch (e) {
      print('Error updating profile: $e');
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
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(_tr(context,'title')),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _saveProfile,
            icon: _isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.blue,
                    ),
                  )
                : const Icon(
                    Icons.save,
                    color: Colors.blue,
                  ),
            tooltip: _tr(context,'save_changes'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
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
                      radius: 60,
                      backgroundColor: Colors.grey.shade200,
                      backgroundImage: UserService.currentProfileImagePath != null
                          ? FileImage(File(UserService.currentProfileImagePath!))
                          : (widget.currentProfileImageUrl != null
                              ? NetworkImage(widget.currentProfileImageUrl!)
                              : null),
                      child: (UserService.currentProfileImagePath == null && widget.currentProfileImageUrl == null)
                          ? const Icon(Icons.person, size: 60, color: Colors.grey)
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
                        padding: const EdgeInsets.all(8),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _showImageSourceDialog,
                child: Text(
                  _tr(context,'change_profile_photo'),
                  style: const TextStyle(color: Colors.blue),
                ),
              ),

              const SizedBox(height: 32),

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

              const SizedBox(height: 32),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(_tr(context,'saving')),
                          ],
                        )
                      : Text(_tr(context,'save')),
                ),
              ),

              const SizedBox(height: 24),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          fillColor: Colors.grey.shade50,
        ),
        validator: validator,
      ),
    );
  }
}