import 'package:flutter/material.dart';
import 'package:m_clearance_imigrasi/app/views/screens/user/document_view_screen.dart';
import 'package:m_clearance_imigrasi/app/services/functions_service.dart';
import '../../../repositories/user_repository.dart';
import '../../../localization/app_localizations.dart';
import '../../../services/logging_service.dart';
import '../../../config/theme.dart';
import '../../../models/user_model.dart';
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
  String? _rejectionReason; // Reason for rejection or revision request
  bool _loadingAction = false;

  // Function to handle account approval, rejection, or revision request
  Future<void> _decide(String decision) async {
    LoggingService().info('Officer decision for account ${widget.uid}: $decision');
    setState(() => _loadingAction = true);
    if (decision != 'approved' && (_rejectionReason == null || _rejectionReason!.isEmpty)) {
      LoggingService().warning('Rejection/revision reason required but not provided');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppLocalizations.of(context).get('accountDetail.reason_required')),
        backgroundColor: AppTheme.errorColor,
      ));
      setState(() => _loadingAction = false);
      return;
    }
    try {
      // Call the officerDecideAccount function from FunctionsService
      await _fx.officerDecideAccount(targetUid: widget.uid, decision: decision, reason: _rejectionReason);
      LoggingService().info('Officer decision processed successfully: $decision for UID: ${widget.uid}');
      if (!mounted) return;
      // Display a success message
      final key = decision == 'approved' ? 'verified_message' : 'rejected_message';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppLocalizations.of(context).get('accountDetail.$key')),
        backgroundColor: AppTheme.successColor,
      ));
      Navigator.pop(context, true);
    } catch (e) {
      LoggingService().error('Error processing officer decision: $e', e);
      // Display an error message
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppLocalizations.of(context).get('accountDetail.error_occurred')),
        backgroundColor: AppTheme.errorColor,
      ));
    } finally {
      if (mounted) setState(() => _loadingAction = false);
    }
  }

  void _showDocumentPreview(BuildContext context, Map<String, dynamic> document) {
    final documentName = (document['documentName'] ?? 'Document').toString();
    final storagePath = (document['storagePath'] ?? '').toString();

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

  String _tr(String key) => AppLocalizations.of(context).get('accountDetail.$key');

  Widget _buildInfoTile(IconData icon, String title, String subtitle) {
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
                    color: AppTheme.blackColor87,
                    fontSize: AppTheme.fontSizeMedium,
                  ),
                ),
                const SizedBox(height: 4.0),
                Text(
                  subtitle.isNotEmpty ? subtitle : _tr('N/A'),
                  style: const TextStyle(
                    color: AppTheme.blackColor54,
                    fontSize: AppTheme.fontSizeMedium,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(String title, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: AppTheme.whiteColor,
        borderRadius: BorderRadius.circular(12.0),
        boxShadow: [
          BoxShadow(
            color: AppTheme.greyShade200.withAlpha(128),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
          ),
          const Divider(height: 24.0, thickness: 1.0, color: AppTheme.greyShade200),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDocumentTile(Map<String, dynamic> doc) {
    return InkWell(
      onTap: () => _showDocumentPreview(context, doc),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          children: [
            const Icon(Icons.description_outlined, color: AppTheme.primaryColor, size: 24),
            const SizedBox(width: 16.0),
            Expanded(
              child: Text(
                (doc['documentName'] ?? 'document').toString(),
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: AppTheme.fontSizeMedium,
                ),
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16.0, color: AppTheme.greyColor),
          ],
        ),
      ),
    );
  }

  Widget _buildDecisionButtons() {
    return _loadingAction
        ? const Center(child: CircularProgressIndicator())
        : Column(
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30.0)),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30.0)),
                    elevation: 2,
                  ),
                ),
              ),
            ],
          );
  }

  @override
  Widget build(BuildContext context) {
    LoggingService().debug('Building AccountDetailScreen for UID: ${widget.uid}');
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: CustomAppBar(
        titleText: _tr('user_details'),
        backgroundColor: AppTheme.whiteColor,
        foregroundColor: AppTheme.blackColor,
        elevation: 0,
      ),
      body: FutureBuilder<UserModel?>(
        future: _repo.getUser(widget.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final user = snapshot.data;
          if (user == null) {
            return Center(child: Text(_tr('user_not_found')));
          }
          return SingleChildScrollView(
            padding: EdgeInsets.all(AppTheme.responsivePadding(context)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionCard(_tr('user_information'), [
                  _buildInfoTile(Icons.person_outline, _tr('username'), user.username),
                  _buildInfoTile(Icons.email_outlined, _tr('email'), user.email),
                  _buildInfoTile(Icons.business_outlined, _tr('corporate_name'), user.corporateName),
                  _buildInfoTile(Icons.flag_outlined, _tr('nationality'), user.nationality),
                  _buildInfoTile(Icons.person_pin_outlined, _tr('role'), user.role),
                ]),
                _buildSectionCard(
                  _tr('registration_docs'),
                  user.documents.map((d) => _buildDocumentTile(d)).toList(),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  decoration: BoxDecoration(
                    color: AppTheme.whiteColor,
                    borderRadius: BorderRadius.circular(12.0),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.greyShade200.withAlpha(128),
                        spreadRadius: 1,
                        blurRadius: 5,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: TextFormField(
                    decoration: InputDecoration(
                      labelText: _tr('reason_label'),
                      hintText: _tr('reason_hint'),
                      border: InputBorder.none,
                      filled: false,
                    ),
                    maxLines: 3,
                    onChanged: (value) => setState(() => _rejectionReason = value),
                  ),
                ),
                const SizedBox(height: 24),
                _buildDecisionButtons(),
              ],
            ),
          );
        },
      ),
    );
  }
}
