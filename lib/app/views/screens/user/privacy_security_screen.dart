import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../localization/app_strings.dart';
import '../../../providers/language_provider.dart';
import '../../../services/logging_service.dart';
import '../../../config/theme.dart';

class PrivacySecurityScreen extends StatefulWidget {
  const PrivacySecurityScreen({super.key});

  @override
  State<PrivacySecurityScreen> createState() => _PrivacySecurityScreenState();
}

class _PrivacySecurityScreenState extends State<PrivacySecurityScreen> {
  String _tr(String key) {
    final langCode = Provider.of<LanguageProvider>(context, listen: false).locale.languageCode;
    return AppStrings.tr(context: context, screenKey: 'privacySecurity', stringKey: key, langCode: langCode.toUpperCase());
  }

  @override
  Widget build(BuildContext context) {
    LoggingService().debug('Building PrivacySecurityScreen');
    return Scaffold(
      backgroundColor: AppTheme.whiteColor,
      appBar: AppBar(
        backgroundColor: AppTheme.whiteColor,
        foregroundColor: AppTheme.onSurface,
        elevation: 0,
        title: Text(
          _tr('title'),
          style: TextStyle(
            color: AppTheme.onSurface,
            fontSize: AppTheme.fontSizeH6,
            fontWeight: FontWeight.w600,
            fontFamily: 'Poppins',
          ),
        ),
        iconTheme: IconThemeData(color: AppTheme.onSurface),
      ),
      body: Center(
        child: Text(
          _tr('content'),
          style: TextStyle(
            color: AppTheme.onSurface,
            fontSize: AppTheme.fontSizeBody1,
            fontFamily: 'Poppins',
          ),
        ),
      ),
    );
  }
}