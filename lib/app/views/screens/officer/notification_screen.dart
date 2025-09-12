import 'package:flutter/material.dart';
import '../../../localization/app_strings.dart';
import '../../../services/logging_service.dart';
import '../../../config/theme.dart';
import '../../widgets/custom_app_bar.dart';

class OfficerNotificationScreen extends StatelessWidget {
  final String initialLanguage;

  const OfficerNotificationScreen({super.key, this.initialLanguage = 'EN'});

  @override
  Widget build(BuildContext context) {
    LoggingService().debug('Building OfficerNotificationScreen with language: $initialLanguage');
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: CustomAppBar(
        titleText: AppStrings.tr(
          context: context,
          screenKey: 'officerNotifications',
          stringKey: 'title',
          langCode: initialLanguage,
        ),
        backgroundColor: AppTheme.whiteColor,
        foregroundColor: AppTheme.blackColor,
        elevation: 0,
      ),
      body: Center(
        child: Text(
          AppStrings.tr(
            context: context,
            screenKey: 'officerNotifications',
            stringKey: 'empty_title',
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