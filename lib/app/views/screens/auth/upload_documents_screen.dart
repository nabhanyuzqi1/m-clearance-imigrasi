import 'dart:async';
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
  bool _isMarking = false;
  bool _canUpload = false;
  StreamSubscription<User?>? _authSub;

  @override
  void initState() {
    super.initState();
    // Navigate to login if user signs out while on this screen
    _authSub = _authService.authStateChanges.listen((user) {
      if (user == null && mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.login);
      }
    });
    // Enforce preconditions on entry
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPreconditions(navigateOnFail: true);
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> _checkPreconditions({bool navigateOnFail = false}) async {
    try {
      await _authService.ensureCanUploadDocuments();
      if (mounted) {
        setState(() {
          _canUpload = true;
        });
      }
    } on StateError catch (e) {
      if (mounted) {
        setState(() {
          _canUpload = false;
        });
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
      if (navigateOnFail) {
        _routeForErrorMessage(e.message);
      }
    } catch (_) {
      // Keep UI responsive on unexpected errors
    }
  }

  void _routeForErrorMessage(String message) {
    if (!mounted) return;
    if (message.contains('Email is not verified')) {
      Navigator.pushReplacementNamed(context, AppRoutes.emailVerification);
    } else if (message.contains('No authenticated user') ||
        message.contains('User data not found')) {
      Navigator.pushReplacementNamed(context, AppRoutes.login);
    } else if (message.contains('Current status')) {
      Navigator.pushReplacementNamed(context, AppRoutes.registrationPending);
    }
  }

  Future<void> _pickDocuments() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result != null) {
      if (!mounted) return;
      setState(() {
        _pickedFiles.addAll(
          result.paths.whereType<String>().map((path) => File(path)),
        );
      });
    }
  }

  Future<void> _uploadDocuments() async {
    if (_pickedFiles.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one document to upload.'),
        ),
      );
      return;
    }

    // Re-validate preconditions before uploading
    await _checkPreconditions(navigateOnFail: true);
    if (!_canUpload) return;

    if (mounted) {
      setState(() {
        _isUploading = true;
      });
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.login);
        setState(() {
          _isUploading = false;
        });
      }
      return;
    }

    final List<String> uploadedPaths = [];
    try {
      for (final file in _pickedFiles) {
        final url = await _authService.uploadDocument(
          user.uid,
          file,
          file.path.split('/').last,
        );
        if (url != null && url.isNotEmpty) {
          uploadedPaths.add(url);
        }
      }

      if (uploadedPaths.isNotEmpty) {
        if (mounted) {
          setState(() {
            _isMarking = true;
          });
        }
        // Mark completion and move to pending_approval (idempotent)
        final _ = await _authService.markDocumentsUploaded(
          storagePathsOrRefs: uploadedPaths,
        );

        if (!mounted) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          Navigator.pushReplacementNamed(
              context, AppRoutes.registrationPending);
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No documents were uploaded.')),
          );
        }
      }
    } on StateError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
      _routeForErrorMessage(e.message);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Failed to upload documents. Please try again.')),
        );
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
    final bool busy = _isUploading || _isMarking;
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
              onPressed: busy ? null : _pickDocuments,
              child: const Text('Select Documents'),
            ),
            const SizedBox(height: 20),
            busy
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed:
                        (!_canUpload || busy) ? null : _uploadDocuments,
                    child: const Text('Upload Documents'),
                  ),
          ],
        ),
      ),
    );
  }
}