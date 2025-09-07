import 'package:flutter/material.dart';

class NotificationScreen extends StatelessWidget {
  final String initialLanguage;

  const NotificationScreen({super.key, this.initialLanguage = 'EN'});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
      ),
      body: const Center(
        child: Text('User Notifications'),
      ),
    );
  }
}