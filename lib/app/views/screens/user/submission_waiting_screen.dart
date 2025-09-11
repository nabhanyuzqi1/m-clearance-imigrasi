import 'package:flutter/material.dart';
import '../../../config/theme.dart';
import '../../../localization/app_strings.dart';

class SubmissionWaitingScreen extends StatelessWidget {
  final String initialLanguage;

  const SubmissionWaitingScreen({
    super.key,
    required this.initialLanguage,
  });

  @override
  Widget build(BuildContext context) {
    String tr(String key) => AppStrings.tr(
      context: context,
      screenKey: 'submissionWaiting',
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
              // Processing Animation/Icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withAlpha(25),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.hourglass_top,
                  color: AppTheme.primaryColor,
                  size: 60,
                ),
              ),

              SizedBox(height: AppTheme.spacing32),

              // Title
              Text(
                tr('submission_received'),
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
                tr('processing'),
                style: TextStyle(
                  fontSize: AppTheme.fontSizeH6,
                  color: AppTheme.subtitleColor,
                  fontFamily: 'Poppins',
                ),
                textAlign: TextAlign.center,
              ),

              SizedBox(height: AppTheme.spacing24),

              // Processing Info
              Container(
                padding: EdgeInsets.all(AppTheme.spacing20),
                decoration: BoxDecoration(
                  color: AppTheme.warningColor.withAlpha(12),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  border: Border.all(
                    color: AppTheme.warningColor.withAlpha(51),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          color: AppTheme.warningColor,
                          size: 24,
                        ),
                        SizedBox(width: AppTheme.spacing12),
                        Expanded(
                          child: Text(
                            tr('estimated_time'),
                            style: TextStyle(
                              fontSize: AppTheme.fontSizeBody1,
                              color: AppTheme.onSurface,
                              fontWeight: FontWeight.w500,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: AppTheme.spacing16),
                    Text(
                      tr('review_time'),
                      style: TextStyle(
                        fontSize: AppTheme.fontSizeBody2,
                        color: AppTheme.onSurface,
                        height: 1.5,
                        fontFamily: 'Poppins',
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              SizedBox(height: AppTheme.spacing24),

              // Notification Info
              Container(
                padding: EdgeInsets.all(AppTheme.spacing16),
                decoration: BoxDecoration(
                  color: AppTheme.successColor.withAlpha(12),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  border: Border.all(
                    color: AppTheme.successColor.withAlpha(51),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.notifications,
                      color: AppTheme.successColor,
                      size: 24,
                    ),
                    SizedBox(width: AppTheme.spacing12),
                    Expanded(
                      child: Text(
                        tr('notification_info'),
                        style: TextStyle(
                          fontSize: AppTheme.fontSizeBody2,
                          color: AppTheme.onSurface,
                          height: 1.4,
                          fontFamily: 'Poppins',
                        ),
                      ),
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
                        Navigator.of(context).pop(); // Go back to home
                        // TODO: Navigate to history tab
                      },
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: AppTheme.spacing16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                        ),
                      ),
                      child: Text(tr('check_status')),
                    ),
                  ),
                ],
              ),

              SizedBox(height: AppTheme.spacing24),

              // Progress Indicator
              Container(
                padding: EdgeInsets.symmetric(vertical: AppTheme.spacing8),
                child: Column(
                  children: [
                    LinearProgressIndicator(
                      value: 0.3, // 30% progress
                      backgroundColor: AppTheme.greyShade300,
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                    ),
                    SizedBox(height: AppTheme.spacing8),
                    Text(
                      'Application submitted successfully',
                      style: TextStyle(
                        fontSize: AppTheme.fontSizeCaption,
                        color: AppTheme.subtitleColor,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}