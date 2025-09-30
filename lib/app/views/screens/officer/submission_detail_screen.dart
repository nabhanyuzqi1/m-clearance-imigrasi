import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../models/clearance_application.dart';
import '../../../localization/app_localizations.dart';
import '../../../repositories/application_repository.dart';
import '../../../services/logging_service.dart';
import '../../../services/auth_service.dart';
import '../../../config/theme.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/custom_button.dart';
import '../user/document_view_screen.dart';
import '../../../utils/file_utils.dart';

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
  String? _rejectionReason; // Reason for rejection or revision request
  bool _isProcessingAction = false;
  String? _processingMessageKey;
  late final ApplicationRepository repo;
  late final String appId;

  @override
  void initState() {
    super.initState();
    LoggingService().info(
      'SubmissionDetailScreen initialized for application: ${widget.application.id}, admin: ${widget.adminName}',
    );
    repo = ApplicationRepository();
    appId = widget.application.id;
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
      String? officerCorporateName;
      if (decision == 'approved') {
        try {
          final currentUser = FirebaseAuth.instance.currentUser;
          if (currentUser != null) {
            final authService = AuthService();
            final userModel = await authService.getUserData(
              currentUser.uid,
              forceRefresh: true,
            );
            officerCorporateName = userModel?.corporateName;
          }
        } catch (e, stackTrace) {
          LoggingService().warning(
            'Unable to resolve officer corporate name for approval',
            e,
            stackTrace,
          );
        }
      }

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
            backgroundColor: AppTheme.errorColor,
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

  Widget _buildDocumentList() {
    final l10n = AppLocalizations.of(context);
    final crewLabel = l10n.get('submissionDetail.crew_list');
    final documents = <Map<String, dynamic>>[
      {
        'name': l10n.get('submissionDetail.port_clearance'),
        'attached': widget.application.portClearanceFile?.isNotEmpty ?? false,
        'file': widget.application.portClearanceFile,
      },
      ..._buildCrewDocuments(crewLabel),
      {
        'name': l10n.get('submissionDetail.notification_letter'),
        'attached':
            widget.application.notificationLetterFile?.isNotEmpty ?? false,
        'file': widget.application.notificationLetterFile,
      },
    ];

    return Column(
      children: documents.map((doc) => _buildFileItem(doc)).toList(),
    );
  }

  List<Map<String, dynamic>> _buildCrewDocuments(String baseLabel) {
    final crewFiles = widget.application.crewListFiles;
    if (crewFiles.isEmpty) {
      return [
        {'name': baseLabel, 'attached': false, 'file': null},
      ];
    }
    return crewFiles.asMap().entries.map((entry) {
      final index = entry.key;
      final fileUrl = entry.value;
      final label = crewFiles.length > 1
          ? '$baseLabel #${index + 1}'
          : baseLabel;
      return {'name': label, 'attached': fileUrl.isNotEmpty, 'file': fileUrl};
    }).toList();
  }

  Widget _buildFileItem(Map<String, dynamic> document) {
    final attached = document['attached'] as bool;
    final filePath = document['file'] as String?;
    final screenWidth = MediaQuery.of(context).size.width;
    final fileName = attached && filePath != null
        ? getFileNameFromUrl(filePath)
        : '';

    return Container(
      margin: EdgeInsets.only(bottom: AppTheme.spacing12),
      padding: EdgeInsets.all(AppTheme.spacing12),
      decoration: BoxDecoration(
        color: AppTheme.whiteColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: AppTheme.greyShade200),
      ),
      child: Row(
        children: [
          Container(
            width: screenWidth > 600 ? 40.0 : screenWidth * 0.1,
            height: screenWidth > 600 ? 40.0 : screenWidth * 0.1,
            decoration: BoxDecoration(
              color: attached && fileName.toLowerCase().endsWith('.pdf')
                  ? AppTheme.errorColor.withAlpha(25)
                  : AppTheme.primaryColor.withAlpha(25),
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
            child: Icon(
              attached && fileName.toLowerCase().endsWith('.pdf')
                  ? Icons.picture_as_pdf
                  : Icons.image,
              color: attached && fileName.toLowerCase().endsWith('.pdf')
                  ? AppTheme.errorColor
                  : AppTheme.primaryColor,
              size: screenWidth > 600 ? 20.0 : screenWidth * 0.05,
            ),
          ),
          SizedBox(width: AppTheme.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  document['name']!,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.onSurface,
                    fontFamily: 'Poppins',
                    fontSize: AppTheme.fontSizeBody2,
                  ),
                ),
                Text(
                  attached ? 'Attached' : 'Not Attached',
                  style: TextStyle(
                    color: AppTheme.subtitleColor,
                    fontFamily: 'Poppins',
                    fontSize: AppTheme.fontSizeBody2,
                  ),
                ),
              ],
            ),
          ),
          if (attached)
            CustomButton(
              text: AppLocalizations.of(context).get('submissionDetail.view'),
              type: CustomButtonType.outlined,
              onPressed: () => _viewDocument(filePath!),
              height: 36,
              textStyle: TextStyle(fontSize: AppTheme.fontSizeSmall),
            )
          else
            SizedBox.shrink(),
        ],
      ),
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

  Widget _buildActionButtons(BuildContext context, String appId) {
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.get('submissionDetail.action'),
          style: TextStyle(
            fontSize: AppTheme.fontSizeH6,
            fontWeight: FontWeight.bold,
            color: AppTheme.onSurface,
            fontFamily: 'Poppins',
          ),
        ),
        SizedBox(height: AppTheme.spacing16),
        SizedBox(
          width: double.infinity,
          child: CustomButton(
            text: 'Request Revision',
            backgroundColor: AppTheme.warningColor,
            foregroundColor: AppTheme.whiteColor,
            onPressed: () async {
              if (_isProcessingAction) return;
              if (_rejectionReason == null || _rejectionReason!.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l10n.get('submissionDetail.reason_required')),
                    backgroundColor: AppTheme.errorColor,
                  ),
                );
                return;
              }
              await _handleDecision(
                decision: 'revision',
                note: _rejectionReason ?? 'Needs fixing',
                logMessage:
                    'Officer decision: revision requested for application $appId by ${widget.adminName}, reason: $_rejectionReason',
                successMessageKey: 'revision_sent_success',
                processingKey: 'processing_revision',
              );
            },
          ),
        ),
        SizedBox(height: AppTheme.spacing12),
        SizedBox(
          width: double.infinity,
          child: CustomButton(
            text: l10n.get('submissionDetail.reject_submission'),
            type: CustomButtonType.elevated,
            backgroundColor: AppTheme.errorColor,
            foregroundColor: AppTheme.whiteColor,
            onPressed: () async {
              if (_isProcessingAction) return;
              if (_rejectionReason == null || _rejectionReason!.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l10n.get('submissionDetail.reason_required')),
                    backgroundColor: AppTheme.errorColor,
                  ),
                );
                return;
              }
              final rejectionNote =
                  _rejectionReason ?? 'Rejected by ${widget.adminName}';
              await _handleDecision(
                decision: 'declined',
                note: rejectionNote,
                logMessage:
                    'Officer decision: declined for application $appId by ${widget.adminName}, reason: $_rejectionReason',
                successMessageKey: 'declined_message',
                processingKey: 'processing_rejection',
              );
            },
          ),
        ),
        SizedBox(height: AppTheme.spacing12),
        SizedBox(
          width: double.infinity,
          child: CustomButton(
            text: l10n.get('submissionDetail.finish_verification'),
            type: CustomButtonType.elevated,
            backgroundColor: AppTheme.successColor,
            onPressed: () async {
              if (_isProcessingAction) return;
              await _handleDecision(
                decision: 'approved',
                logMessage:
                    'Officer decision: approved for application $appId by ${widget.adminName}',
                successMessageKey: 'approved_success',
                processingKey: 'processing_approval',
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingOverlay(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: false,
        child: Container(
          color: AppTheme.blackColor.withOpacity(0.45),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppTheme.whiteColor,
                  ),
                ),
                const SizedBox(height: AppTheme.spacing16),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacing24,
                  ),
                  child: Text(
                    AppLocalizations.of(context).get(
                      'submissionDetail.' +
                          (_processingMessageKey ?? 'processing_request'),
                    ),
                    style: TextStyle(
                      color: AppTheme.whiteColor,
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
      'Building SubmissionDetailScreen for application: ${widget.application.id}',
    );
    final screenWidth = MediaQuery.of(context).size.width;
    final responsivePadding = screenWidth > 600
        ? AppTheme.spacing16
        : screenWidth * 0.04;

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
                colors: [
                  AppTheme.primaryColor,
                  AppTheme.primaryColor.withAlpha(204),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withAlpha(51),
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
                    Icons.anchor,
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
                        widget.application.shipName,
                        style: TextStyle(
                          fontSize: AppTheme.fontSizeH5,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.whiteColor,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      SizedBox(height: AppTheme.spacing4),
                      Text(
                        '${AppLocalizations.of(context).get('submissionDetail.application_id')}: ${widget.application.id}',
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
                      AppLocalizations.of(
                        context,
                      ).get('submissionDetail.application_status'),
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
                    color: _getStatusColor(
                      widget.application.status,
                    ).withAlpha(25),
                    borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                    border: Border.all(
                      color: _getStatusColor(
                        widget.application.status,
                      ).withAlpha(51),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getStatusIcon(widget.application.status),
                        color: _getStatusColor(widget.application.status),
                        size: screenWidth > 600 ? 16.0 : screenWidth * 0.04,
                      ),
                      SizedBox(width: AppTheme.spacing8),
                      Text(
                        _getStatusText(widget.application.status),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: _getStatusColor(widget.application.status),
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
                      AppLocalizations.of(
                        context,
                      ).get('submissionDetail.application_details'),
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
                _buildDetailItem(
                  AppLocalizations.of(
                    context,
                  ).get('submissionDetail.ship_name_label'),
                  widget.application.shipName,
                ),
                _buildDetailItem(
                  AppLocalizations.of(
                    context,
                  ).get('submissionDetail.flag_label'),
                  widget.application.flag,
                ),
                _buildDetailItem(
                  AppLocalizations.of(
                    context,
                  ).get('submissionDetail.last_port_label'),
                  widget.application.port ?? 'N/A',
                ),
                _buildDetailItem(
                  AppLocalizations.of(
                    context,
                  ).get('submissionDetail.eta_label'),
                  widget.application.date ?? 'N/A',
                ),
                _buildDetailItem(
                  AppLocalizations.of(
                    context,
                  ).get('submissionDetail.wni_crew_label'),
                  widget.application.wniCrew?.toString() ?? '0',
                ),
                _buildDetailItem(
                  AppLocalizations.of(
                    context,
                  ).get('submissionDetail.wna_crew_label'),
                  widget.application.wnaCrew?.toString() ?? '0',
                ),
                _buildDetailItem(
                  AppLocalizations.of(
                    context,
                  ).get('submissionDetail.agent_label'),
                  widget.application.agentName,
                ),
                _buildDetailItem(
                  AppLocalizations.of(
                    context,
                  ).get('submissionDetail.location_label'),
                  widget.application.location ?? 'N/A',
                ),
                _buildDetailItem(
                  AppLocalizations.of(
                    context,
                  ).get('submissionDetail.submitted_at_label'),
                  '${widget.application.createdAt.day}/${widget.application.createdAt.month}/${widget.application.createdAt.year} ${widget.application.createdAt.hour}:${widget.application.createdAt.minute.toString().padLeft(2, '0')}',
                ),
                if (widget.application.officerName != null)
                  _buildDetailItem(
                    AppLocalizations.of(
                      context,
                    ).get('submissionDetail.reviewed_by_label'),
                    widget.application.officerName!,
                  ),
                if (widget.application.notes != null &&
                    widget.application.notes!.isNotEmpty)
                  _buildDetailItem(
                    AppLocalizations.of(
                      context,
                    ).get('submissionDetail.officer_notes_label'),
                    widget.application.notes!,
                  ),
              ],
            ),
          ),

          SizedBox(height: AppTheme.spacing24),

          // Document Verification Section
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

          // Decision Section
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
                Text(
                  AppLocalizations.of(context).get('submissionDetail.decision'),
                  style: TextStyle(
                    fontSize: AppTheme.fontSizeH6,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.onSurface,
                    fontFamily: 'Poppins',
                  ),
                ),
                SizedBox(height: AppTheme.spacing16),
                TextFormField(
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(
                      context,
                    ).get('submissionDetail.reason_label'),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _rejectionReason = value;
                    });
                  },
                ),
              ],
            ),
          ),

          SizedBox(height: AppTheme.spacing32),
          _buildActionButtons(context, appId),
          SizedBox(
            height: AppTheme.spacing24 + MediaQuery.of(context).padding.bottom,
          ),
        ],
      ),
    );

    final scaffold = Scaffold(
      backgroundColor: AppTheme.greyShade50,
      appBar: CustomAppBar(
        titleText: AppLocalizations.of(
          context,
        ).get('submissionDetail.application_detail'),
        backgroundColor: AppTheme.whiteColor,
        foregroundColor: AppTheme.blackColor,
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
