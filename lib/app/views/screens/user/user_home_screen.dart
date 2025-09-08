import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:m_clearance_imigrasi/app/services/auth_service.dart';
import '../../../localization/app_strings.dart';
import '../../../repositories/application_repository.dart';
import '../../../models/clearance_application.dart';

class UserHomeScreen extends StatelessWidget {
  final String initialLanguage;

  const UserHomeScreen({Key? key, this.initialLanguage = 'EN'}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final repo = ApplicationRepository();
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.tr(
          context: context,
          screenKey: 'userHome',
          stringKey: 'title',
          langCode: initialLanguage,
        )),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await AuthService().signOut();
            },
          ),
        ],
      ),
      body: currentUid == null
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<List<ClearanceApplication>>(
              stream: repo.streamApplications(
                type: 'arrival', // show all types by two queries? keep simple: recent arrivals
                status: 'waiting',
                agentUid: currentUid,
                limit: 10,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                final items = snapshot.data ?? const [];
                if (items.isEmpty) {
                  return Center(
                    child: Text(AppStrings.tr(
                      context: context,
                      screenKey: 'userHome',
                      stringKey: 'no_transactions',
                      langCode: initialLanguage,
                    )),
                  );
                }
                return ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final a = items[index];
                    final typeLabel = a.type == ApplicationType.kedatangan ? 'Arrival' : 'Departure';
                    return ListTile(
                      leading: Icon(
                        a.type == ApplicationType.kedatangan ? Icons.anchor : Icons.directions_boat,
                      ),
                      title: Text(a.shipName),
                      subtitle: Text('$typeLabel • ${a.flag}'),
                    );
                  },
                );
              },
            ),
    );
  }
}
