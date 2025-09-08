import 'package:flutter/material.dart';
import '../../../localization/app_strings.dart';

class AccountVerificationListScreen extends StatelessWidget {
  final String initialLanguage;
  const AccountVerificationListScreen({super.key, this.initialLanguage = 'EN'});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.tr(
          context: context,
          screenKey: 'accountVerificationList',
          stringKey: 'title',
          langCode: initialLanguage,
        )),
      ),
    );
  }
}