import 'package:flutter/material.dart';
import '../../../localization/app_strings.dart';
import '../../../services/logging_service.dart';
import '../../../config/theme.dart';
import '../../widgets/custom_app_bar.dart';

class EditProfileScreen extends StatelessWidget {
  final String initialLanguage;

  const EditProfileScreen({super.key, this.initialLanguage = 'EN'});

  @override
  Widget build(BuildContext context) {
    LoggingService().debug('Building EditProfileScreen with language: $initialLanguage');
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: CustomAppBar(
        title: LogoTitle(
          text: AppStrings.tr(
            context: context,
            screenKey: 'splash',
            stringKey: 'app_name',
            langCode: initialLanguage,
          ),
        ),
        backgroundColor: AppTheme.whiteColor,
        foregroundColor: AppTheme.blackColor,
        elevation: 0,
      ),
      body: Center(
        child: Text(
          AppStrings.tr(
            context: context,
            screenKey: 'editOfficerProfile',
            stringKey: 'coming_soon',
            langCode: initialLanguage,
          ),
          style: TextStyle(
            color: AppTheme.onSurface,
            fontSize: AppTheme.fontSizeLarge,
          ),
        ),
      ),
    );
  }
}