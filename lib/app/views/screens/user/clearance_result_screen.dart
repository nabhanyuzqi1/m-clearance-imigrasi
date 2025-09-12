import 'package:flutter/material.dart';
import '../../../config/theme.dart';
import '../../../localization/app_strings.dart';
import '../../../models/clearance_application.dart';
import '../../../services/logging_service.dart';
import '../../../services/auth_service.dart';
import '../../widgets/custom_app_bar.dart';
import 'document_view_screen.dart';

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
    LoggingService().info('Building ClearanceResultScreen for application: ${application.id}, status: ${application.status}');

    String tr(String key) => AppStrings.tr(
          context: context,
          screenKey: 'clearanceResult',
          stringKey: key,
          langCode: initialLanguage,
        );

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: CustomAppBar(
        titleText: tr('title'),
        backgroundColor: AppTheme.whiteColor,
        foregroundColor: AppTheme.blackColor,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(AppTheme.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Success Icon and Message
            Center(
              child: Container(
                padding: EdgeInsets.all(AppTheme.spacing24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.successColor.withAlpha(25),
                      AppTheme.successColor.withAlpha(12),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.successColor.withAlpha(25),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: AppTheme.successColor,
                      size: 64,
                    ),
                    SizedBox(height: AppTheme.spacing8),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppTheme.spacing16,
                        vertical: AppTheme.spacing4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.whiteColor.withAlpha(204),
                        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                      ),
                      child: Text(
                        application.id,
                        style: TextStyle(
                          fontSize: AppTheme.fontSizeBody2,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.successColor,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: AppTheme.spacing16),
            Center(
              child: Text(
                tr('application_submitted'),
                style: TextStyle(
                  fontSize: AppTheme.fontSizeH5,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.successColor,
                  fontFamily: 'Poppins',
                ),
              ),
            ),
            SizedBox(height: AppTheme.spacing8),
            Center(
              child: Text(
                tr('application_id_label'),
                style: TextStyle(
                  fontSize: AppTheme.fontSizeBody1,
                  color: AppTheme.subtitleColor,
                  fontFamily: 'Poppins',
                ),
              ),
            ),

            SizedBox(height: AppTheme.spacing32),

            // Application Details Card
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.whiteColor,
                    AppTheme.greyShade50,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.greyColor.withAlpha(25),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.all(AppTheme.spacing16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with icon
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(AppTheme.spacing8),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withAlpha(25),
                            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                          ),
                          child: Icon(
                            Icons.description,
                            color: AppTheme.primaryColor,
                            size: 24,
                          ),
                        ),
                        SizedBox(width: AppTheme.spacing12),
                        Text(
                          tr('application_details'),
                          style: TextStyle(
                            fontSize: AppTheme.fontSizeH6,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Poppins',
                            color: AppTheme.onSurface,
                          ),
                        ),
                      ],
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

                    // Status with enhanced styling
                    Padding(
                      padding: EdgeInsets.only(bottom: AppTheme.spacing12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 120,
                            child: Text(
                              '${tr('status')}:',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: AppTheme.subtitleColor,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: AppTheme.spacing12,
                              vertical: AppTheme.spacing4,
                            ),
                            decoration: BoxDecoration(
                              color: _getStatusColor(application.status).withAlpha(25),
                              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                              border: Border.all(
                                color: _getStatusColor(application.status).withAlpha(51),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _getStatusIcon(application.status),
                                  color: _getStatusColor(application.status),
                                  size: 16,
                                ),
                                SizedBox(width: AppTheme.spacing4),
                                Text(
                                  _getStatusText(application.status, tr),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: _getStatusColor(application.status),
                                    fontFamily: 'Poppins',
                                    fontSize: AppTheme.fontSizeBody2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

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

                    // File attachments section
                    SizedBox(height: AppTheme.spacing16),
                    Text(
                      tr('attached_documents'),
                      style: TextStyle(
                        fontSize: AppTheme.fontSizeBody1,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Poppins',
                        color: AppTheme.onSurface,
                      ),
                    ),
                    SizedBox(height: AppTheme.spacing12),
                    _buildFilePreview(tr('port_clearance'), application.portClearanceFile, tr, context),
                    _buildFilePreview(tr('crew_list'), application.crewListFile, tr, context),
                    _buildFilePreview(tr('notification_letter'), application.notificationLetterFile, tr, context),
                  ],
                ),
              ),
            ),

            SizedBox(height: AppTheme.spacing32),

            // Action Buttons
            Container(
              padding: EdgeInsets.all(AppTheme.spacing16),
              decoration: BoxDecoration(
                color: AppTheme.whiteColor,
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.greyColor.withAlpha(25),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppTheme.primaryColor.withAlpha(25),
                                AppTheme.primaryColor.withAlpha(12),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                            border: Border.all(
                              color: AppTheme.primaryColor.withAlpha(51),
                              width: 1,
                            ),
                          ),
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: AppTheme.spacing16),
                              backgroundColor: Colors.transparent,
                              side: BorderSide.none,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.home,
                                  color: AppTheme.primaryColor,
                                  size: 20,
                                ),
                                SizedBox(width: AppTheme.spacing8),
                                Text(
                                  tr('back_to_home'),
                                  style: TextStyle(
                                    color: AppTheme.primaryColor,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: AppTheme.spacing16),
                      if (application.status == ApplicationStatus.approved)
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppTheme.successColor,
                                  AppTheme.successColor.withAlpha(204),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.successColor.withAlpha(51),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: () {
                                // TODO: Navigate to reports screen
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Reports feature coming soon')),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                padding: EdgeInsets.symmetric(vertical: AppTheme.spacing16),
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.description,
                                    color: AppTheme.whiteColor,
                                    size: 20,
                                  ),
                                  SizedBox(width: AppTheme.spacing8),
                                  Text(
                                    tr('view_reports'),
                                    style: TextStyle(
                                      color: AppTheme.whiteColor,
                                      fontWeight: FontWeight.w600,
                                      fontFamily: 'Poppins',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      else if (application.status == ApplicationStatus.revision)
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppTheme.warningColor,
                                  AppTheme.warningColor.withAlpha(204),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.warningColor.withAlpha(51),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: () {
                                // Navigate to form for editing with existing application data
                                Navigator.pushReplacementNamed(
                                  context,
                                  '/clearance-form',
                                  arguments: {
                                    'type': application.type,
                                    'agentName': application.agentName,
                                    'existingApplication': application,
                                    'initialLanguage': initialLanguage,
                                  },
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                padding: EdgeInsets.symmetric(vertical: AppTheme.spacing16),
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.edit,
                                    color: AppTheme.whiteColor,
                                    size: 20,
                                  ),
                                  SizedBox(width: AppTheme.spacing8),
                                  Text(
                                    tr('edit_application'),
                                    style: TextStyle(
                                      color: AppTheme.whiteColor,
                                      fontWeight: FontWeight.w600,
                                      fontFamily: 'Poppins',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
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

  Color _getStatusColor(ApplicationStatus status) {
    switch (status) {
      case ApplicationStatus.waiting:
        return AppTheme.primaryColor;
      case ApplicationStatus.approved:
        return AppTheme.successColor;
      case ApplicationStatus.revision:
        return AppTheme.warningColor;
      case ApplicationStatus.declined:
        return AppTheme.errorColor;
    }
  }

  IconData _getStatusIcon(ApplicationStatus status) {
    switch (status) {
      case ApplicationStatus.waiting:
        return Icons.schedule;
      case ApplicationStatus.approved:
        return Icons.check_circle;
      case ApplicationStatus.revision:
        return Icons.edit;
      case ApplicationStatus.declined:
        return Icons.cancel;
    }
  }

  Widget _buildFilePreview(String label, String? fileName, String Function(String) tr, BuildContext context) {
    if (fileName == null || fileName.isEmpty) {
      return Padding(
        padding: EdgeInsets.only(bottom: AppTheme.spacing8),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppTheme.greyShade200,
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              child: Icon(
                Icons.insert_drive_file,
                color: AppTheme.greyColor,
                size: 16,
              ),
            ),
            SizedBox(width: AppTheme.spacing12),
            Expanded(
              child: Text(
                '$label: ${tr('no_file_attached')}',
                style: TextStyle(
                  color: AppTheme.greyColor,
                  fontFamily: 'Poppins',
                  fontSize: AppTheme.fontSizeBody2,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(bottom: AppTheme.spacing8),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: fileName.toLowerCase().endsWith('.pdf')
                  ? AppTheme.errorColor.withAlpha(25)
                  : AppTheme.primaryColor.withAlpha(25),
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
            child: Icon(
              fileName.toLowerCase().endsWith('.pdf')
                  ? Icons.picture_as_pdf
                  : Icons.image,
              color: fileName.toLowerCase().endsWith('.pdf')
                  ? AppTheme.errorColor
                  : AppTheme.primaryColor,
              size: 16,
            ),
          ),
          SizedBox(width: AppTheme.spacing12),
          Expanded(
            child: Text(
              '$label: ${fileName.split('/').last}',
              style: TextStyle(
                color: AppTheme.onSurface,
                fontFamily: 'Poppins',
                fontSize: AppTheme.fontSizeBody2,
              ),
            ),
          ),
          IconButton(
            onPressed: () async {
              if (fileName.isNotEmpty) {
                // Show loading
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Downloading file...')),
                );

                try {
                  final authService = AuthService();
                  final fileData = await authService.downloadFileData(fileName);

                  if (fileData != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DocumentViewScreen(
                          fileData: fileData,
                          fileName: fileName.split('/').last,
                        ),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to download file')),
                    );
                  }
                } catch (e) {
                  LoggingService().error('Error downloading file: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error downloading file')),
                  );
                }
              }
            },
            icon: Icon(
              Icons.visibility,
              color: AppTheme.primaryColor,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}