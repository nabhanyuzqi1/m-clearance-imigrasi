import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/user_service.dart';

class EditAgentProfileScreen extends StatefulWidget {
  final String username;
  final String currentName;
  final String currentEmail;
  // PERBAIKAN: Menambahkan parameter initialLanguage untuk mendukung terjemahan.
  final String initialLanguage;

  const EditAgentProfileScreen({
    super.key,
    required this.username,
    required this.currentName,
    required this.currentEmail,
    this.initialLanguage = 'EN', // Default value
  });

  @override
  State<EditAgentProfileScreen> createState() => _EditAgentProfileScreenState();
}

class _EditAgentProfileScreenState extends State<EditAgentProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  final _formKey = GlobalKey<FormState>();
  dynamic _imageFile;
  
  // PERBAIKAN: Menambahkan state untuk bahasa yang dipilih dan map terjemahan.
  late String _selectedLanguage;
  final Map<String, Map<String, String>> _translations = {
    'EN': {
      'title': 'Edit Agent Profile',
      'pick_image_source': 'Select Image Source',
      'gallery': 'Gallery',
      'camera': 'Camera',
      'change_profile_photo': 'Change Profile Photo',
      'full_name': 'Full Name',
      'full_name_empty': 'Name cannot be empty',
      'email_address': 'Email Address',
      'email_empty': 'Email cannot be empty',
      'email_invalid': 'Invalid email format',
      'save_changes': 'Save Changes',
      'profile_updated': 'Profile updated successfully!',
    },
    'ID': {
      'title': 'Ubah Profil Agen',
      'pick_image_source': 'Pilih Sumber Gambar',
      'gallery': 'Galeri',
      'camera': 'Kamera',
      'change_profile_photo': 'Ubah Foto Profil',
      'full_name': 'Nama Lengkap',
      'full_name_empty': 'Nama tidak boleh kosong',
      'email_address': 'Alamat Email',
      'email_empty': 'Email tidak boleh kosong',
      'email_invalid': 'Format email tidak valid',
      'save_changes': 'Simpan Perubahan',
      'profile_updated': 'Profil berhasil diperbarui!',
    }
  };

  String _tr(String key) => _translations[_selectedLanguage]![key] ?? key;


  @override
  void initState() {
    super.initState();
    _selectedLanguage = widget.initialLanguage;
    _nameController = TextEditingController(text: widget.currentName);
    _emailController = TextEditingController(text: widget.currentEmail);
    if (UserService.currentProfileImagePath != null) {
      _imageFile = UserService.currentProfileImagePath;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(_tr("pick_image_source")),
          actions: <Widget>[
            TextButton(
              child: Text(_tr("gallery")),
              onPressed: () => Navigator.pop(context, ImageSource.gallery),
            ),
            TextButton(
              child: Text(_tr("camera")),
              onPressed: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        );
      },
    );

    if (source != null) {
      final XFile? pickedFile = await picker.pickImage(source: source);
      if (pickedFile != null) {
        setState(() {
          _imageFile = pickedFile.path;
        });
      }
    }
  }

  void _saveProfile() {
    if (_formKey.currentState!.validate()) {
      UserService.updateAgentProfile(
        widget.username,
        _nameController.text,
        _emailController.text,
      );
      
      UserService.currentProfileImagePath = _imageFile?.path;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_tr('profile_updated')), backgroundColor: Colors.green),
      );
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_tr('title'))),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            Center(
              child: CircleAvatar(
                radius: 60,
                backgroundColor: Colors.blueGrey,
                backgroundImage: null, // Web doesn't support local file images
                child: _imageFile == null ? const Icon(Icons.person, size: 70, color: Colors.white) : null,
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: OutlinedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.photo_camera),
                label: Text(_tr("change_profile_photo")),
              ),
            ),
            const SizedBox(height: 32),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(labelText: _tr('full_name'), border: const OutlineInputBorder(), prefixIcon: const Icon(Icons.person_outline)),
              validator: (value) { if (value == null || value.isEmpty) { return _tr('full_name_empty'); } return null; },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              decoration: InputDecoration(labelText: _tr('email_address'), border: const OutlineInputBorder(), prefixIcon: const Icon(Icons.email_outlined)),
              keyboardType: TextInputType.emailAddress,
              validator: (value) { if (value == null || value.isEmpty) { return _tr('email_empty'); } if (!value.contains('@') || !value.contains('.')) { return _tr('email_invalid'); } return null; },
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _saveProfile,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              child: Text(_tr('save_changes')),
            ),
          ],
        ),
      ),
    );
  }
}
