import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../../config/theme.dart';
import '../../../models/clearance_application.dart';
import '../../../localization/app_localizations.dart';
import '../../../services/logging_service.dart';
import '../../../services/auth_service.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../widgets/custom_app_bar.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/attachment_status_tile.dart';
import 'document_view_screen.dart';
import '../../../utils/file_utils.dart';
import 'clearance_form_screen.dart';

class ArrivalDetailScreen extends StatelessWidget {
  final ClearanceApplication application;
  final String initialLanguage;

  const ArrivalDetailScreen({
    super.key,
    required this.application,
    required this.initialLanguage,
  });

  String _tr(BuildContext context, String key) =>
      AppLocalizations.of(context).get('userHistory.$key');

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
      'Building ArrivalDetailScreen for application: ${application.id}',
    );
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final responsivePadding = screenWidth > 600
        ? AppTheme.spacing16
        : screenWidth * 0.04;
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final l10n = AppLocalizations.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color cardColor =
        isDark ? colorScheme.surfaceContainerHigh : colorScheme.surface;
    final Color elevatedCardColor =
        isDark ? colorScheme.surfaceContainerHighest : colorScheme.surface;
    final Color subtleShadow = colorScheme.shadow.withValues(
      alpha: isDark ? 0.32 : 0.12,
    );
    final Color headerOverlay = colorScheme.onPrimary.withValues(
      alpha: isDark ? 0.2 : 0.14,
    );
    final Color headerGradientStart = isDark
        ? colorScheme.primaryContainer
        : colorScheme.primary.withValues(alpha: 0.92);
    final Color headerGradientEnd = colorScheme.primary;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: CustomAppBar(
        titleText: _tr(context, 'arrival_detail'),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
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
                    headerGradientStart,
                    headerGradientEnd,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                boxShadow: [
                  BoxShadow(
                    color: subtleShadow,
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(AppTheme.spacing12),
                    decoration: BoxDecoration(
                      color: headerOverlay,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                    ),
                    child: Icon(
                      Icons.anchor,
                      color: colorScheme.onPrimary,
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
                        style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onPrimary,
                        ),
                      ),
                      SizedBox(height: AppTheme.spacing4),
                      Text(
                        '${l10n.get('clearanceResult.application_id_label')}: ${application.id}',
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onPrimary.withValues(alpha: 0.78),
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
                color: cardColor,
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                boxShadow: [
                  BoxShadow(
                    color: subtleShadow,
                    blurRadius: 16,
                    offset: const Offset(0, 8),
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
                        color: colorScheme.primary,
                        size: screenWidth > 600 ? 24.0 : screenWidth * 0.06,
                      ),
                      SizedBox(width: AppTheme.spacing12),
                      Text(
                        l10n.get('submissionDetail.application_status'),
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
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
                      color: _getStatusColor(context, application.status)
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                      border: Border.all(
                        color: _getStatusColor(context, application.status)
                            .withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getStatusIcon(application.status),
                          color: _getStatusColor(context, application.status),
                          size: screenWidth > 600 ? 16.0 : screenWidth * 0.04,
                        ),
                        SizedBox(width: AppTheme.spacing8),
                        Text(
                          _getStatusText(application.status, context),
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: _getStatusColor(context, application.status),
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
                color: elevatedCardColor,
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                boxShadow: [
                  BoxShadow(
                    color: subtleShadow,
                    blurRadius: 14,
                    offset: const Offset(0, 6),
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
                        color: colorScheme.primary,
                        size: screenWidth > 600 ? 24.0 : screenWidth * 0.06,
                      ),
                      SizedBox(width: AppTheme.spacing12),
                      Text(
                        l10n.get('submissionDetail.application_details'),
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: AppTheme.spacing16),
                  _buildDetailItem(
                    context,
                    l10n.get('submissionDetail.ship_name_label'),
                    application.shipName,
                  ),
                  _buildDetailItem(
                    context,
                    l10n.get('submissionDetail.flag_label'),
                    application.flag,
                  ),
                  _buildDetailItem(
                    context,
                    l10n.get('submissionDetail.last_port_label'),
                    _formatField(context, application.port),
                  ),
                  _buildDetailItem(
                    context,
                    l10n.get('submissionDetail.eta_label'),
                    _formatField(context, application.date),
                  ),
                  _buildDetailItem(
                    context,
                    l10n.get('submissionDetail.wni_crew_label'),
                    application.wniCrew?.toString() ?? '0',
                  ),
                  _buildDetailItem(
                    context,
                    l10n.get('submissionDetail.wna_crew_label'),
                    application.wnaCrew?.toString() ?? '0',
                  ),
                  _buildDetailItem(
                    context,
                    l10n.get('submissionDetail.agent_label'),
                    application.agentName,
                  ),
                  _buildDetailItem(
                    context,
                    l10n.get('submissionDetail.location_label'),
                    _formatLocation(context, application.location),
                  ),
                  _buildDetailItem(
                    context,
                    l10n.get('submissionDetail.submitted_at_label'),
                    '${application.createdAt.day}/${application.createdAt.month}/${application.createdAt.year} ${application.createdAt.hour}:${application.createdAt.minute.toString().padLeft(2, '0')}',
                  ),
                  if (application.officerName != null)
                    _buildDetailItem(
                      context,
                      l10n.get('submissionDetail.reviewed_by_label'),
                      application.officerName!,
                    ),
                  if (application.notes != null &&
                      application.notes!.isNotEmpty)
                    _buildDetailItem(
                      context,
                      l10n.get('submissionDetail.officer_notes_label'),
                      application.notes!,
                    ),
                ],
              ),
            ),

            SizedBox(height: AppTheme.spacing24),

            _buildAttachmentsSection(
              context,
              colorScheme,
              subtleShadow,
              cardColor,
            ),

            SizedBox(height: AppTheme.spacing24),

            if (application.status == ApplicationStatus.approved)
              _buildDownloadCertificateCard(
                context,
                colorScheme,
                subtleShadow,
                cardColor,
              ),

            if (application.status == ApplicationStatus.approved)
              SizedBox(height: AppTheme.spacing24),

            if (application.status == ApplicationStatus.revision)
              _buildRevisionBanner(context, colorScheme),

            if (application.status == ApplicationStatus.revision)
              SizedBox(height: AppTheme.spacing24),
            SizedBox(height: AppTheme.spacing32),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentsSection(
    BuildContext context,
    ColorScheme colorScheme,
    Color subtleShadow,
    Color cardColor,
  ) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: EdgeInsets.all(AppTheme.spacing16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: [
          BoxShadow(
            color: subtleShadow,
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
                color: colorScheme.primary,
                size: 22,
              ),
              SizedBox(width: AppTheme.spacing12),
              Text(
                l10n.get('clearanceResult.attached_documents'),
                style: TextStyle(
                  fontSize: AppTheme.fontSizeH6,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
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

  Widget _buildDownloadCertificateCard(
    BuildContext context,
    ColorScheme colorScheme,
    Color subtleShadow,
    Color cardColor,
  ) {
    final l10n = AppLocalizations.of(context);
    final certificateUrl = application.shortLink != null &&
            application.shortLink!.trim().isNotEmpty
        ? application.shortLink!.trim()
        : (application.clearanceResultFile ?? '').trim();
    final certificateAvailable = certificateUrl.isNotEmpty &&
        application.clearanceResultSentAt != null;
    final subtitleKey = application.type == ApplicationType.kedatangan
        ? 'clearanceResult.approved_subtitle_arrival'
        : 'clearanceResult.approved_subtitle_departure';
    final sentAt = application.clearanceResultSentAt;
    final sentAtText = sentAt != null
        ? DateFormat('dd MMM yyyy HH:mm').format(sentAt.toLocal())
        : null;
    final clearanceCode = application.clearanceCode;

    return Container(
      padding: EdgeInsets.all(AppTheme.spacing16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.18),
            blurRadius: 12,
            offset: const Offset(0, 4),
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
              color: colorScheme.onSurface,
              fontFamily: 'Poppins',
            ),
          ),
          SizedBox(height: AppTheme.spacing8),
          Text(
            l10n.get(subtitleKey),
            style: TextStyle(
              fontSize: AppTheme.fontSizeBody2,
              color: colorScheme.onSurfaceVariant,
              fontFamily: 'Poppins',
            ),
          ),
          if (clearanceCode != null && clearanceCode.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: AppTheme.spacing12),
              child: _buildInfoRow(
                context,
                l10n.get('clearanceResult.clearance_code'),
                clearanceCode,
                colorScheme,
              ),
            ),
          if (sentAtText != null)
            Padding(
              padding: EdgeInsets.only(top: AppTheme.spacing8),
              child: _buildInfoRow(
                context,
                l10n.get('clearanceResult.clearance_sent_at'),
                sentAtText,
                colorScheme,
              ),
            ),
          if (!certificateAvailable)
            Padding(
              padding: EdgeInsets.only(top: AppTheme.spacing12),
              child: Text(
                l10n.get('clearanceResult.clearance_pending_message'),
                style: TextStyle(
                  fontSize: AppTheme.fontSizeBody2,
                  color: colorScheme.error,
                  fontFamily: 'Poppins',
                ),
              ),
            ),
          SizedBox(height: AppTheme.spacing12),
          CustomButton(
            text: l10n.get('clearanceResult.download_certificate'),
            type: CustomButtonType.elevated,
            backgroundColor: colorScheme.primary,
            onPressed:
                certificateAvailable
                    ? () => _openDocument(
                          context,
                          certificateUrl,
                          preferExternal: true,
                        )
                    : null,
            isFullWidth: true,
          ),
          if (!certificateAvailable)
            Padding(
              padding: EdgeInsets.only(top: AppTheme.spacing8),
              child: Text(
                l10n.get('clearanceResult.clearance_download_disabled'),
                style: TextStyle(
                  fontSize: AppTheme.fontSizeSmall,
                  color: colorScheme.onSurfaceVariant,
                  fontFamily: 'Poppins',
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    String label,
    String value,
    ColorScheme colorScheme,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            '$label:',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurfaceVariant,
              fontFamily: 'Poppins',
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
              fontFamily: 'Poppins',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailItem(BuildContext context, String label, String value) {
    final screenWidth = MediaQuery.of(context).size.width;
    final colorScheme = Theme.of(context).colorScheme;
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
                color: colorScheme.onSurface,
              ),
            ),
          ),
          SizedBox(width: AppTheme.spacing16),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontFamily: 'Poppins',
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRevisionBanner(
    BuildContext context,
    ColorScheme colorScheme,
  ) {
    return Container(
      padding: EdgeInsets.all(AppTheme.spacing16),
      decoration: BoxDecoration(
        color: colorScheme.secondary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(
          color: colorScheme.secondary.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _tr(context, 'revision_banner_title'),
            style: TextStyle(
              fontSize: AppTheme.fontSizeH6,
              fontWeight: FontWeight.bold,
              color: colorScheme.secondary,
              fontFamily: 'Poppins',
            ),
          ),
          SizedBox(height: AppTheme.spacing8),
          Text(
            _tr(context, 'revision_banner_body'),
            style: TextStyle(
              fontSize: AppTheme.fontSizeBody2,
              color: colorScheme.onSurfaceVariant,
              fontFamily: 'Poppins',
            ),
          ),
          SizedBox(height: AppTheme.spacing16),
          CustomButton(
            text: _tr(context, 'revision_button'),
            type: CustomButtonType.elevated,
            backgroundColor: colorScheme.primary,
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

  Future<void> _openDocument(
    BuildContext context,
    String fileUrl, {
    bool preferExternal = false,
  }) async {
    final l10n = AppLocalizations.of(context);
    final trimmedUrl = fileUrl.trim();
    final uri = Uri.tryParse(trimmedUrl);
    final openExternally =
        preferExternal && _shouldOpenExternally(trimmedUrl);

    Future<void> showFailure() async {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.get('clearanceForm.download_failed'))),
      );
    }

    if (kIsWeb) {
      if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
        final launched = await launchUrl(uri, webOnlyWindowName: '_blank');
        if (!launched) {
          await showFailure();
        }
      } else {
        await showFailure();
      }
      return;
    }

    if (openExternally) {
      if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        if (!launched) {
          await showFailure();
        }
      } else {
        await showFailure();
      }
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.get('clearanceForm.download_start'))),
    );

    try {
      final authService = AuthService();
      final fileData = await authService.downloadFileData(trimmedUrl);

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      if (fileData != null) {
        final fileName = getFileNameFromUrl(trimmedUrl);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                DocumentViewScreen(fileData: fileData, fileName: fileName),
          ),
        );
      } else {
        final uriForFallback = Uri.tryParse(trimmedUrl);
        if (uriForFallback != null) {
          final launched = await launchUrl(
            uriForFallback,
            mode: LaunchMode.externalApplication,
          );
          if (launched) {
            return;
          }
        }
        await showFailure();
      }
    } catch (e) {
      LoggingService().error('Error downloading file: $e');
      await showFailure();
    }
  }

  bool _shouldOpenExternally(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return false;
    }
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') {
      return false;
    }
    final host = uri.host.toLowerCase();
    return host.contains('mclearanceisam.com');
  }

  Color _getStatusColor(BuildContext context, ApplicationStatus status) {
    final scheme = Theme.of(context).colorScheme;
    switch (status) {
      case ApplicationStatus.waiting:
        return scheme.primary;
      case ApplicationStatus.approved:
        return scheme.tertiary;
      case ApplicationStatus.revision:
        return scheme.secondary;
      case ApplicationStatus.declined:
        return scheme.error;
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
