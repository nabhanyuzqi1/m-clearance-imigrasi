import 'package:flutter/material.dart';
import '../../../config/theme.dart';
import '../../../models/clearance_application.dart';
import '../../../localization/app_strings.dart';
import '../../../localization/app_localizations.dart';
import '../../../services/logging_service.dart';
import '../../../services/auth_service.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/attachment_status_tile.dart';
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

            _buildAttachmentsSection(context),

            SizedBox(height: AppTheme.spacing24),

            if (application.status == ApplicationStatus.approved &&
                application.clearanceResultFile != null &&
                application.clearanceResultFile!.isNotEmpty)
              _buildDownloadCertificateCard(context),

            if (application.status == ApplicationStatus.approved &&
                application.clearanceResultFile != null &&
                application.clearanceResultFile!.isNotEmpty)
              SizedBox(height: AppTheme.spacing24),

            if (application.status == ApplicationStatus.revision)
              _buildRevisionBanner(context),

            if (application.status == ApplicationStatus.revision)
              SizedBox(height: AppTheme.spacing24),
            SizedBox(height: AppTheme.spacing32),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentsSection(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
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
                color: AppTheme.secondaryColor,
                size: 22,
              ),
              SizedBox(width: AppTheme.spacing12),
              Text(
                l10n.get('clearanceResult.attached_documents'),
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
          AttachmentStatusTile(
            label: l10n.get('submissionDetail.port_clearance'),
            fileUrls: application.portClearanceFiles,
            onViewFile: _openDocument,
          ),
          AttachmentStatusTile(
            label: l10n.get('submissionDetail.crew_list'),
            fileUrls: application.crewListFiles,
            onViewFile: _openDocument,
          ),
          AttachmentStatusTile(
            label: l10n.get('submissionDetail.notification_letter'),
            fileUrls: application.notificationLetterFiles,
            onViewFile: _openDocument,
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadCertificateCard(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final certificateUrl = application.clearanceResultFile;
    if (certificateUrl == null || certificateUrl.isEmpty) {
      return const SizedBox.shrink();
    }

    final subtitleKey = application.type == ApplicationType.kedatangan
        ? 'clearanceResult.approved_subtitle_arrival'
        : 'clearanceResult.approved_subtitle_departure';

    return Container(
      padding: EdgeInsets.all(AppTheme.spacing16),
      decoration: BoxDecoration(
        color: AppTheme.whiteColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: [
          BoxShadow(
            color: AppTheme.secondaryColor.withAlpha(25),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.get('clearanceResult.clearance_certificate'),
            style: TextStyle(
              fontSize: AppTheme.fontSizeH6,
              fontWeight: FontWeight.bold,
              color: AppTheme.onSurface,
              fontFamily: 'Poppins',
            ),
          ),
          SizedBox(height: AppTheme.spacing8),
          Text(
            l10n.get(subtitleKey),
            style: TextStyle(
              fontSize: AppTheme.fontSizeBody2,
              color: AppTheme.subtitleColor,
              fontFamily: 'Poppins',
            ),
          ),
          SizedBox(height: AppTheme.spacing12),
          CustomButton(
            text: l10n.get('clearanceResult.download_certificate'),
            type: CustomButtonType.elevated,
            backgroundColor: AppTheme.secondaryColor,
            onPressed: () => _openDocument(context, certificateUrl),
            isFullWidth: true,
          ),
        ],
      ),
    );
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

  Future<void> _openDocument(BuildContext context, String fileUrl) async {
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.get('clearanceForm.download_start'))),
    );

    try {
      final authService = AuthService();
      final fileData = await authService.downloadFileData(fileUrl);

      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      if (fileData != null) {
        final fileName = getFileNameFromUrl(fileUrl);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                DocumentViewScreen(fileData: fileData, fileName: fileName),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.get('clearanceForm.download_failed'))),
        );
      }
    } catch (e) {
      LoggingService().error('Error downloading file: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.get('clearanceForm.download_failed'))),
      );
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
