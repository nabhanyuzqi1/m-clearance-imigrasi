import 'package:flutter/material.dart';
import '../../../localization/app_strings.dart';

class AccountDetailScreen extends StatelessWidget {
  final String initialLanguage;
  const AccountDetailScreen({super.key, this.initialLanguage = 'EN'});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.tr(
          context: context,
          screenKey: 'accountDetail',
          stringKey: 'title',
          langCode: initialLanguage,
        )),
      ),
    );
  }
}