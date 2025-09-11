import 'package:flutter/material.dart';
import '../../../models/clearance_application.dart';
import '../../../localization/app_strings.dart';
import '../../../repositories/application_repository.dart';

class SubmissionDetailScreen extends StatelessWidget {
  final ClearanceApplication application;
  final String adminName;
  final String initialLanguage;

  const SubmissionDetailScreen({
    super.key,
    required this.application,
    required this.adminName,
    this.initialLanguage = 'EN',
  });

  @override
  Widget build(BuildContext context) {
    final repo = ApplicationRepository();
    final appId = application.id;
    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.tr(
          context: context,
          screenKey: 'submissionDetail',
          stringKey: 'title',
          langCode: initialLanguage,
        )),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(application.shipName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('${application.agentName} • ${application.flag}'),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                            await repo.officerDecide(appId: appId, decision: 'declined', note: 'Rejected by $adminName', officerName: adminName);
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Declined')));
                            Navigator.pop(context, true);
                          },
                    child: Text(AppStrings.tr(
                      context: context,
                      screenKey: 'submissionDetail',
                      stringKey: 'reject_submission',
                      langCode: initialLanguage,
                    )),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                            await repo.officerDecide(appId: appId, decision: 'revision', note: 'Needs fixing', officerName: adminName);
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Revision requested')));
                            Navigator.pop(context, true);
                          },
                    child: Text(AppStrings.tr(
                      context: context,
                      screenKey: 'submissionDetail',
                      stringKey: 'review_submission',
                      langCode: initialLanguage,
                    )),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                            await repo.officerDecide(appId: appId, decision: 'approved', officerName: adminName);
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Approved')));
                            Navigator.pop(context, true);
                          },
                    child: Text(AppStrings.tr(
                      context: context,
                      screenKey: 'submissionDetail',
                      stringKey: 'finish_verification',
                      langCode: initialLanguage,
                    )),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
