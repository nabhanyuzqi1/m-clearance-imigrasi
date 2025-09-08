import 'package:flutter/material.dart';
import '../../../localization/app_strings.dart';
import '../../../repositories/user_repository.dart';
import '../../../models/user_model.dart';

class AccountVerificationListScreen extends StatelessWidget {
  final String initialLanguage;
  const AccountVerificationListScreen({super.key, this.initialLanguage = 'EN'});

  @override
  Widget build(BuildContext context) {
    final repo = UserRepository();
    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.tr(
          context: context,
          screenKey: 'accountVerificationList',
          stringKey: 'title',
          langCode: initialLanguage,
        )),
      ),
      body: StreamBuilder<List<UserModel>>(
        stream: repo.streamPendingApprovals(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final users = snapshot.data ?? const [];
          if (users.isEmpty) {
            return Center(child: Text(AppStrings.tr(
              context: context,
              screenKey: 'accountVerificationList',
              stringKey: 'no_data',
              langCode: initialLanguage,
            )));
          }
          return ListView.separated(
            itemCount: users.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final u = users[index];
              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text(u.username.isNotEmpty ? u.username : (u.email)),
                subtitle: Text(u.email),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    '/account-detail',
                    arguments: {
                      'uid': u.uid,
                      'initialLanguage': initialLanguage,
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
