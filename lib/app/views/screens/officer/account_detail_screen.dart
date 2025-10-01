import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../config/theme.dart';
import '../../../localization/app_localizations.dart';
import '../../../models/user_model.dart';
import '../../../repositories/user_repository.dart';
import '../../../services/logging_service.dart';
import '../../../services/functions_service.dart';
import '../../../services/officer_service.dart';
import '../../../utils/file_utils.dart';
import '../../screens/user/document_view_screen.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/attachment_status_tile.dart';
import '../../widgets/custom_button.dart';

class AccountDetailScreen extends StatefulWidget {
  final String uid;
  const AccountDetailScreen({super.key, required this.uid});

  @override
  State<AccountDetailScreen> createState() => _AccountDetailScreenState();
}

class _AccountDetailScreenState extends State<AccountDetailScreen> {
  final _repo = UserRepository();
  final _fx = FunctionsService();
  final OfficerService _officerService = OfficerService();
  late final Future<UserModel?> _userFuture;
  bool _loadingAction = false;
  UserModel? _userModel;

  @override
  void initState() {
    super.initState();
    _userFuture = _repo.getUser(widget.uid).then((user) {
      _userModel = user;
      return user;
    });
  }

  Future<void> _decide(String decision, {String? reason}) async {
    LoggingService().info(
      'Officer decision for account ${widget.uid}: $decision',
    );
    setState(() => _loadingAction = true);

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      await _fx.officerDecideAccount(
        targetUid: widget.uid,
        decision: decision,
        reason: reason?.trim().isEmpty == true ? null : reason?.trim(),
      );
      LoggingService().info(
        'Officer decision processed successfully: $decision for UID: ${widget.uid}',
      );

      await _logAccountActivity(decision, reason: reason);

      if (!mounted) return;
      final key = decision == 'approved'
          ? 'verified_message'
          : 'rejected_message';
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(_tr(key)),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
      navigator.pop(true);
    } catch (e) {
      LoggingService().error('Error processing officer decision: $e', e);
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(_tr('error_occurred')),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingAction = false);
    }
  }

  String _tr(String key) =>
      AppLocalizations.of(context).get('accountDetail.$key');

  Future<void> _logAccountActivity(String decision, {String? reason}) async {
    try {
      final subject = _deriveAccountSubject();
      final descriptionBuffer = StringBuffer(
        'Account $subject marked as ${decision.toUpperCase()}.',
      );
      if (decision != 'approved' && reason != null && reason.isNotEmpty) {
        descriptionBuffer.write(' Reason: $reason.');
      }
      await _officerService.logActivity(
        title: subject,
        description: descriptionBuffer.toString(),
        type: 'accountVerification',
        status: decision,
        iconData: 'person',
      );
    } catch (e) {
      LoggingService().warning('Failed to log account activity', e);
    }
  }

  String _deriveAccountSubject() {
    final user = _userModel;
    if (user != null) {
      final corporate = user.corporateName.trim();
      if (corporate.isNotEmpty) return corporate;
      final fullName = user.fullName.trim();
      if (fullName.isNotEmpty) return fullName;
      final email = user.email.trim();
      if (email.isNotEmpty) return email;
    }
    return widget.uid;
  }

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
          Icon(icon, color: Theme.of(context).colorScheme.primary, size: 24),
          const SizedBox(width: 16.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: AppTheme.fontSizeMedium,
                  ),
                ),
                if (displaySubtitle.isNotEmpty) ...[
                  const SizedBox(height: 4.0),
                  Text(
                    displaySubtitle,
                    style: TextStyle(
                      color:
                          subtitleColor ??
                          Theme.of(context).colorScheme.onSurfaceVariant,
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
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ]
        : children;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12.0),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withAlpha(120),
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
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 12.0),
          ...content,
        ],
      ),
    );
  }

  Widget _buildDecisionSection() {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12.0),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withAlpha(120),
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
            l10n.get('accountDetail.select_action'),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.get('accountDetail.decision_hint'),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: AppTheme.fontSizeSmall,
            ),
          ),
          const SizedBox(height: 16),
          CustomButton(
            text: l10n.get('accountDetail.select_action'),
            leadingIcon: Icon(
              Icons.gavel_outlined,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            isFullWidth: true,
            onPressed: _loadingAction ? null : _showDecisionSheet,
          ),
        ],
      ),
    );
  }

  void _showDecisionSheet() {
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
              _buildDecisionOption(
                icon: Icons.check_circle_outline,
                color: Theme.of(context).colorScheme.primary,
                title: _tr('approve'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _onSelectApprove();
                },
              ),
              _buildDecisionOption(
                icon: Icons.cancel_outlined,
                color: Theme.of(context).colorScheme.error,
                title: _tr('reject'),
                subtitle: _tr('reason_label'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _onSelectReject();
                },
              ),
              const SizedBox(height: AppTheme.spacing12),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDecisionOption({
    required IconData icon,
    required Color color,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withAlpha(32),
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

  Future<void> _onSelectApprove() async {
    if (!await _confirmAccountApproval()) return;
    await _decide('approved');
  }

  Future<void> _onSelectReject() async {
    final reason = await _promptAccountReason(
      title: _tr('reject'),
      hint: _tr('reason_hint'),
    );
    if (reason == null) return;
    await _decide('rejected', reason: reason);
  }

  Future<bool> _confirmAccountApproval() async {
    final l10n = AppLocalizations.of(context);
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: Text(_tr('approve')),
          content: Text(l10n.get('accountDetail.decision_hint')),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(false),
              child: Text(l10n.get('submissionDetail.cancel')),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(true),
              child: Text(_tr('approve')),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  Future<String?> _promptAccountReason({
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
                      content: Text(_tr('reason_required')),
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
    final trimmed = result?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

  List<Widget> _buildRegistrationDocumentTiles(
    List<Map<String, dynamic>> docs,
  ) {
    final grouped = <String, Set<String>>{};
    final labels = <String, String>{};

    for (final doc in docs) {
      final raw = (doc['documentName'] ?? doc['name'] ?? doc['type'] ?? '')
          .toString()
          .trim();
      final key = _normalizeDocumentKey(raw);
      if (key.isEmpty) continue;

      final url = (doc['storagePath'] ?? doc['path'] ?? doc['url'] ?? '')
          .toString();
      labels.putIfAbsent(key, () => _labelForDocumentKey(key, raw));
      grouped.putIfAbsent(key, () => <String>{});
      if (url.trim().isNotEmpty) {
        grouped[key]!.add(url.trim());
      }
    }

    for (final expected in const ['ktp', 'nib']) {
      labels.putIfAbsent(
        expected,
        () => _labelForDocumentKey(expected, expected),
      );
      grouped.putIfAbsent(expected, () => <String>{});
    }

    final keys = labels.keys.toList()
      ..sort((a, b) {
        const priority = {'ktp': 0, 'nib': 1, 'siup': 2, 'npwp': 3};
        final pa = priority[a] ?? 999;
        final pb = priority[b] ?? 999;
        if (pa != pb) return pa.compareTo(pb);
        return labels[a]!.compareTo(labels[b]!);
      });

    return keys
        .map(
          (key) => AttachmentStatusTile(
            label: labels[key]!,
            fileUrls: grouped[key]!.toList(),
            onViewFile: (ctx, url) => _openDocumentUrl(url),
          ),
        )
        .toList();
  }

  String _normalizeDocumentKey(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('ktp')) return 'ktp';
    if (lower.contains('nib')) return 'nib';
    if (lower.contains('siup')) return 'siup';
    if (lower.contains('npwp')) return 'npwp';
    return lower.replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  String _labelForDocumentKey(String key, String fallback) {
    switch (key) {
      case 'ktp':
        return 'KTP';
      case 'nib':
        return 'NIB';
      case 'siup':
        return 'SIUP';
      case 'npwp':
        return 'NPWP';
      default:
        if (fallback.trim().isEmpty) {
          return _tr('registration_docs');
        }
        final words = fallback
            .replaceAll('_', ' ')
            .split(RegExp(r'\s+'))
            .where((word) => word.isNotEmpty)
            .map(
              (word) =>
                  '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
            );
        return words.join(' ');
    }
  }

  Future<void> _openDocumentUrl(String url) async {
    if (url.isEmpty) return;
    final fileName = getFileNameFromUrl(url);
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            DocumentViewScreen(storagePath: url, fileName: fileName),
      ),
    );
  }

  Map<String, dynamic> _statusDescriptor(String status) {
    final l10n = AppLocalizations.of(context);
    switch (status) {
      case 'approved':
        return {
          'label': l10n.get('accountVerificationList.status_approved'),
          'color': Theme.of(context).colorScheme.primary,
        };
      case 'rejected':
        return {
          'label': l10n.get('accountVerificationList.status_rejected'),
          'color': Theme.of(context).colorScheme.error,
        };
      case 'pending_documents':
        return {
          'label': l10n.get('accountVerificationList.status_pending_documents'),
          'color': Theme.of(context).colorScheme.secondary,
        };
      case 'pending_email_verification':
        return {
          'label': l10n.get(
            'accountVerificationList.status_pending_email_verification',
          ),
          'color': Theme.of(context).colorScheme.primary,
        };
      case 'pending_approval':
        return {
          'label': l10n.get('accountVerificationList.status_pending_approval'),
          'color': Theme.of(context).colorScheme.secondary,
        };
      default:
        return {
          'label': status.replaceAll('_', ' ').toUpperCase(),
          'color': Theme.of(context).colorScheme.onSurfaceVariant,
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
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: CustomAppBar(
        titleText: _tr('user_details'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
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

          final content = SingleChildScrollView(
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
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.secondary,
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
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.secondary,
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
                  _buildRegistrationDocumentTiles(documents),
                  emptyMessage: _tr('documents_empty'),
                ),
                SizedBox(height: verticalSpacing),
                _buildDecisionSection(),
              ],
            ),
          );

          return Stack(
            children: [content, if (_loadingAction) _buildLoadingOverlay()],
          );
        },
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withAlpha(89),
        child: const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
