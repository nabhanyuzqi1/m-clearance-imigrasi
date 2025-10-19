import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/theme.dart';
import '../../../localization/app_localizations.dart';
import '../../../models/clearance_application.dart';
import '../../../repositories/application_repository.dart';
import '../../../services/auth_service.dart';
import '../../../services/logging_service.dart';
import '../../../utils/file_utils.dart';
import '../../widgets/attachment_status_tile.dart';
import '../../widgets/bouncing_dots_loader.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/custom_button.dart';
import '../user/document_view_screen.dart';

class SubmissionDetailScreen extends StatefulWidget {
  final ClearanceApplication application;
  final String adminName;
  final String initialLanguage;

  const SubmissionDetailScreen({
    super.key,
    required this.application,
    required this.adminName,
    this.initialLanguage = 'EN',
  }) : super();

  @override
  State<SubmissionDetailScreen> createState() => _SubmissionDetailScreenState();
}

class _SubmissionDetailScreenState extends State<SubmissionDetailScreen> {
  bool _isProcessingAction = false;
  String? _processingMessageKey;
  late final ApplicationRepository repo;
  late final String appId;
  late ClearanceApplication _application;

  @override
  void initState() {
    super.initState();
    _application = widget.application;
    LoggingService().info(
      'SubmissionDetailScreen initialized for application: ${_application.id}, admin: ${widget.adminName}',
    );
    repo = ApplicationRepository();
    appId = _application.id;
  }

