import 'package:flutter/material.dart';
import 'package:m_clearance_imigrasi/app/services/functions_service.dart';
import '../../../repositories/user_repository.dart';
import '../../../localization/app_localizations.dart';
import '../../../localization/app_strings.dart';
import '../../../services/auth_service.dart';
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

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(AppLocalizations.of(context).get('accountDetail.viewing_doc')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  documentName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Text(AppLocalizations.of(context).get('accountDetail.simulation_text')),
                Text(
                  '${AppLocalizations.of(context).get('accountDetail.file_path')}: $storagePath',
                  style: const TextStyle(fontStyle: FontStyle.italic),
                ),
                const SizedBox(height: 16),
                // Placeholder for document content
                Container(
                  height: 200,
                  width: double.maxFinite,
                  decoration: BoxDecoration(
                    color: AppTheme.greyShade100,
                    border: Border.all(color: AppTheme.greyColor),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.description,
                      size: 64,
                      color: AppTheme.greyColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(AppLocalizations.of(context).get('accountDetail.close')),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    LoggingService().debug('Building AccountDetailScreen for UID: ${widget.uid}');
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: CustomAppBar(
        titleText: AppLocalizations.of(context).get('accountDetail.user_details'),
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
            return Center(child: Text(AppLocalizations.of(context).get('accountDetail.user_not_found')));
          }
          return SingleChildScrollView(
            padding: EdgeInsets.all(AppTheme.responsivePadding(context)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  elevation: 2.0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context).get('accountDetail.user_information'),
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const Divider(height: 24.0),
                        ListTile(
                          leading: const Icon(Icons.person_outline, color: AppTheme.primaryColor),
                          title: Text(AppLocalizations.of(context).get('accountDetail.username')),
                          subtitle: Text(user.username.isNotEmpty ? user.username : 'N/A'),
                        ),
                        ListTile(
                          leading: const Icon(Icons.email_outlined, color: AppTheme.primaryColor),
                          title: Text(AppLocalizations.of(context).get('accountDetail.email')),
                          subtitle: Text(user.email),
                        ),
                        ListTile(
                          leading: const Icon(Icons.business_outlined, color: AppTheme.primaryColor),
                          title: Text(AppLocalizations.of(context).get('accountDetail.corporate_name')),
                          subtitle: Text(user.corporateName.isNotEmpty ? user.corporateName : 'N/A'),
                        ),
                        ListTile(
                          leading: const Icon(Icons.flag_outlined, color: AppTheme.primaryColor),
                          title: Text(AppLocalizations.of(context).get('accountDetail.nationality')),
                          subtitle: Text(user.nationality.isNotEmpty ? user.nationality : 'N/A'),
                        ),
                        ListTile(
                          leading: const Icon(Icons.person_pin_outlined, color: AppTheme.primaryColor),
                          title: Text(AppLocalizations.of(context).get('accountDetail.role')),
                          subtitle: Text(user.role),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  elevation: 2.0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context).get('accountDetail.registration_docs'),
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const Divider(height: 24.0),
                        ...user.documents.map((d) => ListTile(
                              leading: const Icon(Icons.description_outlined, color: AppTheme.primaryColor),
                              title: Text((d['documentName'] ?? 'document').toString()),
                              trailing: ElevatedButton(
                                onPressed: () => _showDocumentPreview(context, d),
                                child: Text(AppLocalizations.of(context).get('accountDetail.view')),
                              ),
                            )),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context).get('accountDetail.reason_label'),
                    hintText: AppLocalizations.of(context).get('accountDetail.reason_hint'),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    ),
                    filled: true,
                    fillColor: AppTheme.greyShade50,
                  ),
                  maxLines: 3,
                  onChanged: (value) {
                    setState(() {
                      _rejectionReason = value;
                    });
                  },
                ),
                const SizedBox(height: 24),
                if (_loadingAction)
                  const Center(child: CircularProgressIndicator())
                else
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _decide('approved'),
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.successColor, padding: const EdgeInsets.symmetric(vertical: 16)),
                          child: Text(
                            AppLocalizations.of(context).get('accountDetail.approve'),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _decide('rejected'),
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor, padding: const EdgeInsets.symmetric(vertical: 16)),
                          child: Text(
                            AppLocalizations.of(context).get('accountDetail.reject'),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
