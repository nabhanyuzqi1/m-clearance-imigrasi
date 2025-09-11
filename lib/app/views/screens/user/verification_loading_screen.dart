import 'package:flutter/material.dart';
import '../../../config/theme.dart';
import '../../../models/clearance_application.dart';
import '../../../localization/app_strings.dart';

class VerificationLoadingScreen extends StatelessWidget {
  final ClearanceApplication application;
  final String initialLanguage;

  const VerificationLoadingScreen({
    super.key,
    required this.application,
    this.initialLanguage = 'EN',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.tr(
          context: context,
          screenKey: 'submissionSent',
          stringKey: 'title',
          langCode: initialLanguage,
        )),
      ),
      body: Center(
        child: Text('Verification loading for ${application.shipName}', style: TextStyle(fontFamily: 'Poppins', color: AppTheme.onSurface)),
      ),
    );
  }
}