  Future<String?> _fetchOfficerCorporateName() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        return null;
      }
      final authService = AuthService();
      final userModel = await authService.getUserData(
        currentUser.uid,
        forceRefresh: true,
      );
      return userModel?.corporateName;
    } catch (e, stackTrace) {
      LoggingService().warning(
        'Unable to resolve officer corporate name',
        e,
        stackTrace,
      );
      return null;
    }
  }

  Future<void> _handleDecision({
    required String decision,
    String? note,
    required String logMessage,
    required String successMessageKey,
    required String processingKey,
  }) async {
    if (_isProcessingAction) return;

    final l10n = AppLocalizations.of(context);
    setState(() {
      _isProcessingAction = true;
      _processingMessageKey = processingKey;
    });

    try {
      final officerCorporateName = decision == 'approved'
          ? await _fetchOfficerCorporateName()
          : null;

      await repo.officerDecide(
        appId: appId,
        decision: decision,
        note: note,
        officerName: widget.adminName,
        officerCorporateName: officerCorporateName,
      );
      LoggingService().info(logMessage);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.get('submissionDetail.$successMessageKey')),
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      LoggingService().error(
        'Failed processing decision "$decision" for application $appId',
        e,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.get('submissionDetail.action_failed')),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingAction = false;
          _processingMessageKey = null;
        });
      }
    }
  }

  Future<void> _handleSendClearance() async {
    if (_isProcessingAction) return;
    final hasCertificate =
        _application.clearanceResultFile != null &&
        _application.clearanceResultFile!.isNotEmpty;
    if (!hasCertificate) {
      final warnL10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            warnL10n.get('submissionDetail.generate_clearance_first'),
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }
    final l10n = AppLocalizations.of(context);

    setState(() {
      _isProcessingAction = true;
      _processingMessageKey = 'processing_clearance';
    });

    try {
      final officerCorporateName =
          await _fetchOfficerCorporateName() ?? widget.adminName;
      final updatedApplication = await repo.sendClearanceCertificate(
        appId: appId,
        officerName: widget.adminName,
        officerCorporateName: officerCorporateName,
      );

      if (!mounted) return;
      setState(() {
        _application = updatedApplication;
        _isProcessingAction = false;
        _processingMessageKey = null;
      });

      // Show success message with short link info
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.get('submissionDetail.clearance_sent_success')),
          action: updatedApplication.shortLink != null
              ? SnackBarAction(
                  label: 'View Link',
                  onPressed: () =>
                      _showShortLinkDialog(updatedApplication.shortLink!),
                )
              : null,
        ),
      );
    } catch (e, stackTrace) {
      LoggingService().error(
        'Failed sending eClearance for application $appId',
        e,
        stackTrace,
      );
      if (!mounted) return;
      setState(() {
        _isProcessingAction = false;
        _processingMessageKey = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.get('submissionDetail.action_failed')),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _handleGenerateClearance() async {
    if (_isProcessingAction) return;
    final l10n = AppLocalizations.of(context);

    setState(() {
      _isProcessingAction = true;
      _processingMessageKey = 'processing_generate_clearance';
    });

    try {
      final officerCorporateName =
          await _fetchOfficerCorporateName() ?? widget.adminName;
      final updatedApplication =
          await repo.generateClearanceCertificate(
        appId: appId,
        officerName: widget.adminName,
        officerCorporateName: officerCorporateName,
      );

      if (!mounted) return;
      setState(() {
        _application = updatedApplication;
        _isProcessingAction = false;
        _processingMessageKey = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.get('submissionDetail.clearance_generated_success'),
          ),
        ),
      );
    } catch (e, stackTrace) {
      LoggingService().error(
        'Failed generating clearance document for application $appId',
        e,
        stackTrace,
      );
      if (!mounted) return;
      setState(() {
        _isProcessingAction = false;
        _processingMessageKey = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.get('submissionDetail.action_failed')),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _showShortLinkDialog(String shortLink) async {
    await showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: Text('Short Link Generated'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Share this link to access the clearance document:'),
              SizedBox(height: 16),
              SelectableText(
                shortLink,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              SizedBox(height: 16),
              Text('Anyone with this link can access the document directly.'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: Text('Close'),
            ),
            TextButton(
              onPressed: () {
                // Copy to clipboard functionality would go here
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Link copied to clipboard')),
                );
                Navigator.of(dialogCtx).pop();
              },
              child: Text('Copy Link'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDocumentList() {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        AttachmentStatusTile(
          label: l10n.get('submissionDetail.port_clearance'),
          fileUrls: _application.portClearanceFiles,
          onViewFile: (ctx, url) => _viewDocument(url),
        ),
        AttachmentStatusTile(
          label: l10n.get('submissionDetail.crew_list'),
          fileUrls: _application.crewListFiles,
          onViewFile: (ctx, url) => _viewDocument(url),
        ),
        AttachmentStatusTile(
          label: l10n.get('submissionDetail.notification_letter'),
          fileUrls: _application.notificationLetterFiles,
          onViewFile: (ctx, url) => _viewDocument(url),
        ),
      ],
    );
  }

  Future<void> _viewDocument(String filePath) async {
    try {
      // Show loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(
              context,
            ).get('submissionDetail.downloading_document'),
          ),
        ),
      );

      final authService = AuthService();
      final fileData = await authService.downloadFileData(filePath);

      if (!mounted) return;

      if (fileData != null) {
        final fileName = getFileNameFromUrl(filePath);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                DocumentViewScreen(fileData: fileData, fileName: fileName),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(
                context,
              ).get('submissionDetail.failed_to_download_document'),
            ),
          ),
        );
      }
    } catch (e) {
      LoggingService().error('Error viewing document: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(
              context,
            ).get('submissionDetail.error_viewing_document'),
          ),
        ),
      );
    }
  }

  Future<void> _downloadClearance(BuildContext context) async {
    final l10n = AppLocalizations.of(context);

    // Always prefer short link for download button - this is what the user wants
    final downloadUrl =
        _application.shortLink ?? _application.clearanceResultFile;

    if (downloadUrl == null || downloadUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.get('submissionDetail.failed_to_download_document'),
          ),
        ),
      );
      return;
    }

    // For web, always use the short link (which opens the web interface)
    if (kIsWeb) {
      final uri = Uri.tryParse(downloadUrl);
      if (uri != null) {
        final launched = await launchUrl(uri, webOnlyWindowName: '_blank');
        if (!launched && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                l10n.get('submissionDetail.failed_to_download_document'),
              ),
            ),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.get('submissionDetail.failed_to_download_document'),
            ),
          ),
        );
      }
      return;
    }

    // For mobile, check if it's a short link or direct URL
    if (downloadUrl.contains('mclearanceisam.com/s/')) {
      // It's a short link - open in browser/external app
      final uri = Uri.tryParse(downloadUrl);
      if (uri != null) {
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        if (!launched && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open document link')),
          );
        }
      }
    } else {
      // It's a direct file URL - use in-app viewer
      await _viewDocument(downloadUrl);
    }
  }

  String? _formatDisplayDate(DateTime? input) {
    if (input == null) return null;
    final local = input.toLocal();
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final day = local.day.toString().padLeft(2, '0');
    final month = months[local.month - 1];
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day $month ${local.year} $hour:$minute';
  }

  Widget _buildDetailItem(String label, String value) {
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
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          SizedBox(width: AppTheme.spacing16),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontFamily: 'Poppins',
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(ApplicationStatus status) {
    final colorScheme = Theme.of(context).colorScheme;
    switch (status) {
      case ApplicationStatus.waiting:
        return colorScheme.primary;
      case ApplicationStatus.approved:
        return colorScheme.primary;
      case ApplicationStatus.revision:
        return colorScheme.secondary;
      case ApplicationStatus.declined:
        return colorScheme.error;
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

  String _getStatusText(ApplicationStatus status) {
    switch (status) {
      case ApplicationStatus.waiting:
        return AppLocalizations.of(context).get('submissionDetail.waiting');
      case ApplicationStatus.approved:
        return AppLocalizations.of(context).get('submissionDetail.approved');
      case ApplicationStatus.revision:
        return AppLocalizations.of(context).get('submissionDetail.revision');
      case ApplicationStatus.declined:
        return AppLocalizations.of(context).get('submissionDetail.declined');
    }
  }

  Widget _buildDecisionSection(BuildContext context, String appId) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDarkMode = theme.brightness == Brightness.dark;
    final cardColor = isDarkMode
        ? colorScheme.surfaceContainerHigh
        : colorScheme.surface;
    final shadowColor = colorScheme.shadow.withValues(
      alpha: isDarkMode ? 0.45 : 0.18,
    );
    return Container(
      padding: EdgeInsets.all(AppTheme.spacing16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.get('submissionDetail.decision'),
            style: TextStyle(
              fontSize: AppTheme.fontSizeH6,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
              fontFamily: 'Poppins',
            ),
          ),
          SizedBox(height: AppTheme.spacing8),
          Text(
            l10n.get('submissionDetail.decision_hint'),
            style: TextStyle(
              fontSize: AppTheme.fontSizeBody2,
              color: colorScheme.onSurfaceVariant,
              fontFamily: 'Poppins',
            ),
          ),
          SizedBox(height: AppTheme.spacing16),
          CustomButton(
            text: l10n.get('submissionDetail.select_action'),
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            isFullWidth: true,
            leadingIcon: Icon(
              Icons.gavel_outlined,
              color: colorScheme.onPrimary,
            ),
            onPressed: _isProcessingAction
                ? null
                : () => _showDecisionSheet(appId),
          ),
        ],
      ),
    );
  }

  Widget _buildClearanceSection(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDarkMode = theme.brightness == Brightness.dark;
    final cardColor = isDarkMode
        ? colorScheme.surfaceContainerHigh
        : colorScheme.surface;
    final shadowColor = colorScheme.shadow.withValues(
      alpha: isDarkMode ? 0.45 : 0.18,
    );
    final hasCertificate =
        _application.clearanceResultFile != null &&
        _application.clearanceResultFile!.isNotEmpty;
    final clearanceCode = _application.clearanceCode;
    final sentAt = _application.clearanceResultSentAt;
    final sentAtText = _formatDisplayDate(sentAt);

    final infoText = hasCertificate
        ? l10n.get('submissionDetail.clearance_sent_hint')
        : l10n.get('submissionDetail.clearance_generate_hint');
    final buttonLabel = hasCertificate
        ? l10n.get('submissionDetail.resend_e_clearance')
        : l10n.get('submissionDetail.send_e_clearance');

    return Container(
      padding: EdgeInsets.all(AppTheme.spacing16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
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
                Icons.picture_as_pdf_outlined,
                color: colorScheme.primary,
                size: 24,
              ),
              SizedBox(width: AppTheme.spacing12),
              Text(
                l10n.get('submissionDetail.clearance_section_title'),
                style: TextStyle(
                  fontSize: AppTheme.fontSizeH6,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                  fontFamily: 'Poppins',
                ),
              ),
            ],
          ),
          SizedBox(height: AppTheme.spacing12),
          Text(
            infoText,
            style: TextStyle(
              fontSize: AppTheme.fontSizeBody2,
              color: colorScheme.onSurfaceVariant,
              fontFamily: 'Poppins',
            ),
          ),
          if (!hasCertificate) ...[
            SizedBox(height: AppTheme.spacing8),
            Text(
              l10n.get('submissionDetail.clearance_not_sent'),
              style: TextStyle(
                fontSize: AppTheme.fontSizeBody2,
                color: colorScheme.error,
                fontFamily: 'Poppins',
              ),
            ),
          ],
          if (hasCertificate && clearanceCode != null) ...[
            SizedBox(height: AppTheme.spacing12),
            _buildClearanceInfoRow(
              l10n.get('submissionDetail.clearance_code_label'),
              clearanceCode,
              colorScheme,
            ),
          ],
          if (hasCertificate && sentAtText != null) ...[
            _buildClearanceInfoRow(
              l10n.get('submissionDetail.clearance_sent_at'),
              sentAtText,
              colorScheme,
            ),
          ],
          if (hasCertificate && _application.shortLink != null) ...[
            _buildShortLinkInfoRow(
              l10n.get('submissionDetail.short_link_label'),
              _application.shortLink!,
              colorScheme,
            ),
          ],
          SizedBox(height: AppTheme.spacing16),
          Row(
            children: [
              Expanded(
                child: CustomButton(
                  text: l10n.get('submissionDetail.generate_clearance'),
                  type: CustomButtonType.outlined,
                  onPressed: _isProcessingAction ? null : _handleGenerateClearance,
                  isFullWidth: true,
                ),
              ),
              if (hasCertificate) ...[
                SizedBox(width: AppTheme.spacing12),
                Expanded(
                  child: CustomButton(
                    text: l10n.get('submissionDetail.download_clearance'),
                    type: CustomButtonType.outlined,
                    onPressed: () => _downloadClearance(context),
                    isFullWidth: true,
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: AppTheme.spacing12),
          CustomButton(
            text: buttonLabel,
            type: CustomButtonType.elevated,
            backgroundColor: colorScheme.primary,
            onPressed: (_isProcessingAction || !hasCertificate)
                ? null
                : _handleSendClearance,
            isFullWidth: true,
          ),
        ],
      ),
    );
  }

  Widget _buildClearanceInfoRow(
    String label,
    String value,
    ColorScheme colorScheme,
  ) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppTheme.spacing8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
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
      ),
    );
  }

  Widget _buildShortLinkInfoRow(
    String label,
    String shortLink,
    ColorScheme colorScheme,
  ) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: AppTheme.spacing8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurfaceVariant,
                fontFamily: 'Poppins',
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Expanded(
                  child: SelectableText(
                    shortLink,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.primary,
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.copy, size: 16, color: colorScheme.primary),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: shortLink));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          l10n.get('submissionDetail.short_link_copied'),
                        ),
                      ),
                    );
                  },
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showDecisionSheet(String appId) {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDecisionTile(
                icon: Icons.edit_outlined,
                color: Theme.of(context).colorScheme.secondary,
                title: l10n.get('submissionDetail.review_submission'),
                subtitle: l10n.get('submissionDetail.revision_notes_hint'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _onSelectRevision(appId);
                },
              ),
              _buildDecisionTile(
                icon: Icons.cancel_outlined,
                color: Theme.of(context).colorScheme.error,
                title: l10n.get('submissionDetail.reject_submission'),
                subtitle: l10n.get('submissionDetail.reason_label'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _onSelectDecline(appId);
                },
              ),
              _buildDecisionTile(
                icon: Icons.check_circle_outline,
                color: Theme.of(context).colorScheme.primary,
                title: l10n.get('submissionDetail.finish_verification'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _onSelectApprove(appId);
                },
              ),
              const SizedBox(height: AppTheme.spacing12),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDecisionTile({
    required IconData icon,
    required Color color,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.13),
        child: Icon(icon, color: color),
      ),
      title: Text(title),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: const TextStyle(fontSize: AppTheme.fontSizeSmall),
            )
          : null,
      onTap: onTap,
    );
  }

  Future<void> _onSelectRevision(String appId) async {
    final l10n = AppLocalizations.of(context);
    final reason = await _promptForReason(
      title: l10n.get('submissionDetail.review_submission'),
      hint: l10n.get('submissionDetail.revision_notes_hint'),
    );
    if (reason == null) return;

    final trimmed = reason.trim();
    await _handleDecision(
      decision: 'revision',
      note: trimmed,
      logMessage:
          'Officer decision: revision requested for application $appId by ${widget.adminName}${trimmed.isNotEmpty ? ', reason: $trimmed' : ''}',
      successMessageKey: 'revision_sent_success',
      processingKey: 'processing_revision',
    );
  }

  Future<void> _onSelectDecline(String appId) async {
    final l10n = AppLocalizations.of(context);
    final reason = await _promptForReason(
      title: l10n.get('submissionDetail.reject_submission'),
      hint: l10n.get('submissionDetail.reason_label'),
    );
    if (reason == null) return;

    final trimmed = reason.trim().isEmpty
        ? 'Rejected by ${widget.adminName}'
        : reason.trim();
    await _handleDecision(
      decision: 'declined',
      note: trimmed,
      logMessage:
          'Officer decision: declined for application $appId by ${widget.adminName}${trimmed.isNotEmpty ? ', reason: $trimmed' : ''}',
      successMessageKey: 'declined_message',
      processingKey: 'processing_rejection',
    );
  }

  Future<void> _onSelectApprove(String appId) async {
    final confirmed = await _confirmApproval();
    if (!confirmed) return;

    await _handleDecision(
      decision: 'approved',
      logMessage:
          'Officer decision: approved for application $appId by ${widget.adminName}',
      successMessageKey: 'approved_success',
      processingKey: 'processing_approval',
    );
  }

  Future<String?> _promptForReason({
    required String title,
    required String hint,
  }) async {
    final controller = TextEditingController();
    final l10n = AppLocalizations.of(context);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            maxLines: 4,
            decoration: InputDecoration(hintText: hint),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: Text(l10n.get('submissionDetail.cancel')),
            ),
            TextButton(
              onPressed: () {
                final value = controller.text.trim();
                if (value.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        l10n.get('submissionDetail.reason_required'),
                      ),
                      backgroundColor: Theme.of(context).colorScheme.error,
                    ),
                  );
                  return;
                }
                Navigator.of(dialogCtx).pop(value);
              },
              child: Text(l10n.get('submissionDetail.save')),
            ),
          ],
        );
      },
    );
    controller.dispose();
    return result?.trim().isEmpty ?? true ? null : result!.trim();
  }

  Future<bool> _confirmApproval() async {
    final l10n = AppLocalizations.of(context);
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: Text(l10n.get('submissionDetail.finish_verification')),
          content: Text(l10n.get('submissionDetail.decision_hint')),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(false),
              child: Text(l10n.get('submissionDetail.cancel')),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(true),
              child: Text(l10n.get('submissionDetail.finish_verification')),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  Widget _buildLoadingOverlay(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: false,
        child: Container(
          color: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.45),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                BouncingDotsLoader(),
                const SizedBox(height: AppTheme.spacing16),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacing24,
                  ),
                  child: Text(
                    AppLocalizations.of(context).get(
                      'submissionDetail.${_processingMessageKey ?? 'processing_request'}',
                    ),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: AppTheme.fontSizeBody1,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Poppins',
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    LoggingService().debug(
      'Building SubmissionDetailScreen for application: ${_application.id}',
    );
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDarkMode = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final responsivePadding = screenWidth > 600
        ? AppTheme.spacing16
        : screenWidth * 0.04;
    final elevatedCardColor = isDarkMode
        ? colorScheme.surfaceContainerHighest
        : colorScheme.surface;
    final subtleShadowColor = colorScheme.shadow.withValues(
      alpha: isDarkMode ? 0.45 : 0.18,
    );
    final headerGradientStart = isDarkMode
        ? colorScheme.primaryContainer
        : colorScheme.primary.withValues(alpha: 0.9);
    final headerGradientEnd = colorScheme.primary;

    final scrollContent = SingleChildScrollView(
      padding: EdgeInsets.all(responsivePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Application Header
          Container(
            padding: EdgeInsets.all(AppTheme.spacing16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [headerGradientStart, headerGradientEnd],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withValues(
                    alpha: isDarkMode ? 0.55 : 0.24,
                  ),
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
                    color: colorScheme.onPrimary.withValues(
                      alpha: isDarkMode ? 0.25 : 0.35,
                    ),
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
                        _application.shipName,
                        style: TextStyle(
                          fontSize: AppTheme.fontSizeH5,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onPrimary,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      SizedBox(height: AppTheme.spacing4),
                      Text(
                        '${AppLocalizations.of(context).get('submissionDetail.application_id')}: ${_application.id}',
                        style: TextStyle(
                          fontSize: AppTheme.fontSizeBody2,
                          color: colorScheme.onPrimary.withValues(alpha: 0.82),
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
              color: elevatedCardColor,
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              boxShadow: [
                BoxShadow(
                  color: subtleShadowColor,
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
                      color: colorScheme.primary,
                      size: screenWidth > 600 ? 24.0 : screenWidth * 0.06,
                    ),
                    SizedBox(width: AppTheme.spacing12),
                    Text(
                      AppLocalizations.of(
                        context,
                      ).get('submissionDetail.application_status'),
                      style: TextStyle(
                        fontSize: AppTheme.fontSizeH6,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
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
                    color: _getStatusColor(
                      _application.status,
                    ).withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                    border: Border.all(
                      color: _getStatusColor(
                        _application.status,
                      ).withValues(alpha: 0.32),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getStatusIcon(_application.status),
                        color: _getStatusColor(_application.status),
                        size: screenWidth > 600 ? 16.0 : screenWidth * 0.04,
                      ),
                      SizedBox(width: AppTheme.spacing8),
                      Text(
                        _getStatusText(_application.status),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: _getStatusColor(_application.status),
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
                  color: subtleShadowColor,
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
                      color: colorScheme.primary,
                      size: screenWidth > 600 ? 24.0 : screenWidth * 0.06,
                    ),
                    SizedBox(width: AppTheme.spacing12),
                    Text(
                      AppLocalizations.of(
                        context,
                      ).get('submissionDetail.application_details'),
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
                _buildDetailItem(
                  AppLocalizations.of(
                    context,
                  ).get('submissionDetail.ship_name_label'),
                  _application.shipName,
                ),
                _buildDetailItem(
                  AppLocalizations.of(
                    context,
                  ).get('submissionDetail.flag_label'),
                  _application.flag,
                ),
                _buildDetailItem(
                  AppLocalizations.of(
                    context,
                  ).get('submissionDetail.last_port_label'),
                  _application.port ?? 'N/A',
                ),
                _buildDetailItem(
                  AppLocalizations.of(
                    context,
                  ).get('submissionDetail.eta_label'),
                  _application.date ?? 'N/A',
                ),
                _buildDetailItem(
                  AppLocalizations.of(
                    context,
                  ).get('submissionDetail.wni_crew_label'),
                  _application.wniCrew?.toString() ?? '0',
                ),
                _buildDetailItem(
                  AppLocalizations.of(
                    context,
                  ).get('submissionDetail.wna_crew_label'),
                  _application.wnaCrew?.toString() ?? '0',
                ),
                _buildDetailItem(
                  AppLocalizations.of(
                    context,
                  ).get('submissionDetail.agent_label'),
                  _application.agentName,
                ),
                _buildDetailItem(
                  AppLocalizations.of(
                    context,
                  ).get('submissionDetail.location_label'),
                  _application.location ?? 'N/A',
                ),
                _buildDetailItem(
                  AppLocalizations.of(
                    context,
                  ).get('submissionDetail.submitted_at_label'),
                  '${_application.createdAt.day}/${_application.createdAt.month}/${_application.createdAt.year} ${_application.createdAt.hour}:${_application.createdAt.minute.toString().padLeft(2, '0')}',
                ),
                if (_application.officerName != null)
                  _buildDetailItem(
                    AppLocalizations.of(
                      context,
                    ).get('submissionDetail.reviewed_by_label'),
                    _application.officerName!,
                  ),
                if (_application.notes != null &&
                    _application.notes!.isNotEmpty)
                  _buildDetailItem(
                    AppLocalizations.of(
                      context,
                    ).get('submissionDetail.officer_notes_label'),
                    _application.notes!,
                  ),
              ],
            ),
          ),

          SizedBox(height: AppTheme.spacing24),

          // Document Verification Section
          Container(
            padding: EdgeInsets.all(AppTheme.spacing16),
            decoration: BoxDecoration(
              color: elevatedCardColor,
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              boxShadow: [
                BoxShadow(
                  color: subtleShadowColor,
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
                      size: screenWidth > 600 ? 24.0 : screenWidth * 0.06,
                    ),
                    SizedBox(width: AppTheme.spacing12),
                    Text(
                      AppLocalizations.of(
                        context,
                      ).get('submissionDetail.doc_verification'),
                    ),
                  ],
                ),
                SizedBox(height: AppTheme.spacing16),
                _buildDocumentList(),
              ],
            ),
          ),

          SizedBox(height: AppTheme.spacing24),

          if (_application.status == ApplicationStatus.approved)
            _buildClearanceSection(context),

          if (_application.status == ApplicationStatus.approved)
            SizedBox(height: AppTheme.spacing24),

          // Decision Section
          _buildDecisionSection(context, appId),

          SizedBox(height: AppTheme.spacing32),
          SizedBox(
            height: AppTheme.spacing24 + MediaQuery.of(context).padding.bottom,
          ),
        ],
      ),
    );

    final scaffold = Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: CustomAppBar(
        titleText: AppLocalizations.of(
          context,
        ).get('submissionDetail.application_detail'),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
      ),
      body: scrollContent,
    );

    if (!_isProcessingAction) {
      return scaffold;
    }

    return Stack(children: [scaffold, _buildLoadingOverlay(context)]);
  }
}
