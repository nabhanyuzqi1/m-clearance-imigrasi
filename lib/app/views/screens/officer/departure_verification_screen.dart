import 'package:flutter/material.dart';
import '../../../localization/app_strings.dart';

class DepartureVerificationScreen extends StatelessWidget {
  final String adminName;
  final String initialLanguage;

  const DepartureVerificationScreen({
    super.key,
    required this.adminName,
    this.initialLanguage = 'EN',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.tr(
          context: context,
          screenKey: 'departureVerification',
          stringKey: 'title',
          langCode: initialLanguage,
        )),
      ),
      body: Center(
        child: Text('Departure Verification Screen for $adminName'),
      ),
    );
  }
}