import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../../../config/routes.dart';
import '../../../config/theme.dart';
import '../../../localization/app_localizations.dart';
import '../../../models/clearance_application.dart';
import '../../../services/logging_service.dart';
import '../../widgets/custom_app_bar.dart';
import 'package:url_launcher/url_launcher.dart';

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
    LoggingService().info(
      'Building ClearanceResultScreen for application: ${application.id}, status: ${application.status}',
    );

    String tr(String key) =>
        AppLocalizations.of(context).get('clearanceResult.$key');
    final isArrival = application.type == ApplicationType.kedatangan;
    final appName = AppLocalizations.of(context).get('splash.app_name');
    final createdAtLocal = application.createdAt.toLocal();
    final submittedAtText = DateFormat(
      'dd MMM yyyy HH:mm',
    ).format(createdAtLocal);
    final certificateGeneratedAtLocal = application.clearanceResultGeneratedAt
        ?.toLocal();
    final certificateGeneratedAtText = certificateGeneratedAtLocal != null
        ? DateFormat('dd MMM yyyy HH:mm').format(certificateGeneratedAtLocal)
        : null;
    final clearanceSentAtLocal = application.clearanceResultSentAt?.toLocal();
    final clearanceSentAtText = clearanceSentAtLocal != null
        ? DateFormat('dd MMM yyyy HH:mm').format(clearanceSentAtLocal)
        : null;
    final notProvided = tr('not_provided');

    String cleanValue(String? raw) {
      if (raw == null) return notProvided;
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return notProvided;
      const invalidTokens = {
        'n/a',
        'na',
        'n.a',
        'not available',
        'tidak tersedia',
        '-',
      };
      return invalidTokens.contains(trimmed.toLowerCase())
          ? notProvided
          : trimmed;
    }

    String formatLocation(String? location) => cleanValue(location);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: CustomAppBar(
        title: LogoTitle(text: appName),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
        centerTitle: false,
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
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.tertiary.withAlpha(25),
                          Theme.of(context).colorScheme.tertiary.withAlpha(12),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(
                            context,
                          ).colorScheme.tertiary.withAlpha(25),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.check_circle,
                      color: Theme.of(context).colorScheme.tertiary,
                      size: 64,
                    ),
                  ),
                  SizedBox(height: AppTheme.spacing16),
                  Text(
                    tr('application_submitted'),
                    style: TextStyle(
                      fontSize: AppTheme.fontSizeH5,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.tertiary,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  SizedBox(height: AppTheme.spacing8),
                  Text(
                    '${tr('application_id_label')}:',
                    style: TextStyle(
                      fontSize: AppTheme.fontSizeBody1,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  SizedBox(height: AppTheme.spacing4),
                  SelectableText(
                    application.id,
                    style: TextStyle(
                      fontSize: AppTheme.fontSizeBody1,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.tertiary,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: AppTheme.spacing32),

            // Clearance metadata overview
            Container(
              margin: EdgeInsets.only(bottom: AppTheme.spacing24),
              padding: EdgeInsets.all(AppTheme.spacing16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.shadow.withAlpha(25),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('overview_title'),
                    style: TextStyle(
                      fontSize: AppTheme.fontSizeBody1,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurface,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  SizedBox(height: AppTheme.spacing12),
                  Wrap(
                    spacing: AppTheme.spacing12,
                    runSpacing: AppTheme.spacing12,
                    children: [
                      _buildMetaChip(
                        context,
                        label: tr('type'),
                        value: isArrival ? tr('arrival') : tr('departure'),
                        icon: Icons.swap_horiz,
                      ),
                      _buildMetaChip(
                        context,
                        label: tr('status'),
                        value: _getStatusText(application.status, tr),
                        color: _getStatusColor(context, application.status),
                        icon: _getStatusIcon(application.status),
                      ),
                      _buildMetaChip(
                        context,
                        label: tr('location'),
                        value: formatLocation(application.location),
                        icon: Icons.place_outlined,
                      ),
                      if (application.clearanceCode != null &&
                          application.clearanceCode!.isNotEmpty)
                        _buildMetaChip(
                          context,
                          label: tr('clearance_code'),
                          value: application.clearanceCode!,
                          icon: Icons.qr_code,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      _buildMetaChip(
                        context,
                        label: tr('submitted_at'),
                        value: submittedAtText,
                        icon: Icons.access_time,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Application Details Card
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.surface,
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.shadow.withAlpha(25),
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
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withAlpha(25),
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusSmall,
                            ),
                          ),
                          child: Icon(
                            Icons.description,
                            color: Theme.of(context).colorScheme.primary,
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
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: AppTheme.spacing16),

                    // Ship Information
                    _buildDetailRow(
                      context,
                      tr('agent'),
                      application.agentName,
                    ),
                    _buildDetailRow(
                      context,
                      tr('ship_name'),
                      application.shipName,
                    ),
                    _buildDetailRow(context, tr('flag'), application.flag),
                    _buildDetailRow(
                      context,
                      tr('type'),
                      isArrival ? tr('arrival') : tr('departure'),
                    ),

                    _buildDetailRow(
                      context,
                      isArrival ? tr('last_port') : tr('next_port'),
                      cleanValue(application.port),
                    ),

                    if (application.date != null)
                      _buildDetailRow(context, tr('date'), application.date!),

                    // Crew Information
                    if (application.wniCrew != null)
                      _buildDetailRow(
                        context,
                        tr('wni_crew'),
                        application.wniCrew!,
                      ),

                    if (application.wnaCrew != null)
                      _buildDetailRow(
                        context,
                        tr('wna_crew'),
                        application.wnaCrew!,
                      ),

                    // Officer Information
                    if (application.officerName != null)
                      _buildDetailRow(
                        context,
                        tr('officer_name'),
                        cleanValue(application.officerName),
                      ),

                    if (application.clearanceResultSignedBy != null)
                      _buildDetailRow(
                        context,
                        tr('certificate_signed_by'),
                        cleanValue(application.clearanceResultSignedBy),
                      ),

                    if (application.clearanceResultSignedByCorporate != null)
                      _buildDetailRow(
                        context,
                        tr('certificate_signed_by_corporate'),
                        cleanValue(
                          application.clearanceResultSignedByCorporate,
                        ),
                      ),

                    if (certificateGeneratedAtText != null)
                      _buildDetailRow(
                        context,
                        tr('certificate_generated_at'),
                        certificateGeneratedAtText,
                      ),

                    if (application.clearanceCode != null &&
                        application.clearanceCode!.isNotEmpty)
                      _buildDetailRow(
                        context,
                        tr('clearance_code'),
                        application.clearanceCode!,
                      ),

                    if (clearanceSentAtText != null)
                      _buildDetailRow(
                        context,
                        tr('clearance_sent_at'),
                        clearanceSentAtText,
                      ),

                    _buildDetailRow(
                      context,
                      tr('location'),
                      formatLocation(application.location),
                    ),

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
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
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
                              color: _getStatusColor(
                                context,
                                application.status,
                              ).withAlpha(25),
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusLarge,
                              ),
                              border: Border.all(
                                color: _getStatusColor(
                                  context,
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
                                  color: _getStatusColor(
                                    context,
                                    application.status,
                                  ),
                                  size: 16,
                                ),
                                SizedBox(width: AppTheme.spacing4),
                                Text(
                                  _getStatusText(application.status, tr),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: _getStatusColor(
                                      context,
                                      application.status,
                                    ),
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
                    if (application.notes != null &&
                        application.notes!.isNotEmpty)
                      _buildDetailRow(context, tr('notes'), application.notes!)
                    else
                      _buildDetailRow(context, tr('notes'), tr('no_notes')),

                    // Submitted At
                    _buildDetailRow(
                      context,
                      tr('submitted_at'),
                      submittedAtText,
                    ),

                    // File attachments section
                    SizedBox(height: AppTheme.spacing16),
                    Text(
                      tr('attached_documents'),
                      style: TextStyle(
                        fontSize: AppTheme.fontSizeBody1,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Poppins',
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    SizedBox(height: AppTheme.spacing12),
                    ..._buildFileWidgets(application, tr, context),
                  ],
                ),
              ),
            ),

            SizedBox(height: AppTheme.spacing32),

            // Action Buttons
            Container(
              padding: EdgeInsets.all(AppTheme.spacing16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.shadow.withAlpha(25),
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
                                Theme.of(
                                  context,
                                ).colorScheme.primary.withAlpha(25),
                                Theme.of(
                                  context,
                                ).colorScheme.primary.withAlpha(12),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusMedium,
                            ),
                            border: Border.all(
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withAlpha(51),
                              width: 1,
                            ),
                          ),
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.symmetric(
                                vertical: AppTheme.spacing16,
                              ),
                              backgroundColor: Colors.transparent,
                              side: BorderSide.none,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radiusMedium,
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.home,
                                  color: Theme.of(context).colorScheme.primary,
                                  size: 20,
                                ),
                                SizedBox(width: AppTheme.spacing8),
                                Text(
                                  tr('back_to_home'),
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
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
                                  Theme.of(context).colorScheme.tertiary,
                                  Theme.of(
                                    context,
                                  ).colorScheme.tertiary.withAlpha(204),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusMedium,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.tertiary.withAlpha(51),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.pushNamed(
                                  context,
                                  AppRoutes.officerReport,
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                padding: EdgeInsets.symmetric(
                                  vertical: AppTheme.spacing16,
                                ),
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusMedium,
                                  ),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.description,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onPrimary,
                                    size: 20,
                                  ),
                                  SizedBox(width: AppTheme.spacing8),
                                  Text(
                                    tr('view_reports'),
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onPrimary,
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
                                  Theme.of(context).colorScheme.secondary,
                                  Theme.of(
                                    context,
                                  ).colorScheme.secondary.withAlpha(204),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusMedium,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.secondary.withAlpha(51),
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
                                padding: EdgeInsets.symmetric(
                                  vertical: AppTheme.spacing16,
                                ),
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusMedium,
                                  ),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.edit,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onPrimary,
                                    size: 20,
                                  ),
                                  SizedBox(width: AppTheme.spacing8),
                                  Text(
                                    tr('edit_application'),
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onPrimary,
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

  Widget _buildMetaChip(
    BuildContext context, {
    required String label,
    required String value,
    Color? color,
    IconData? icon,
  }) {
    final resolvedColor = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppTheme.spacing16,
        vertical: AppTheme.spacing8,
      ),
      decoration: BoxDecoration(
        color: resolvedColor.withAlpha(25),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: resolvedColor.withAlpha(51)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: resolvedColor),
                SizedBox(width: AppTheme.spacing4),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: AppTheme.fontSizeBody2,
                  fontWeight: FontWeight.w500,
                  color: resolvedColor.withAlpha(179),
                  fontFamily: 'Poppins',
                ),
              ),
            ],
          ),
          SizedBox(height: AppTheme.spacing4),
          Text(
            value,
            style: TextStyle(
              fontSize: AppTheme.fontSizeBody1,
              fontWeight: FontWeight.w600,
              color: resolvedColor,
              fontFamily: 'Poppins',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value) {
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
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontFamily: 'Poppins',
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurface,
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

  Color _getStatusColor(BuildContext context, ApplicationStatus status) {
    switch (status) {
      case ApplicationStatus.waiting:
        return Theme.of(context).colorScheme.primary;
      case ApplicationStatus.approved:
        return Theme.of(context).colorScheme.tertiary;
      case ApplicationStatus.revision:
        return Theme.of(context).colorScheme.secondary;
      case ApplicationStatus.declined:
        return Theme.of(context).colorScheme.error;
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

  String _extractFilename(String fileName) {
    try {
      return Uri.parse(fileName).pathSegments.last;
    } catch (e) {
      return fileName.split('/').last;
    }
  }

  Widget _buildFileCard(String label, String? fileUrl, BuildContext context) {
    final theme = Theme.of(context);
    final resolvedFileUrl = fileUrl ?? '';
    final hasFile = resolvedFileUrl.isNotEmpty;
    final filename = hasFile ? _extractFilename(resolvedFileUrl) : '';
    final isPdf = hasFile && filename.toLowerCase().endsWith('.pdf');

    return Container(
      margin: EdgeInsets.only(bottom: AppTheme.spacing12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withAlpha(25),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: hasFile
                ? (isPdf
                      ? theme.colorScheme.error.withAlpha(25)
                      : theme.colorScheme.primary.withAlpha(25))
                : theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          ),
          child: Icon(
            hasFile
                ? (isPdf ? Icons.picture_as_pdf : Icons.image)
                : Icons.insert_drive_file,
            color: hasFile
                ? (isPdf ? theme.colorScheme.error : theme.colorScheme.primary)
                : theme.colorScheme.onSurfaceVariant,
            size: 20,
          ),
        ),
        title: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
            fontFamily: 'Poppins',
            fontSize: AppTheme.fontSizeBody1,
          ),
        ),
        subtitle: Text(
          AppLocalizations.of(context).get(
            hasFile
                ? 'submissionDetail.file_status_uploaded'
                : 'submissionDetail.file_status_missing',
          ),
          style: TextStyle(
            color: theme.colorScheme.onSurfaceVariant,
            fontFamily: 'Poppins',
            fontSize: AppTheme.fontSizeBody2,
          ),
        ),
        trailing: hasFile
            ? IconButton(
                onPressed: () async {
                  final l10n = AppLocalizations.of(context);
                  if (kIsWeb) {
                    final uri = Uri.tryParse(resolvedFileUrl);
                    if (uri != null) {
                      final launched = await launchUrl(
                        uri,
                        webOnlyWindowName: '_blank',
                      );
                      if (!launched) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              l10n.get('clearanceForm.download_failed'),
                            ),
                          ),
                        );
                      }
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            l10n.get('clearanceForm.download_failed'),
                          ),
                        ),
                      );
                    }
                    return;
                  }

                  final uri = Uri.tryParse(resolvedFileUrl);
                  if (uri != null &&
                      (uri.scheme == 'http' || uri.scheme == 'https')) {
                    final launched = await launchUrl(
                      uri,
                      mode: LaunchMode.externalApplication,
                    );
                    if (!launched && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            l10n.get('clearanceForm.download_failed'),
                          ),
                        ),
                      );
                    }
                    return;
                  }

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(l10n.get('clearanceForm.download_failed')),
                    ),
                  );
                },
                icon: Icon(
                  Icons.visibility,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
              )
            : null,
      ),
    );
  }

  List<Widget> _buildFileWidgets(
    ClearanceApplication application,
    String Function(String) tr,
    BuildContext context,
  ) {
    final widgets = <Widget>[];

    final certificateDownloadUrl = (application.shortLink != null &&
            application.shortLink!.trim().isNotEmpty)
        ? application.shortLink!.trim()
        : (application.clearanceResultFile ?? '').trim();
    final certificateAvailable =
        certificateDownloadUrl.isNotEmpty &&
        application.clearanceResultSentAt != null;

    if (certificateAvailable) {
      widgets.add(
        _buildFileCard(
          tr('clearance_certificate'),
          certificateDownloadUrl,
          context,
        ),
      );
    } else if (application.status == ApplicationStatus.approved) {
      widgets.add(_buildPendingClearanceCard(context));
    }

    final portFiles = application.portClearanceFiles;
    if (portFiles.isEmpty) {
      widgets.add(_buildFileCard(tr('port_clearance'), null, context));
    } else {
      widgets.addAll(
        portFiles.asMap().entries.map(
          (entry) => _buildFileCard(
            portFiles.length > 1
                ? '${tr('port_clearance')} #${entry.key + 1}'
                : tr('port_clearance'),
            entry.value,
            context,
          ),
        ),
      );
    }

    if (application.crewListFiles.isEmpty) {
      widgets.add(_buildFileCard(tr('crew_list'), null, context));
    } else {
      widgets.addAll(
        application.crewListFiles.asMap().entries.map(
          (entry) => _buildFileCard(
            application.crewListFiles.length > 1
                ? '${tr('crew_list')} #${entry.key + 1}'
                : tr('crew_list'),
            entry.value,
            context,
          ),
        ),
      );
    }

    final notificationFiles = application.notificationLetterFiles;
    if (notificationFiles.isEmpty) {
      widgets.add(_buildFileCard(tr('notification_letter'), null, context));
    } else {
      widgets.addAll(
        notificationFiles.asMap().entries.map(
          (entry) => _buildFileCard(
            notificationFiles.length > 1
                ? '${tr('notification_letter')} #${entry.key + 1}'
                : tr('notification_letter'),
            entry.value,
            context,
          ),
        ),
      );
    }

    return widgets;
  }

  Widget _buildPendingClearanceCard(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: EdgeInsets.only(bottom: AppTheme.spacing12),
      padding: EdgeInsets.all(AppTheme.spacing16),
      decoration: BoxDecoration(
        color: colorScheme.error.withAlpha(25),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: colorScheme.error.withAlpha(80)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: colorScheme.error, size: 24),
          SizedBox(width: AppTheme.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.get('clearanceResult.clearance_pending_title'),
                  style: TextStyle(
                    fontSize: AppTheme.fontSizeBody1,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.error,
                    fontFamily: 'Poppins',
                  ),
                ),
                SizedBox(height: AppTheme.spacing8),
                Text(
                  l10n.get('clearanceResult.clearance_pending_message'),
                  style: TextStyle(
                    fontSize: AppTheme.fontSizeBody2,
                    color: colorScheme.onSurface,
                    fontFamily: 'Poppins',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
