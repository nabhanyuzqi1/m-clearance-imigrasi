import 'package:flutter/material.dart';
import '../../../models/clearance_application.dart';
import '../../../localization/app_strings.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.tr(
          context: context,
          screenKey: 'submissionDetail',
          stringKey: 'title',
          langCode: initialLanguage,
        )),
      ),
      body: Center(
        child: Text('Submission detail for ${application.shipName}'),
      ),
    );
  }
}