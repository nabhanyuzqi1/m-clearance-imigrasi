import 'package:flutter/material.dart';
import '../../../localization/app_strings.dart';

class EditProfileScreen extends StatelessWidget {
  final String initialLanguage;

  const EditProfileScreen({super.key, this.initialLanguage = 'EN'});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.tr(
          context: context,
          screenKey: 'editOfficerProfile',
          stringKey: 'title',
          langCode: initialLanguage,
        )),
      ),
      body: const Center(
        child: Text('Edit Profile Screen'),
      ),
    );
  }
}