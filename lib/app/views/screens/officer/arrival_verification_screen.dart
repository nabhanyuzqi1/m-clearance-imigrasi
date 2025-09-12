import 'package:flutter/material.dart';
import '../../../localization/app_strings.dart';
import '../../../repositories/application_repository.dart';
import '../../../models/clearance_application.dart';
import '../../../services/logging_service.dart';
import '../../../config/theme.dart';
import '../../widgets/custom_app_bar.dart';

class ArrivalVerificationScreen extends StatefulWidget {
  final String adminName;
  final String initialLanguage;

  const ArrivalVerificationScreen({
    super.key,
    required this.adminName,
    this.initialLanguage = 'EN',
  });

  @override
  State<ArrivalVerificationScreen> createState() => _ArrivalVerificationScreenState();
}

class _ArrivalVerificationScreenState extends State<ArrivalVerificationScreen> {
  late final ApplicationRepository repo;

  @override
  void initState() {
    super.initState();
    LoggingService().info('ArrivalVerificationScreen initialized for admin: ${widget.adminName}');
    repo = ApplicationRepository();
  }

  Future<void> _refreshList() async {
    LoggingService().debug('Refreshing arrival verification list');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    LoggingService().debug('Building ArrivalVerificationScreen');
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
        child: StreamBuilder<List<ClearanceApplication>>(
          // Stream to fetch the list of arrival applications with "waiting" status
          stream: repo.streamApplications(type: 'arrival', status: 'waiting'),
          builder: (context, snapshot) {
            // Display a loading indicator while waiting for the data
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            // Display an error message if there's an error fetching the data
            if (snapshot.hasError) {
              LoggingService().error('Error fetching arrival applications: ${snapshot.error}');
              return Center(child: Text(AppStrings.tr(
                context: context,
                screenKey: 'arrivalVerification',
                stringKey: 'error_loading',
                langCode: widget.initialLanguage,
              )));
            }
            // Get the list of applications from the snapshot
            final apps = snapshot.data ?? const [];
            // Display a message if there are no pending applications
            if (apps.isEmpty) {
              return Center(child: Text(AppStrings.tr(
                context: context,
                screenKey: 'verificationList',
                stringKey: 'no_data',
                langCode: widget.initialLanguage,
              )));
            }
            // Display the list of applications
            return ListView.separated(
              physics: const NeverScrollableScrollPhysics(),
              itemCount: apps.length,
              separatorBuilder: (_, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final a = apps[index];
                return ListTile(
                  leading: const Icon(Icons.anchor),
                  title: Text(a.shipName),
                  subtitle: Text('${a.agentName} • ${a.flag}'),
                  trailing: const Icon(Icons.chevron_right),
                  // Navigate to the submission detail screen when an application is tapped
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      '/submission-detail',
                      arguments: {
                        'application': a,
                        'adminName': widget.adminName,
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
