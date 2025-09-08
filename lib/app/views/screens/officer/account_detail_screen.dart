import 'package:flutter/material.dart';
import 'package:m_clearance_imigrasi/app/services/functions_service.dart';
import '../../../localization/app_strings.dart';
import '../../../services/auth_service.dart';
import '../../../models/user_model.dart';

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
  bool _loadingAction = false;

  Future<void> _decide(String decision) async {
    setState(() => _loadingAction = true);
    try {
      await _fx.officerDecideAccount(targetUid: widget.uid, decision: decision);
      if (!mounted) return;
      final key = decision == 'approved' ? 'verified_message' : 'rejected_message';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.tr(
        context: context,
        screenKey: 'accountDetail',
        stringKey: key,
        langCode: widget.initialLanguage,
      ))));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loadingAction = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.tr(
          context: context,
          screenKey: 'accountDetail',
          stringKey: 'title',
          langCode: widget.initialLanguage,
        )),
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
                const Spacer(),
                if (_loadingAction) const Center(child: CircularProgressIndicator()),
                if (!_loadingAction)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
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
                        child: ElevatedButton(
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
