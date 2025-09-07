import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:m_clearance_imigrasi/app/config/routes.dart';
import 'package:m_clearance_imigrasi/app/services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UploadDocumentsScreen extends StatefulWidget {
  const UploadDocumentsScreen({Key? key}) : super(key: key);

  @override
  _UploadDocumentsScreenState createState() => _UploadDocumentsScreenState();
}

class _UploadDocumentsScreenState extends State<UploadDocumentsScreen> {
  final AuthService _authService = AuthService();
  final List<File> _pickedFiles = [];
  bool _isUploading = false;

  Future<void> _pickDocuments() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result != null) {
      setState(() {
        _pickedFiles.addAll(result.paths.map((path) => File(path!)));
      });
    }
  }

  Future<void> _uploadDocuments() async {
    if (_pickedFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one document to upload.'),
        ),
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      for (final file in _pickedFiles) {
        await _authService.uploadDocument(
          user.uid,
          file,
          file.path.split('/').last,
        );
      }
      Navigator.pushReplacementNamed(context, AppRoutes.registrationPending);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to upload documents. Please try again.'),
        ),
      );
    }

    setState(() {
      _isUploading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Documents'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: _pickedFiles.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text(_pickedFiles[index].path.split('/').last),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _pickDocuments,
              child: const Text('Select Documents'),
            ),
            const SizedBox(height: 20),
            _isUploading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _uploadDocuments,
                    child: const Text('Upload Documents'),
                  ),
          ],
        ),
      ),
    );
  }
}