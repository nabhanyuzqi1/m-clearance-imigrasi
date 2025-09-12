import 'package:flutter/material.dart';
import 'package:m_clearance_imigrasi/app/services/functions_service.dart';
import '../../../localization/app_strings.dart';
import '../../../services/auth_service.dart';
import '../../../services/logging_service.dart';
import '../../../config/theme.dart';
import '../../../models/user_model.dart';
import '../../widgets/custom_app_bar.dart';

class AccountDetailScreen extends StatefulWidget {
  final String uid;
  final String initialLanguage;
  const AccountDetailScreen({super.key, required this.uid, this.initialLanguage = 'EN'});

  @override
  State<AccountDetailScreen> createState() => _AccountDetailScreenState();
}

class _AccountDetailScreenState extends State<AccountDetailScreen> {
  final _auth = AuthService();
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
        content: Text(AppStrings.tr(
          context: context,
          screenKey: 'accountDetail',
          stringKey: 'reason_required',
          langCode: widget.initialLanguage,
        )),
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
        content: Text(AppStrings.tr(
          context: context,
          screenKey: 'accountDetail',
          stringKey: key,
          langCode: widget.initialLanguage,
        )),
        backgroundColor: AppTheme.successColor,
      ));
      Navigator.pop(context, true);
    } catch (e) {
      LoggingService().error('Error processing officer decision: $e', e);
      // Display an error message
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppStrings.tr(
          context: context,
          screenKey: 'accountDetail',
          stringKey: 'error_occurred',
          langCode: widget.initialLanguage,
        )),
        backgroundColor: AppTheme.errorColor,
      ));
    } finally {
      if (mounted) setState(() => _loadingAction = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    LoggingService().debug('Building AccountDetailScreen for UID: ${widget.uid}');
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: CustomAppBar(
        title: LogoTitle(
          text: AppStrings.tr(
            context: context,
            screenKey: 'splash',
            stringKey: 'app_name',
            langCode: widget.initialLanguage,
          ),
        ),
        backgroundColor: AppTheme.whiteColor,
        foregroundColor: AppTheme.blackColor,
        elevation: 0,
      ),
      body: FutureBuilder<UserModel?>(
        future: _auth.getUserData(widget.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final user = snapshot.data;
          if (user == null) {
            return const Center(child: Text('User not found'));
          }
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(user.username.isNotEmpty ? user.username : user.email),
                  subtitle: Text(user.email),
                ),
                const SizedBox(height: 16),
                Text(AppStrings.tr(context: context, screenKey: 'accountDetail', stringKey: 'registration_docs', langCode: widget.initialLanguage),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...user.documents.map((d) => ListTile(
                      leading: const Icon(Icons.description_outlined),
                      title: Text((d['documentName'] ?? 'document').toString()),
                      subtitle: Text((d['storagePath'] ?? '').toString()),
                    )),
                const SizedBox(height: 16),
                // Text field for entering the reason for rejection or revision request
                TextFormField(
                  decoration: InputDecoration(
                    labelText: AppStrings.tr(
                      context: context,
                      screenKey: 'accountDetail',
                      stringKey: 'reason_label',
                      langCode: widget.initialLanguage,
                    ),
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
                const SizedBox(height: 16),
                const Spacer(),
                if (_loadingAction) const Center(child: CircularProgressIndicator()),
                if (!_loadingAction)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          // Reject button
                          onPressed: () => _decide('rejected'),
                          child: Text(AppStrings.tr(
                            context: context,
                            screenKey: 'accountDetail',
                            stringKey: 'reject',
                            langCode: widget.initialLanguage,
                          )),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          // Request revision button
                          onPressed: () => _decide('revision_requested'),
                          child: Text(AppStrings.tr(
                            context: context,
                            screenKey: 'accountDetail',
                            stringKey: 'request_revision',
                            langCode: widget.initialLanguage,
                          )),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          // Approve button
                          onPressed: () => _decide('approved'),
                          child: Text(AppStrings.tr(
                            context: context,
                            screenKey: 'accountDetail',
                            stringKey: 'verify_account',
                            langCode: widget.initialLanguage,
                          )),
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
