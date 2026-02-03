import 'package:flutter/material.dart';
import '../../../config/routes.dart';
import '../../../config/theme.dart';
import '../../../localization/app_localizations.dart';
import '../../../services/logging_service.dart';

class SubmissionWaitingScreen extends StatelessWidget {
  final String initialLanguage;

  const SubmissionWaitingScreen({super.key, required this.initialLanguage});

  @override
  Widget build(BuildContext context) {
    LoggingService().debug(
      'Building SubmissionWaitingScreen with language: $initialLanguage',
    );
    LoggingService().info(
      'SubmissionWaitingScreen is being displayed - checking navigation stack',
    );
    LoggingService().debug(
      'SubmissionWaitingScreen build: context.hashCode=${context.hashCode}, widget.hashCode=$hashCode',
    );

    String tr(String key) =>
        AppLocalizations.of(context).get('submissionWaiting.$key');

    return Scaffold(
      key: const ValueKey('submission_waiting_scaffold'),
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(tr('title')),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
      ),
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
                  color: Theme.of(context).colorScheme.primary.withAlpha(25),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.hourglass_top,
                  color: Theme.of(context).colorScheme.primary,
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
                  color: Theme.of(context).colorScheme.onSurface,
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
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontFamily: 'Poppins',
                ),
                textAlign: TextAlign.center,
              ),

              SizedBox(height: AppTheme.spacing24),

              // Processing Info
              Container(
                padding: EdgeInsets.all(AppTheme.spacing20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondary.withAlpha(12),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.secondary.withAlpha(51),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          color: Theme.of(context).colorScheme.secondary,
                          size: 24,
                        ),
                        SizedBox(width: AppTheme.spacing12),
                        Expanded(
                          child: Text(
                            tr('estimated_time'),
                            style: TextStyle(
                              fontSize: AppTheme.fontSizeBody1,
                              color: Theme.of(context).colorScheme.onSurface,
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
                        color: Theme.of(context).colorScheme.onSurface,
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
                  color: Theme.of(context).colorScheme.tertiary.withAlpha(12),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.tertiary.withAlpha(51),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.notifications,
                      color: Theme.of(context).colorScheme.tertiary,
                      size: 24,
                    ),
                    SizedBox(width: AppTheme.spacing12),
                    Expanded(
                      child: Text(
                        tr('notification_info'),
                        style: TextStyle(
                          fontSize: AppTheme.fontSizeBody2,
                          color: Theme.of(context).colorScheme.onSurface,
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
                      onPressed: () {
                        LoggingService().debug(
                          'Back to home button pressed in SubmissionWaitingScreen',
                        );
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (context.mounted) {
                            Navigator.of(context).pop();
                          }
                        });
                      },
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                          vertical: AppTheme.spacing16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusMedium,
                          ),
                        ),
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      child: Text(
                        tr('back_to_home'),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
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
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (context.mounted) {
                            Navigator.pushReplacementNamed(
                              context,
                              AppRoutes.userHome,
                            );
                          }
                        });
                        // Note: This navigates to home, user can then tap History tab
                        // For better UX, we could implement deep linking to history tab
                      },
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                          vertical: AppTheme.spacing16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusMedium,
                          ),
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
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    SizedBox(height: AppTheme.spacing8),
                    Text(
                      tr('progress_text'),
                      style: TextStyle(
                        fontSize: AppTheme.fontSizeCaption,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
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
