import 'package:flutter/material.dart';
import '../../../localization/app_strings.dart';
import '../../../repositories/application_repository.dart';
import '../../../models/clearance_application.dart';

class ArrivalVerificationScreen extends StatelessWidget {
  final String adminName;
  final String initialLanguage;

  const ArrivalVerificationScreen({
    super.key,
    required this.adminName,
    this.initialLanguage = 'EN',
  });

  @override
  Widget build(BuildContext context) {
    final repo = ApplicationRepository();
    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.tr(
          context: context,
          screenKey: 'arrivalVerification',
          stringKey: 'title',
          langCode: initialLanguage,
        )),
      ),
      body: StreamBuilder<List<ClearanceApplication>>(
        stream: repo.streamApplications(type: 'arrival', status: 'waiting'),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final apps = snapshot.data ?? const [];
          if (apps.isEmpty) {
            return Center(child: Text(AppStrings.tr(
              context: context,
              screenKey: 'verificationList',
              stringKey: 'no_data',
              langCode: initialLanguage,
            )));
          }
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
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    '/submission-detail',
                    arguments: {
                      'application': a,
                      'adminName': adminName,
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
