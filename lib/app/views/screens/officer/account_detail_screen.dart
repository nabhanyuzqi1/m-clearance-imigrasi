import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:m_clearance_imigrasi/app/services/functions_service.dart';
import 'package:m_clearance_imigrasi/app/views/screens/user/document_view_screen.dart';

import '../../../config/theme.dart';
import '../../../localization/app_localizations.dart';
import '../../../models/user_model.dart';
import '../../../repositories/user_repository.dart';
import '../../../services/logging_service.dart';
import '../../widgets/custom_app_bar.dart';

class AccountDetailScreen extends StatefulWidget {
  final String uid;
  const AccountDetailScreen({super.key, required this.uid});

  @override
  State<AccountDetailScreen> createState() => _AccountDetailScreenState();
}

class _AccountDetailScreenState extends State<AccountDetailScreen> {
  final _repo = UserRepository();
  final _fx = FunctionsService();
  late final Future<UserModel?> _userFuture;
  final TextEditingController _reasonController = TextEditingController();
  String? _rejectionReason;
  bool _loadingAction = false;

  @override
  void initState() {
    super.initState();
    _userFuture = _repo.getUser(widget.uid);
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _decide(String decision) async {
    LoggingService().info(
      'Officer decision for account ${widget.uid}: $decision',
    );
    setState(() => _loadingAction = true);

    _rejectionReason = _reasonController.text.trim();
    if (decision != 'approved' &&
        (_rejectionReason == null || _rejectionReason!.isEmpty)) {
      LoggingService().warning(
        'Rejection/revision reason required but not provided',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_tr('reason_required')),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
      setState(() => _loadingAction = false);
      return;
    }

    try {
      await _fx.officerDecideAccount(
        targetUid: widget.uid,
        decision: decision,
        reason: _rejectionReason,
      );
      LoggingService().info(
        'Officer decision processed successfully: $decision for UID: ${widget.uid}',
      );

      if (!mounted) return;
      final key = decision == 'approved'
          ? 'verified_message'
          : 'rejected_message';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_tr(key)),
          backgroundColor: AppTheme.successColor,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      LoggingService().error('Error processing officer decision: $e', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_tr('error_occurred')),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (decision == 'approved') {
        _reasonController.clear();
        _rejectionReason = null;
      }
      if (mounted) setState(() => _loadingAction = false);
    }
  }

