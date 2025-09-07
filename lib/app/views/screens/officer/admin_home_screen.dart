import 'package:flutter/material.dart';

class AdminHomeScreen extends StatelessWidget {
  final String adminName;
  final String adminUsername;
  const AdminHomeScreen({super.key, required this.adminName, required this.adminUsername});

  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text("Admin Home")));
  }
}