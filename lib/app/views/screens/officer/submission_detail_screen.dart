import 'package:flutter/material.dart';
import '../../../models/clearance_application.dart';
import '../../../localization/app_strings.dart';
import '../../../repositories/application_repository.dart';
import '../../../services/logging_service.dart';
import '../../../config/theme.dart';
import '../../widgets/custom_app_bar.dart';

class SubmissionDetailScreen extends StatefulWidget {
  final ClearanceApplication application;
  final String adminName;
  final String initialLanguage;

  const SubmissionDetailScreen({
    super.key,
    required this.application,
    required this.adminName,
    this.initialLanguage = 'EN',
  }) : super();

  @override
  State<SubmissionDetailScreen> createState() => _SubmissionDetailScreenState();
}

class _SubmissionDetailScreenState extends State<SubmissionDetailScreen> {
  String? _rejectionReason; // Reason for rejection or revision request
  late final ApplicationRepository repo;
  late final String appId;

  @override
  void initState() {
    super.initState();
    LoggingService().info('SubmissionDetailScreen initialized for application: ${widget.application.id}, admin: ${widget.adminName}');
    repo = ApplicationRepository();
    appId = widget.application.id;
  }

  @override
  Widget build(BuildContext context) {
    LoggingService().debug('Building SubmissionDetailScreen for application: ${widget.application.id}');
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
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.application.shipName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('${widget.application.agentName} • ${widget.application.flag}'),
            // Text field for entering the reason for rejection or revision request
            TextFormField(
              decoration: InputDecoration(
                labelText: AppStrings.tr(
                  context: context,
                  screenKey: 'submissionDetail',
                  stringKey: 'reason_label',
                  langCode: widget.initialLanguage,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                ),
                filled: true,
                fillColor: AppTheme.greyShade50,
              ),
              maxLines: 3,
              onChanged: (value) {
                _rejectionReason = value;
              },
            ),
            const SizedBox(height: 16),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    // Reject button
                    onPressed: () async {
                            if (_rejectionReason == null || _rejectionReason!.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text(AppStrings.tr(
                                  context: context,
                                  screenKey: 'submissionDetail',
                                  stringKey: 'reason_required',
                                  langCode: widget.initialLanguage,
                                )),
                                backgroundColor: AppTheme.errorColor,
                              ));
                              return;
                            }
                            // Call the officerDecide function to reject the submission
                            await repo.officerDecide(appId: appId, decision: 'declined', note: _rejectionReason ?? 'Rejected by ${widget.adminName}', officerName: widget.adminName);
                            LoggingService().info('Officer decision: declined for application $appId by ${widget.adminName}, reason: $_rejectionReason');
                            if (!context.mounted) return;
                            // Display a success message
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Declined: ${_rejectionReason ?? 'No reason provided'}')));
                            Navigator.pop(context, true);
                          },
                    child: Text(AppStrings.tr(
                      context: context,
                      screenKey: 'submissionDetail',
                      stringKey: 'reject_submission',
                      langCode: widget.initialLanguage,
                    )),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    // Request revision button
                    onPressed: () async {
                            if (_rejectionReason == null || _rejectionReason!.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text(AppStrings.tr(
                                  context: context,
                                  screenKey: 'submissionDetail',
                                  stringKey: 'reason_required',
                                  langCode: widget.initialLanguage,
                                )),
                                backgroundColor: AppTheme.errorColor,
                              ));
                              return;
                            }
                            // Call the officerDecide function to request a revision
                            await repo.officerDecide(appId: appId, decision: 'revision', note: _rejectionReason ?? 'Needs fixing', officerName: widget.adminName);
                            LoggingService().info('Officer decision: revision requested for application $appId by ${widget.adminName}, reason: $_rejectionReason');
                            if (!context.mounted) return;
                            // Display a success message
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Revision requested: ${_rejectionReason ?? 'No reason provided'}')));
                            Navigator.pop(context, true);
                          },
                    child: Text(AppStrings.tr(
                      context: context,
                      screenKey: 'submissionDetail',
                      stringKey: 'review_submission',
                      langCode: widget.initialLanguage,
                    )),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    // Approve button
                    onPressed: () async {
                            // Call the officerDecide function to approve the submission
                            await repo.officerDecide(appId: appId, decision: 'approved', officerName: widget.adminName);
                            LoggingService().info('Officer decision: approved for application $appId by ${widget.adminName}');
                            if (!context.mounted) return;
                            // Display a success message
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Approved')));
                            Navigator.pop(context, true);
                          },
                    child: Text(AppStrings.tr(
                      context: context,
                      screenKey: 'submissionDetail',
                      stringKey: 'finish_verification',
                      langCode: widget.initialLanguage,
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
