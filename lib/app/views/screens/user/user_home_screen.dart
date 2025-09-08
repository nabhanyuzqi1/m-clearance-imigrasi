import 'package:flutter/material.dart';
import 'package:m_clearance_imigrasi/app/services/auth_service.dart';
import '../../../localization/app_strings.dart';

class UserHomeScreen extends StatelessWidget {
  final String initialLanguage;

  const UserHomeScreen({Key? key, this.initialLanguage = 'EN'}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.tr(
          context: context,
          screenKey: 'userHome',
          stringKey: 'title',
          langCode: initialLanguage,
        )),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await AuthService().signOut();
            },
          ),
        ],
      ),
      body: const Center(child: Text('Welcome!')),
    );
  }
}