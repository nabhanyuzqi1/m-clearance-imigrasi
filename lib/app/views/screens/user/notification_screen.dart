import 'package:flutter/material.dart';
import '../../../localization/app_strings.dart';

class NotificationScreen extends StatelessWidget {
  final String initialLanguage;

  const NotificationScreen({super.key, this.initialLanguage = 'EN'});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.tr(
          context: context,
          screenKey: 'userNotifications',
          stringKey: 'title',
          langCode: initialLanguage,
        )),
      ),
      body: Center(
        child: Text(AppStrings.tr(
          context: context,
          screenKey: 'userNotifications',
          stringKey: 'empty_title',
          langCode: initialLanguage,
        )),
      ),
    );
  }
}