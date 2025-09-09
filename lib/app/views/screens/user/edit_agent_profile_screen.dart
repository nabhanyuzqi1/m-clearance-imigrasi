import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../localization/app_strings.dart';
import '../../../models/user_account.dart';
import '../../../services/user_service.dart';

class EditAgentProfileScreen extends StatefulWidget {
  final String username;
  final String currentName;
  final String currentEmail;
  final String initialLanguage;

  const EditAgentProfileScreen({
    super.key,
    required this.username,
    required this.currentName,
    required this.currentEmail,
    required this.initialLanguage,
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
  String _selectedLanguage = 'EN';

  final Map<String, Map<String, String>> _translations = {
    'EN': {
      'edit_profile': 'Edit Profile',
      'full_name': 'Full Name',
      'email': 'Email',
      'change_photo': 'Change Photo',
      'save': 'Save',
      'saving': 'Saving...',
      'cancel': 'Cancel',
      'required_field': 'This field is required',
      'invalid_email': 'Please enter a valid email',
      'success': 'Profile updated successfully',
      'error': 'Failed to update profile',
      'camera': 'Camera',
      'gallery': 'Gallery',
      'select_image_source': 'Select Image Source',
    },
    'ID': {
      'edit_profile': 'Edit Profil',
      'full_name': 'Nama Lengkap',
      'email': 'Email',
      'change_photo': 'Ubah Foto',
      'save': 'Simpan',
      'saving': 'Menyimpan...',
      'cancel': 'Batal',
      'required_field': 'Field ini wajib diisi',
      'invalid_email': 'Masukkan email yang valid',
      'success': 'Profil berhasil diperbarui',
      'error': 'Gagal memperbarui profil',
      'camera': 'Kamera',
      'gallery': 'Galeri',
      'select_image_source': 'Pilih Sumber Gambar',
    }
  };

  String _tr(String key) => _translations[_selectedLanguage]![key] ?? key;

  @override
  void initState() {
    super.initState();
    _selectedLanguage = widget.initialLanguage;
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
          title: Text(_tr('select_image_source')),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _pickImage(ImageSource.camera);
              },
              child: Text(_tr('camera')),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _pickImage(ImageSource.gallery);
              },
              child: Text(_tr('gallery')),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(_tr('cancel')),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final success = await _userService.updateUserProfile(
        _nameController.text.trim(),
        _emailController.text.trim(),
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_tr('success')),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true); // Return true to indicate success
      } else {
        throw Exception('Update failed');
      }
    } catch (e) {
      print('Error updating profile: $e');
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(_tr('edit_profile')),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveProfile,
            child: _isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.blue,
                    ),
                  )
                : Text(
                    _tr('save'),
                    style: const TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
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
                          : null,
                      child: UserService.currentProfileImagePath == null
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
                  _tr('change_photo'),
                  style: const TextStyle(color: Colors.blue),
                ),
              ),

              const SizedBox(height: 32),

              // Form Fields
              _buildTextField(
                _tr('full_name'),
                _nameController,
                validator: (value) =>
                    value?.isEmpty ?? true ? _tr('required_field') : null,
              ),

              _buildTextField(
                _tr('email'),
                _emailController,
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value?.isEmpty ?? true) return _tr('required_field');
                  final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                  if (!emailRegex.hasMatch(value!)) return _tr('invalid_email');
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
                            Text(_tr('saving')),
                          ],
                        )
                      : Text(_tr('save')),
                ),
              ),

              const SizedBox(height: 24),
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