  void _showDocumentPreview(
    BuildContext context,
    Map<String, dynamic> document,
  ) {
    final documentName = (document['documentName'] ?? 'Document').toString();
    final storagePath =
        (document['storagePath'] ?? document['path'] ?? document['url'] ?? '')
            .toString();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DocumentViewScreen(
          storagePath: storagePath,
          fileName: documentName,
        ),
      ),
    );
  }

  String _tr(String key) =>
      AppLocalizations.of(context).get('accountDetail.$key');

  String _formatTimestamp(dynamic value) {
    if (value == null) return _tr('N/A');
    DateTime? dateTime;
    if (value is DateTime) {
      dateTime = value;
    } else if (value is Timestamp) {
      dateTime = value.toDate();
    }
    if (dateTime == null) return _tr('N/A');
    return DateFormat('dd MMM yyyy • HH:mm').format(dateTime.toLocal());
  }

  Widget _buildInfoTile(
    IconData icon,
    String title,
    String subtitle, {
    Color? subtitleColor,
    bool allowFallback = true,
  }) {
    final displaySubtitle = subtitle.isNotEmpty
        ? subtitle
        : (allowFallback ? _tr('N/A') : '');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.primaryColor, size: 24),
          const SizedBox(width: 16.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.blackColor,
                    fontSize: AppTheme.fontSizeMedium,
                  ),
                ),
                if (displaySubtitle.isNotEmpty) ...[
                  const SizedBox(height: 4.0),
                  Text(
                    displaySubtitle,
                    style: TextStyle(
                      color: subtitleColor ?? AppTheme.blackColor54,
                      fontSize: AppTheme.fontSizeMedium,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(
    String title,
    List<Widget> children, {
    String? emptyMessage,
  }) {
    final content = children.isEmpty && emptyMessage != null
        ? [
            Text(
              emptyMessage,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppTheme.blackColor54),
            ),
          ]
        : children;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: AppTheme.whiteColor,
        borderRadius: BorderRadius.circular(12.0),
        boxShadow: [
          BoxShadow(
            color: AppTheme.greyShade200.withAlpha(120),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 12.0),
          ...content,
        ],
      ),
    );
  }

  Widget _buildDocumentTile(Map<String, dynamic> doc) {
    final name =
        (doc['documentName'] ?? doc['name'] ?? doc['type'] ?? 'Document')
            .toString();
    final storagePath = (doc['storagePath'] ?? doc['path'] ?? doc['url'] ?? '')
        .toString();
    final uploadedAt = doc['uploadedAt'];
    final subtitle = uploadedAt != null
        ? _formatTimestamp(uploadedAt)
        : (storagePath.isNotEmpty
              ? '${_tr('file_path')}: $storagePath'
              : _tr('N/A'));
    final canPreview = storagePath.isNotEmpty;

    final tile = Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          const Icon(
            Icons.description_outlined,
            color: AppTheme.primaryColor,
            size: 24,
          ),
          const SizedBox(width: 12.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: AppTheme.fontSizeMedium,
                    color: AppTheme.blackColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppTheme.blackColor54,
                    fontSize: AppTheme.fontSizeSmall,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios,
            size: 16.0,
            color: canPreview ? AppTheme.greyColor : AppTheme.greyShade300,
          ),
        ],
      ),
    );

    if (!canPreview) {
      return Opacity(opacity: 0.6, child: tile);
    }

    return InkWell(
      onTap: () => _showDocumentPreview(context, doc),
      borderRadius: BorderRadius.circular(12),
      child: tile,
    );
  }

  Widget _buildDecisionButtons() {
    if (_loadingAction) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.check_circle_outline),
            label: Text(_tr('approve')),
            onPressed: () => _decide('approved'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.successColor,
              foregroundColor: AppTheme.whiteColor,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30.0),
              ),
              elevation: 2,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.cancel_outlined),
            label: Text(_tr('reject')),
            onPressed: () => _decide('rejected'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              foregroundColor: AppTheme.whiteColor,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30.0),
              ),
              elevation: 2,
            ),
          ),
        ),
      ],
    );
  }

  Map<String, dynamic> _statusDescriptor(String status) {
    final l10n = AppLocalizations.of(context);
    switch (status) {
      case 'approved':
        return {
          'label': l10n.get('accountVerificationList.status_approved'),
          'color': AppTheme.successColor,
        };
      case 'rejected':
        return {
          'label': l10n.get('accountVerificationList.status_rejected'),
          'color': AppTheme.errorColor,
        };
      case 'pending_documents':
        return {
          'label': l10n.get('accountVerificationList.status_pending_documents'),
          'color': AppTheme.warningColor,
        };
      case 'pending_email_verification':
        return {
          'label': l10n.get(
            'accountVerificationList.status_pending_email_verification',
          ),
          'color': AppTheme.infoColor,
        };
      case 'pending_approval':
        return {
          'label': l10n.get('accountVerificationList.status_pending_approval'),
          'color': AppTheme.accentColor,
        };
      default:
        return {
          'label': status.replaceAll('_', ' ').toUpperCase(),
          'color': AppTheme.greyColor,
        };
    }
  }

  @override
  Widget build(BuildContext context) {
    LoggingService().debug(
      'Building AccountDetailScreen for UID: ${widget.uid}',
    );
    final horizontalPadding = AppTheme.responsivePadding(context);
    final verticalSpacing = horizontalPadding * 0.6;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: CustomAppBar(
        titleText: _tr('user_details'),
        backgroundColor: AppTheme.whiteColor,
        foregroundColor: AppTheme.blackColor,
        elevation: 0,
      ),
      body: FutureBuilder<UserModel?>(
        future: _userFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final user = snapshot.data;
          if (user == null) {
            return Center(child: Text(_tr('user_not_found')));
          }

          final documents = user.documents
              .whereType<Map<String, dynamic>>()
              .toList(growable: false);
          final hasUploadedDocs = documents.any(
            (doc) =>
                ((doc['storagePath'] ?? doc['path'] ?? doc['url'])
                    ?.toString()
                    .isNotEmpty ??
                false),
          );
          final statusDescriptor = _statusDescriptor(user.status);

          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: verticalSpacing,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionCard(_tr('user_information'), [
                  _buildInfoTile(
                    Icons.person_outline,
                    _tr('username'),
                    user.username,
                  ),
                  if (user.fullName.isNotEmpty)
                    _buildInfoTile(
                      Icons.badge_outlined,
                      _tr('full_name'),
                      user.fullName,
                    ),
                  _buildInfoTile(
                    Icons.email_outlined,
                    _tr('email'),
                    user.email,
                  ),
                  _buildInfoTile(
                    Icons.business_outlined,
                    _tr('corporate_name'),
                    user.corporateName,
                  ),
                  _buildInfoTile(
                    Icons.flag_outlined,
                    _tr('nationality'),
                    user.nationality,
                  ),
                  _buildInfoTile(
                    Icons.person_pin_outlined,
                    _tr('role'),
                    user.role,
                  ),
                ]),
                _buildSectionCard(_tr('account_metadata'), [
                  _buildInfoTile(
                    Icons.verified_user_outlined,
                    _tr('status'),
                    statusDescriptor['label'] as String,
                    subtitleColor: statusDescriptor['color'] as Color?,
                  ),
                  _buildInfoTile(
                    user.isEmailVerified
                        ? Icons.mark_email_read_outlined
                        : Icons.mark_email_unread_outlined,
                    _tr('email'),
                    _tr(
                      user.isEmailVerified
                          ? 'email_verified'
                          : 'email_not_verified',
                    ),
                    subtitleColor: user.isEmailVerified
                        ? AppTheme.successColor
                        : AppTheme.warningColor,
                  ),
                  _buildInfoTile(
                    hasUploadedDocs
                        ? Icons.folder_copy_outlined
                        : Icons.folder_off_outlined,
                    _tr('registration_docs'),
                    _tr(
                      hasUploadedDocs
                          ? 'documents_uploaded'
                          : 'documents_missing',
                    ),
                    subtitleColor: hasUploadedDocs
                        ? AppTheme.infoColor
                        : AppTheme.warningColor,
                  ),
                  _buildInfoTile(
                    Icons.schedule_outlined,
                    _tr('created_at'),
                    _formatTimestamp(user.createdAt),
                  ),
                  _buildInfoTile(
                    Icons.update,
                    _tr('updated_at'),
                    _formatTimestamp(user.updatedAt),
                  ),
                ]),
                _buildSectionCard(
                  _tr('registration_docs'),
                  documents.map(_buildDocumentTile).toList(),
                  emptyMessage: _tr('documents_empty'),
                ),
                SizedBox(height: verticalSpacing),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 12.0,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.whiteColor,
                    borderRadius: BorderRadius.circular(12.0),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.greyShade200.withAlpha(120),
                        spreadRadius: 1,
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: TextFormField(
                    controller: _reasonController,
                    decoration: InputDecoration(
                      labelText: _tr('reason_label'),
                      hintText: _tr('reason_hint'),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: AppTheme.greyShade50,
                    ),
                    maxLines: 4,
                    onChanged: (value) => _rejectionReason = value,
                  ),
                ),
                SizedBox(height: verticalSpacing),
                _buildDecisionButtons(),
              ],
            ),
          );
        },
      ),
    );
  }
}
