import 'package:flutter/material.dart';
import '../../../config/theme.dart';
import '../../../models/clearance_application.dart';
import '../../../localization/app_strings.dart';
import '../../../services/logging_service.dart';
import '../../../services/functions_service.dart';
import '../../../services/auth_service.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/custom_button.dart';
import 'document_view_screen.dart';

class DepartureDetailScreen extends StatelessWidget {
  final ClearanceApplication application;
  final String initialLanguage;

  const DepartureDetailScreen({
    super.key,
    required this.application,
    required this.initialLanguage,
  });

  String _tr(BuildContext context, String key) => AppStrings.tr(
        context: context,
        screenKey: 'userHistory',
        stringKey: key,
        langCode: initialLanguage,
      );

  String _extractFileName(String filePath) {
    try {
      // Handle both full URLs and simple file names
      if (filePath.contains('/')) {
        return filePath.split('/').last;
      } else if (filePath.contains('%2F')) {
        // Handle URL-encoded paths
        final decoded = Uri.decodeComponent(filePath);
        return decoded.split('/').last;
      } else {
        return filePath;
      }
    } catch (e) {
      LoggingService().error('Error extracting file name from: $filePath', e);
      return 'Unknown File';
    }
  }

  @override
  Widget build(BuildContext context) {
    LoggingService().debug('Building DepartureDetailScreen for application: ${application.id}');
    return Scaffold(
      backgroundColor: AppTheme.greyShade50,
      appBar: CustomAppBar(
        titleText: _tr(context, 'departure_detail'),
        backgroundColor: AppTheme.whiteColor,
        foregroundColor: AppTheme.blackColor,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(AppTheme.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Application Header
            Container(
              padding: EdgeInsets.all(AppTheme.spacing16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.secondaryColor, (AppTheme.secondaryColor).withAlpha(204)],
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
                      size: 32,
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
                        size: 24,
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
                        size: 24,
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
                  _buildDetailItem(context, 'Next Port', application.port ?? 'N/A'),
                  _buildDetailItem(context, 'ETD', application.date ?? 'N/A'),
                  _buildDetailItem(context, 'WNI Crew', application.wniCrew?.toString() ?? '0'),
                  _buildDetailItem(context, 'WNA Crew', application.wnaCrew?.toString() ?? '0'),
                  _buildDetailItem(context, 'Agent', application.agentName),
                  _buildDetailItem(context, 'Location', application.location ?? 'N/A'),
                  _buildDetailItem(context, 'Submitted At', '${application.createdAt.day}/${application.createdAt.month}/${application.createdAt.year} ${application.createdAt.hour}:${application.createdAt.minute.toString().padLeft(2, '0')}'),
                  if (application.officerName != null)
                    _buildDetailItem(context, 'Reviewed By', application.officerName!),
                  if (application.notes != null && application.notes!.isNotEmpty)
                    _buildDetailItem(context, 'Officer Notes', application.notes!),
                ],
              ),
            ),

            SizedBox(height: AppTheme.spacing24),

            // File Attachments
            if ((application.portClearanceFile?.isNotEmpty ?? false) ||
                (application.crewListFile?.isNotEmpty ?? false) ||
                (application.notificationLetterFile?.isNotEmpty ?? false))
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
                          size: 24,
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
                    if (application.portClearanceFile?.isNotEmpty ?? false)
                      _buildFileItem(context, 'Port Clearance', application.portClearanceFile!),
                    if (application.crewListFile?.isNotEmpty ?? false)
                      _buildFileItem(context, 'Crew List', application.crewListFile!),
                    if (application.notificationLetterFile?.isNotEmpty ?? false)
                      _buildFileItem(context, 'Notification Letter', application.notificationLetterFile!),
                  ],
                ),
              ),

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
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(color: AppTheme.primaryColor),
                SizedBox(width: AppTheme.spacing16),
                Text('Generating PDF...'),
              ],
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Downloading PDF...')),
        );

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
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to download PDF')),
            );
          }
        } catch (e) {
          LoggingService().error('Error downloading PDF: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error downloading PDF')),
          );
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
    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppTheme.spacing8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Poppins', color: AppTheme.onSurface),
            ),
          ),
          SizedBox(width: AppTheme.spacing16),
          Expanded(
            child: Text(value, style: TextStyle(fontFamily: 'Poppins', color: AppTheme.onSurface)),
          ),
        ],
      ),
    );
  }

  Widget _buildFileItem(BuildContext context, String label, String fileName) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppTheme.spacing12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
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
              size: 20,
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
                  _extractFileName(fileName),
                  style: TextStyle(
                    color: AppTheme.subtitleColor,
                    fontFamily: 'Poppins',
                    fontSize: AppTheme.fontSizeBody2,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () async {
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
                        fileName: _extractFileName(fileName),
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
              size: 20,
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