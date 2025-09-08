import 'package:flutter/material.dart';
import '../../../localization/app_strings.dart';

class OfficerNotificationScreen extends StatelessWidget {
  final String initialLanguage;

  const OfficerNotificationScreen({super.key, this.initialLanguage = 'EN'});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.tr(
          context: context,
          screenKey: 'officerNotifications',
          stringKey: 'title',
          langCode: initialLanguage,
        )),
      ),
      body: Center(
        child: Text(AppStrings.tr(
          context: context,
          screenKey: 'officerNotifications',
          stringKey: 'empty_title',
          langCode: initialLanguage,
        )),
      ),
    );
  }
}