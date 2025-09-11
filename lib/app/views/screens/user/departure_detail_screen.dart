import 'package:flutter/material.dart';
import '../../../models/clearance_application.dart';
import '../../../localization/app_strings.dart';
import '../../widgets/custom_app_bar.dart';

class DepartureDetailScreen extends StatelessWidget {
  final ClearanceApplication application;
  final String initialLanguage;

  const DepartureDetailScreen({
    super.key,
    required this.application,
    required this.initialLanguage,
  });

  String _tr(BuildContext context, String key) => AppStrings.tr(
        context: context,
        screenKey: 'userHistory',
        stringKey: key,
        langCode: initialLanguage,
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        titleText: _tr(context, 'departure_detail'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildDetailItem(context, 'Ship Name', application.shipName),
          _buildDetailItem(context, 'Flag', application.flag),
          _buildDetailItem(context, 'Next Port', application.port ?? 'N/A'),
          _buildDetailItem(context, 'ETD', application.date ?? 'N/A'),
          _buildDetailItem(context, 'WNI Crew', application.wniCrew?.toString() ?? '0'),
          _buildDetailItem(context, 'WNA Crew', application.wnaCrew?.toString() ?? '0'),
          _buildDetailItem(context, 'Agent', application.agentName),
          _buildDetailItem(context, 'Status', application.status.name),
          if (application.notes != null && application.notes!.isNotEmpty)
            _buildDetailItem(context, 'Notes', application.notes!),
        ],
      ),
    );
  }

  Widget _buildDetailItem(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
}