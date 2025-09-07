import 'package:flutter/material.dart';

class RegistrationPendingScreen extends StatelessWidget {
  const RegistrationPendingScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registration Pending'),
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'Your account is pending approval. You will be notified once your account has been reviewed by an administrator.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}