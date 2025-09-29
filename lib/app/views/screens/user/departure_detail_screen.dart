import 'package:flutter/material.dart';
import '../../../config/theme.dart';
import '../../../models/clearance_application.dart';
import '../../../localization/app_strings.dart';
import '../../../localization/app_localizations.dart';
import '../../../services/logging_service.dart';
import '../../../services/functions_service.dart';
import '../../../services/auth_service.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/custom_button.dart';
import 'document_view_screen.dart';
import '../../../utils/file_utils.dart';
import 'clearance_form_screen.dart';

class DepartureDetailScreen extends StatelessWidget {
  final ClearanceApplication application;
  final String initialLanguage;

  const DepartureDetailScreen({
    super.key,
    required this.application,
    required this.initialLanguage,
  });

  String _tr(BuildContext context, String key) => AppStrings.tr(
    screenKey: 'userHistory',
    stringKey: key,
    langCode: initialLanguage,
  );

  String _formatLocation(BuildContext context, String? location) {
    if (location != null && location.trim().isNotEmpty) {
      return location.trim();
    }
    return AppLocalizations.of(
      context,
    ).get('submissionDetail.location_not_provided');
  }

  String _formatField(BuildContext context, String? value) {
    if (value == null) {
      return AppLocalizations.of(context).get('clearanceResult.not_provided');
    }
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return AppLocalizations.of(context).get('clearanceResult.not_provided');
    }
    const invalidTokens = {
      'n/a',
      'na',
      'n.a',
      'not available',
      'tidak tersedia',
      '-',
    };
    return invalidTokens.contains(trimmed.toLowerCase())
        ? AppLocalizations.of(context).get('clearanceResult.not_provided')
        : trimmed;
  }

  @override
  Widget build(BuildContext context) {
    LoggingService().debug(
      'Building DepartureDetailScreen for application: ${application.id}',
    );
    final screenWidth = MediaQuery.of(context).size.width;
    final responsivePadding = screenWidth > 600
        ? AppTheme.spacing16
        : screenWidth * 0.04;
    return Scaffold(
      backgroundColor: AppTheme.greyShade50,
      appBar: CustomAppBar(
        titleText: _tr(context, 'departure_detail'),
        backgroundColor: AppTheme.whiteColor,
        foregroundColor: AppTheme.blackColor,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(responsivePadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Application Header
            Container(
              padding: EdgeInsets.all(AppTheme.spacing16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.secondaryColor,
                    (AppTheme.secondaryColor).withAlpha(204),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                boxShadow: [
                  BoxShadow(
                    color: (AppTheme.secondaryColor).withAlpha(51),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(AppTheme.spacing12),
                    decoration: BoxDecoration(
                      color: AppTheme.whiteColor.withAlpha(51),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                    ),
                    child: Icon(
                      Icons.directions_boat,
                      color: AppTheme.whiteColor,
                      size: screenWidth > 600 ? 32.0 : screenWidth * 0.08,
                    ),
                  ),
                  SizedBox(width: AppTheme.spacing16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          application.shipName,
                          style: TextStyle(
                            fontSize: AppTheme.fontSizeH5,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.whiteColor,
                            fontFamily: 'Poppins',
                          ),
                        ),
                        SizedBox(height: AppTheme.spacing4),
                        Text(
                          'Application ID: ${application.id}',
                          style: TextStyle(
                            fontSize: AppTheme.fontSizeBody2,
                            color: AppTheme.whiteColor.withAlpha(204),
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: AppTheme.spacing24),

            // Status Card
            Container(
              padding: EdgeInsets.all(AppTheme.spacing16),
              decoration: BoxDecoration(
                color: AppTheme.whiteColor,
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.greyColor.withAlpha(25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: AppTheme.primaryColor,
                        size: screenWidth > 600 ? 24.0 : screenWidth * 0.06,
                      ),
                      SizedBox(width: AppTheme.spacing12),
                      Text(
                        'Application Status',
                        style: TextStyle(
                          fontSize: AppTheme.fontSizeH6,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.onSurface,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: AppTheme.spacing12),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppTheme.spacing12,
                      vertical: AppTheme.spacing8,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(application.status).withAlpha(25),
                      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                      border: Border.all(
                        color: _getStatusColor(
                          application.status,
                        ).withAlpha(51),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getStatusIcon(application.status),
                          color: _getStatusColor(application.status),
                          size: screenWidth > 600 ? 16.0 : screenWidth * 0.04,
                        ),
                        SizedBox(width: AppTheme.spacing8),
                        Text(
                          _getStatusText(application.status, context),
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

            SizedBox(height: AppTheme.spacing24),

            // Details Card
            Container(
              padding: EdgeInsets.all(AppTheme.spacing16),
              decoration: BoxDecoration(
                color: AppTheme.whiteColor,
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.greyColor.withAlpha(25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.description,
                        color: AppTheme.primaryColor,
                        size: screenWidth > 600 ? 24.0 : screenWidth * 0.06,
                      ),
                      SizedBox(width: AppTheme.spacing12),
                      Text(
                        'Departure Details',
                        style: TextStyle(
                          fontSize: AppTheme.fontSizeH6,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.onSurface,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: AppTheme.spacing16),
                  _buildDetailItem(context, 'Ship Name', application.shipName),
                  _buildDetailItem(context, 'Flag', application.flag),
                  _buildDetailItem(
                    context,
                    'Next Port',
                    _formatField(context, application.port),
                  ),
                  _buildDetailItem(
                    context,
                    'ETD',
                    _formatField(context, application.date),
                  ),
                  _buildDetailItem(
                    context,
                    'WNI Crew',
                    application.wniCrew?.toString() ?? '0',
                  ),
                  _buildDetailItem(
                    context,
                    'WNA Crew',
                    application.wnaCrew?.toString() ?? '0',
                  ),
                  _buildDetailItem(context, 'Agent', application.agentName),
                  _buildDetailItem(
                    context,
                    'Location',
                    _formatLocation(context, application.location),
                  ),
                  _buildDetailItem(
                    context,
                    'Submitted At',
                    '${application.createdAt.day}/${application.createdAt.month}/${application.createdAt.year} ${application.createdAt.hour}:${application.createdAt.minute.toString().padLeft(2, '0')}',
                  ),
                  if (application.officerName != null)
                    _buildDetailItem(
                      context,
                      'Reviewed By',
                      application.officerName!,
                    ),
                  if (application.notes != null &&
                      application.notes!.isNotEmpty)
                    _buildDetailItem(
                      context,
                      'Officer Notes',
                      application.notes!,
                    ),
                ],
              ),
            ),

            SizedBox(height: AppTheme.spacing24),

            // File Attachments
            Container(
              padding: EdgeInsets.all(AppTheme.spacing16),
              decoration: BoxDecoration(
                color: AppTheme.whiteColor,
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.greyColor.withAlpha(25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.attach_file,
                        color: AppTheme.primaryColor,
                        size: screenWidth > 600 ? 24.0 : screenWidth * 0.06,
                      ),
                      SizedBox(width: AppTheme.spacing12),
                      Text(
                        'Attached Documents',
                        style: TextStyle(
                          fontSize: AppTheme.fontSizeH6,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.onSurface,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: AppTheme.spacing16),
                  _buildFileItem(
                    context,
                    'Port Clearance',
                    application.portClearanceFile,
                  ),
                  if (application.crewListFiles.isEmpty)
                    _buildFileItem(context, 'Crew List', null)
                  else
                    ...application.crewListFiles.asMap().entries.map(
                      (entry) => _buildFileItem(
                        context,
                        application.crewListFiles.length > 1
                            ? 'Crew List #${entry.key + 1}'
                            : 'Crew List',
                        entry.value,
                      ),
                    ),
                  _buildFileItem(
                    context,
                    'Notification Letter',
                    application.notificationLetterFile,
                  ),
                ],
              ),
            ),

            SizedBox(height: AppTheme.spacing24),

            if (application.status == ApplicationStatus.revision)
              _buildRevisionBanner(context),

            if (application.status == ApplicationStatus.revision)
              SizedBox(height: AppTheme.spacing24),

            // PDF Generation Button
            Container(
              padding: EdgeInsets.all(AppTheme.spacing16),
              decoration: BoxDecoration(
                color: AppTheme.whiteColor,
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.greyColor.withAlpha(25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    'Generate PDF Report',
                    style: TextStyle(
                      fontSize: AppTheme.fontSizeH6,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.onSurface,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  SizedBox(height: AppTheme.spacing12),
                  Text(
                    'Download a comprehensive PDF report of this application with official M-Clearance ISam branding.',
                    style: TextStyle(
                      fontSize: AppTheme.fontSizeBody2,
                      color: AppTheme.subtitleColor,
                      fontFamily: 'Poppins',
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: AppTheme.spacing16),
                  CustomButton(
                    text: 'Generate & Download PDF',
                    type: CustomButtonType.elevated,
                    backgroundColor: AppTheme.secondaryColor,
                    onPressed: () => _generatePDF(context),
                    isFullWidth: true,
                  ),
                ],
              ),
            ),

            SizedBox(height: AppTheme.spacing32),
          ],
        ),
      ),
    );
  }

  Future<void> _generatePDF(BuildContext context) async {
    try {
      // Show loading dialog
      final screenWidth = MediaQuery.of(context).size.width;
      final isTablet = screenWidth > 600;
      final maxWidth = isTablet ? 400.0 : double.infinity;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return Container(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: AlertDialog(
              content: Row(
                children: [
                  CircularProgressIndicator(color: AppTheme.primaryColor),
                  SizedBox(width: AppTheme.spacing16),
                  Expanded(
                    child: Text(
                      'Generating PDF...',
                      style: TextStyle(
                        fontSize: screenWidth * 0.04,
                        color: AppTheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );

      // Call Firebase Function to generate PDF
      final functions = FunctionsService();
      final result = await functions.generateHistoryPDF(application.id);

      // Close loading dialog
      Navigator.of(context).pop();

      if (result['success'] == true) {
        final pdfUrl = result['pdfUrl'];

        // Show loading for download
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Downloading PDF...')));

        try {
          // Download PDF data
          final authService = AuthService();
          final pdfData = await authService.downloadFileData(pdfUrl);

          if (pdfData != null) {
            // Navigate to internal PDF viewer
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DocumentViewScreen(
                  fileData: pdfData,
                  fileName: 'Application_Report_${application.id}.pdf',
                ),
              ),
            );
          } else {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Failed to download PDF')));
          }
        } catch (e) {
          LoggingService().error('Error downloading PDF: $e');
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error downloading PDF')));
        }
      } else {
        throw Exception('PDF generation failed');
      }
    } catch (e) {
      // Close loading dialog if open
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      // Show error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to generate PDF: ${e.toString()}'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  Widget _buildDetailItem(BuildContext context, String label, String value) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppTheme.spacing8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: screenWidth > 600 ? 120.0 : screenWidth * 0.25,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontFamily: 'Poppins',
                color: AppTheme.onSurface,
              ),
            ),
          ),
          SizedBox(width: AppTheme.spacing16),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontFamily: 'Poppins',
                color: AppTheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRevisionBanner(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppTheme.spacing16),
      decoration: BoxDecoration(
        color: AppTheme.warningColor.withAlpha(25),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: AppTheme.warningColor.withAlpha(128)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _tr(context, 'revision_banner_title'),
            style: TextStyle(
              fontSize: AppTheme.fontSizeH6,
              fontWeight: FontWeight.bold,
              color: AppTheme.warningColor,
              fontFamily: 'Poppins',
            ),
          ),
          SizedBox(height: AppTheme.spacing8),
          Text(
            _tr(context, 'revision_banner_body'),
            style: TextStyle(
              fontSize: AppTheme.fontSizeBody2,
              color: AppTheme.subtitleColor,
              fontFamily: 'Poppins',
            ),
          ),
          SizedBox(height: AppTheme.spacing16),
          CustomButton(
            text: _tr(context, 'revision_button'),
            type: CustomButtonType.elevated,
            backgroundColor: AppTheme.primaryColor,
            onPressed: () => _openRevisionForm(context),
            isFullWidth: true,
          ),
        ],
      ),
    );
  }

  void _openRevisionForm(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ClearanceFormScreen(
          type: application.type,
          agentName: application.agentName,
          existingApplication: application,
          initialLanguage: initialLanguage,
        ),
      ),
    );
  }

  Widget _buildFileItem(BuildContext context, String label, String? fileUrl) {
    final screenWidth = MediaQuery.of(context).size.width;
    final resolvedFileUrl = fileUrl ?? '';
    final hasFile = resolvedFileUrl.isNotEmpty;
    final displayName = hasFile ? getFileNameFromUrl(resolvedFileUrl) : '';
    final isPdf = hasFile && displayName.toLowerCase().endsWith('.pdf');
    return Padding(
      padding: EdgeInsets.only(bottom: AppTheme.spacing12),
      child: Row(
        children: [
          Container(
            width: screenWidth > 600 ? 40.0 : screenWidth * 0.1,
            height: screenWidth > 600 ? 40.0 : screenWidth * 0.1,
            decoration: BoxDecoration(
              color: hasFile
                  ? (isPdf
                        ? AppTheme.errorColor.withAlpha(25)
                        : AppTheme.primaryColor.withAlpha(25))
                  : AppTheme.greyShade200,
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
            child: Icon(
              hasFile
                  ? (isPdf ? Icons.picture_as_pdf : Icons.image)
                  : Icons.insert_drive_file,
              color: hasFile
                  ? (isPdf ? AppTheme.errorColor : AppTheme.primaryColor)
                  : AppTheme.greyShade500,
              size: screenWidth > 600 ? 20.0 : screenWidth * 0.05,
            ),
          ),
          SizedBox(width: AppTheme.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.onSurface,
                    fontFamily: 'Poppins',
                    fontSize: AppTheme.fontSizeBody2,
                  ),
                ),
                Text(
                  hasFile
                      ? AppLocalizations.of(
                          context,
                        ).get('submissionDetail.file_status_uploaded')
                      : AppLocalizations.of(
                          context,
                        ).get('submissionDetail.file_status_missing'),
                  style: TextStyle(
                    color: AppTheme.subtitleColor,
                    fontFamily: 'Poppins',
                    fontSize: AppTheme.fontSizeBody2,
                  ),
                ),
              ],
            ),
          ),
          if (hasFile)
            IconButton(
              onPressed: () async {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Downloading file...')));

                try {
                  final authService = AuthService();
                  final fileData = await authService.downloadFileData(
                    resolvedFileUrl,
                  );

                  if (fileData != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DocumentViewScreen(
                          fileData: fileData,
                          fileName: displayName,
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
              },
              icon: Icon(
                Icons.visibility,
                color: AppTheme.primaryColor,
                size: screenWidth > 600 ? 20.0 : screenWidth * 0.05,
              ),
            ),
        ],
      ),
    );
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

  String _getStatusText(ApplicationStatus status, BuildContext context) {
    switch (status) {
      case ApplicationStatus.waiting:
        return 'Waiting';
      case ApplicationStatus.approved:
        return 'Approved';
      case ApplicationStatus.revision:
        return 'Revision';
      case ApplicationStatus.declined:
        return 'Declined';
    }
  }
}
