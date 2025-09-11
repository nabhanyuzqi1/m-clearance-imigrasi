import 'package:flutter/material.dart';
import '../../../config/theme.dart';
import '../../../localization/app_strings.dart';
import '../../../models/clearance_application.dart';

class ClearanceResultScreen extends StatelessWidget {
  final ClearanceApplication application;
  final String initialLanguage;
  const ClearanceResultScreen({
    super.key,
    required this.application,
    required this.initialLanguage,
  });

  @override
  Widget build(BuildContext context) {
    String tr(String key) => AppStrings.tr(
          context: context,
          screenKey: 'clearanceResult',
          stringKey: key,
          langCode: initialLanguage,
        );

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(tr('application_submitted')),
        backgroundColor: AppTheme.surfaceColor,
        foregroundColor: AppTheme.onSurface,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(AppTheme.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Success Icon and Message
            Center(
              child: Column(
                children: [
                  Container(
                    padding: EdgeInsets.all(AppTheme.spacing24),
                    decoration: BoxDecoration(
                      color: AppTheme.successColor.withAlpha(25),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_circle,
                      color: AppTheme.successColor,
                      size: 64,
                    ),
                  ),
                  SizedBox(height: AppTheme.spacing16),
                  Text(
                    tr('application_submitted'),
                    style: TextStyle(
                      fontSize: AppTheme.fontSizeH5,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.successColor,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  SizedBox(height: AppTheme.spacing8),
                  Text(
                    'Application ID: ${application.id}',
                    style: TextStyle(
                      fontSize: AppTheme.fontSizeBody1,
                      color: AppTheme.subtitleColor,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: AppTheme.spacing32),

            // Application Details Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
              child: Padding(
                padding: EdgeInsets.all(AppTheme.spacing16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('application_details'),
                      style: TextStyle(
                        fontSize: AppTheme.fontSizeH6,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Poppins',
                        color: AppTheme.onSurface,
                      ),
                    ),
                    SizedBox(height: AppTheme.spacing16),

                    // Ship Information
                    _buildDetailRow(tr('ship_name'), application.shipName),
                    _buildDetailRow(tr('flag'), application.flag),
                    _buildDetailRow(tr('type'),
                      application.type == ApplicationType.kedatangan
                          ? tr('arrival')
                          : tr('departure')
                    ),

                    if (application.port != null)
                      _buildDetailRow(tr('port'), application.port!),

                    if (application.date != null)
                      _buildDetailRow(tr('date'), application.date!),

                    // Crew Information
                    if (application.wniCrew != null)
                      _buildDetailRow(tr('wni_crew'), application.wniCrew!),

                    if (application.wnaCrew != null)
                      _buildDetailRow(tr('wna_crew'), application.wnaCrew!),

                    // Officer Information
                    if (application.officerName != null)
                      _buildDetailRow(tr('officer_name'), application.officerName!),

                    if (application.location != null)
                      _buildDetailRow(tr('location'), application.location!),

                    // Status
                    _buildDetailRow(tr('status'), _getStatusText(application.status, tr)),

                    // Notes
                    if (application.notes != null && application.notes!.isNotEmpty)
                      _buildDetailRow(tr('notes'), application.notes!)
                    else
                      _buildDetailRow(tr('notes'), tr('no_notes')),

                    // Submitted At
                    _buildDetailRow(
                      tr('submitted_at'),
                      '${application.createdAt.day}/${application.createdAt.month}/${application.createdAt.year} ${application.createdAt.hour}:${application.createdAt.minute.toString().padLeft(2, '0')}'
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: AppTheme.spacing32),

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
                    ),
                    child: Text(tr('back_to_home')),
                  ),
                ),
                SizedBox(width: AppTheme.spacing16),
                if (application.status == ApplicationStatus.approved)
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        // TODO: Navigate to reports screen
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Reports feature coming soon')),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: AppTheme.spacing16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                        ),
                      ),
                      child: Text(tr('view_reports')),
                    ),
                  )
                else if (application.status == ApplicationStatus.revision)
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        // Navigate back to form for editing
                        Navigator.of(context).pop(); // This should pop the result screen
                        Navigator.of(context).pop(); // This should pop the form screen
                      },
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: AppTheme.spacing16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                        ),
                      ),
                      child: Text(tr('edit_application')),
                    ),
                  ),
              ],
            ),

            SizedBox(height: AppTheme.spacing24),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppTheme.spacing12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: AppTheme.subtitleColor,
                fontFamily: 'Poppins',
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: AppTheme.onSurface,
                fontFamily: 'Poppins',
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusText(ApplicationStatus status, String Function(String) tr) {
    switch (status) {
      case ApplicationStatus.waiting:
        return tr('waiting');
      case ApplicationStatus.approved:
        return tr('approved');
      case ApplicationStatus.revision:
        return tr('revision');
      case ApplicationStatus.declined:
        return tr('declined');
    }
  }
}