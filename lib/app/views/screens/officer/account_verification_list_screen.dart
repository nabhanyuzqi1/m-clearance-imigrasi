import 'package:flutter/material.dart';
import '../../../localization/app_strings.dart';
import '../../../repositories/user_repository.dart';
import '../../../models/user_model.dart';
import '../../../services/logging_service.dart';
import '../../../config/theme.dart';
import '../../widgets/custom_app_bar.dart';

class AccountVerificationListScreen extends StatefulWidget {
  final String initialLanguage;
  const AccountVerificationListScreen({super.key, this.initialLanguage = 'EN'});

  @override
  State<AccountVerificationListScreen> createState() => _AccountVerificationListScreenState();
}

class _AccountVerificationListScreenState extends State<AccountVerificationListScreen> {
  late final UserRepository repo;

  @override
  void initState() {
    super.initState();
    LoggingService().info('AccountVerificationListScreen initialized');
    repo = UserRepository();
  }

  Future<void> _refreshList() async {
    LoggingService().debug('Refreshing account verification list');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    LoggingService().debug('Building AccountVerificationListScreen');
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
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: AppTheme.onSurface),
            onPressed: _refreshList,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshList,
        child: StreamBuilder<List<UserModel>>(
          // Stream to fetch the list of users with pending account verifications
          stream: repo.streamPendingApprovals(),
          builder: (context, snapshot) {
            // Display a loading indicator while waiting for the data
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            // Display an error message if there's an error fetching the data
            if (snapshot.hasError) {
              LoggingService().error('Error fetching pending approvals: ${snapshot.error}');
              return Center(child: Text(AppStrings.tr(
                context: context,
                screenKey: 'accountVerificationList',
                stringKey: 'error_loading',
                langCode: widget.initialLanguage,
              )));
            }
            // Get the list of users from the snapshot
            final users = snapshot.data ?? const [];
            // Display a message if there are no users with pending account verifications
            if (users.isEmpty) {
              return Center(child: Text(AppStrings.tr(
                context: context,
                screenKey: 'accountVerificationList',
                stringKey: 'no_data',
                langCode: widget.initialLanguage,
              )));
            }
            // Display the list of users
            return ListView.separated(
              itemCount: users.length,
              separatorBuilder: (_, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final u = users[index];
                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(u.username.isNotEmpty ? u.username : (u.email)),
                  subtitle: Text(u.email),
                  trailing: const Icon(Icons.chevron_right),
                  // Navigate to the account detail screen when a user is tapped
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      '/account-detail',
                      arguments: {
                        'uid': u.uid,
                        'initialLanguage': widget.initialLanguage,
                      },
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}
