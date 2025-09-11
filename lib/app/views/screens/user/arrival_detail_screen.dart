import 'package:flutter/material.dart';
import '../../../config/theme.dart';
import '../../../models/clearance_application.dart';
import '../../../localization/app_strings.dart';
import '../../widgets/custom_app_bar.dart';

class ArrivalDetailScreen extends StatelessWidget {
  final ClearanceApplication application;
  final String initialLanguage;

  const ArrivalDetailScreen({
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
        titleText: _tr(context, 'arrival_detail'),
      ),
      body: ListView(
        padding: EdgeInsets.all(AppTheme.spacing16),
        children: [
          _buildDetailItem(context, 'Ship Name', application.shipName),
          _buildDetailItem(context, 'Flag', application.flag),
          _buildDetailItem(context, 'Last Port', application.port ?? 'N/A'),
          _buildDetailItem(context, 'ETA', application.date ?? 'N/A'),
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
      padding: EdgeInsets.symmetric(vertical: AppTheme.spacing8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Poppins', color: AppTheme.onSurface),
            ),
          ),
          SizedBox(width: AppTheme.spacing16),
          Expanded(
            child: Text(value, style: TextStyle(fontFamily: 'Poppins', color: AppTheme.onSurface)),
          ),
        ],
      ),
    );
  }
}