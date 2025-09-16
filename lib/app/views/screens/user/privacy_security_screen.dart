import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../localization/app_localizations.dart';
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
    Provider.of<LanguageProvider>(context, listen: false).locale.languageCode;
    return AppLocalizations.of(context).get('privacySecurity.$key');
  }

  @override
  Widget build(BuildContext context) {
    LoggingService().debug('Building PrivacySecurityScreen');
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = screenWidth * 0.06; // 6% of screen width
    final maxWidth = screenWidth > 600 ? 600.0 : double.infinity; // Constrain width on tablets

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
            fontSize: AppTheme.responsiveFontSize(context, mobile: AppTheme.fontSizeH6, tablet: AppTheme.fontSizeH5, desktop: AppTheme.fontSizeH4),
            fontWeight: FontWeight.w600,
            fontFamily: 'Poppins',
          ),
        ),
        iconTheme: IconThemeData(color: AppTheme.onSurface),
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Text(
              _tr('content'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.onSurface,
                fontSize: AppTheme.responsiveFontSize(context, mobile: AppTheme.fontSizeBody1, tablet: AppTheme.fontSizeH6, desktop: AppTheme.fontSizeH6),
                fontFamily: 'Poppins',
              ),
            ),
          ),
        ),
      ),
    );
  }
}