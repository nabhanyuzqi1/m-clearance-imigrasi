import 'package:flutter/material.dart';
import '../../../config/theme.dart';
import '../../../localization/app_strings.dart';
import '../../../services/logging_service.dart';

class SubmissionSentScreen extends StatelessWidget {
  final String initialLanguage;

  const SubmissionSentScreen({
    super.key,
    required this.initialLanguage,
  });

  @override
  Widget build(BuildContext context) {
    LoggingService().debug('Building SubmissionSentScreen with language: $initialLanguage');

    String tr(String key) => AppStrings.tr(
      context: context,
      screenKey: 'submissionSent',
      stringKey: key,
      langCode: initialLanguage,
    );

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(AppTheme.spacing24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Success Animation/Icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: AppTheme.successColor.withAlpha(25),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle,
                  color: AppTheme.successColor,
                  size: 80,
                ),
              ),

              SizedBox(height: AppTheme.spacing32),

              // Title
              Text(
                tr('title'),
                style: TextStyle(
                  fontSize: AppTheme.fontSizeH4,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.onSurface,
                  fontFamily: 'Poppins',
                ),
                textAlign: TextAlign.center,
              ),

              SizedBox(height: AppTheme.spacing16),

              // Subtitle
              Text(
                tr('thank_you'),
                style: TextStyle(
                  fontSize: AppTheme.fontSizeH6,
                  color: AppTheme.subtitleColor,
                  fontFamily: 'Poppins',
                ),
                textAlign: TextAlign.center,
              ),

              SizedBox(height: AppTheme.spacing24),

              // Description
              Container(
                padding: EdgeInsets.all(AppTheme.spacing20),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withAlpha(12),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  border: Border.all(
                    color: AppTheme.primaryColor.withAlpha(51),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      tr('submission_received'),
                      style: TextStyle(
                        fontSize: AppTheme.fontSizeBody1,
                        color: AppTheme.onSurface,
                        height: 1.5,
                        fontFamily: 'Poppins',
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: AppTheme.spacing12),
                    Text(
                      tr('tracking_info'),
                      style: TextStyle(
                        fontSize: AppTheme.fontSizeBody2,
                        color: AppTheme.subtitleColor,
                        height: 1.5,
                        fontFamily: 'Poppins',
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              SizedBox(height: AppTheme.spacing48),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: AppTheme.spacing16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                        ),
                        side: BorderSide(color: AppTheme.primaryColor),
                      ),
                      child: Text(
                        tr('back_to_home'),
                        style: TextStyle(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: AppTheme.spacing16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        // Navigate to history screen
                        Navigator.pushReplacementNamed(context, '/user-home');
                        // Note: This navigates to home, user can then tap History tab
                        // For better UX, we could implement deep linking to history tab
                      },
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: AppTheme.spacing16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                        ),
                      ),
                      child: Text(tr('view_history'), style: TextStyle(fontFamily: 'Poppins')),
                    ),
                  ),
                ],
              ),

              SizedBox(height: AppTheme.spacing24),

              // Additional Info
              Text(
                tr('support_info'),
                style: TextStyle(
                  fontSize: AppTheme.fontSizeBody2,
                  color: AppTheme.subtitleColor,
                  fontFamily: 'Poppins',
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}