import 'package:flutter/material.dart';

class OfficerNotificationScreen extends StatelessWidget {
  final String initialLanguage;

  const OfficerNotificationScreen({super.key, this.initialLanguage = 'EN'});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
      ),
      body: const Center(
        child: Text('Officer Notifications'),
      ),
    );
  }
}