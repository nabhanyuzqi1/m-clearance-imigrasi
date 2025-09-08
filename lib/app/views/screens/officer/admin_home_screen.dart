import 'package:flutter/material.dart';
import '../../../localization/app_strings.dart';

class AdminHomeScreen extends StatelessWidget {
  final String adminName;
  final String adminUsername;
  final String initialLanguage;
  const AdminHomeScreen({
    super.key,
    required this.adminName,
    required this.adminUsername,
    this.initialLanguage = 'EN',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.tr(
          context: context,
          screenKey: 'adminHome',
          stringKey: 'title',
          langCode: initialLanguage,
        )),
      ),
    );
  }
}