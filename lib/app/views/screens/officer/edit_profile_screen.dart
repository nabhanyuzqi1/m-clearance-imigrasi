import 'package:flutter/material.dart';

class EditProfileScreen extends StatelessWidget {
  final String initialLanguage;

  const EditProfileScreen({super.key, this.initialLanguage = 'EN'});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
      ),
      body: const Center(
        child: Text('Edit Profile Screen'),
      ),
    );
  }
}