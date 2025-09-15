// lib/app/views/screens/officer/officer_report_screen.dart

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../localization/app_localizations.dart';
import '../../../localization/app_strings.dart';
import '../../../services/logging_service.dart';
import '../../../config/theme.dart';
import '../../../services/functions_service.dart';
import '../../../services/report_service.dart';
import '../../../models/report_model.dart';
import '../../widgets/custom_app_bar.dart';

class OfficerReportScreen extends StatefulWidget {
  final String initialLanguage;

  const OfficerReportScreen({super.key, this.initialLanguage = 'EN'});

  @override
  State<OfficerReportScreen> createState() => _OfficerReportScreenState();
}

class _OfficerReportScreenState extends State<OfficerReportScreen> {
  final FunctionsService _functionsService = FunctionsService();
  final ReportService _reportService = ReportService();
  bool _isGeneratingReport = false;
  Map<String, dynamic> _todayStats = {};
  Map<String, dynamic> _monthStats = {};
  bool _isLoadingStats = true;
  List<ReportModel> _reports = [];
  bool _isLoadingReports = true;

  String _tr(String key) => AppLocalizations.of(context).get('officerReport.$key');

  @override
  void initState() {
    super.initState();
    LoggingService().info('OfficerReportScreen initialized');
    _loadStats();
    _loadReports();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoadingStats = true);
    try {
      final todayStats = await _functionsService.getOfficerDashboardStats();
      final monthStats = await _functionsService.getOfficerMonthlyStats();

      setState(() {
        _todayStats = todayStats;
        _monthStats = monthStats;
        _isLoadingStats = false;
      });
    } catch (e) {
      LoggingService().error('Error loading stats: $e', e);
      // Provide default values if stats loading fails
      setState(() {
        _todayStats = {
          'pendingArrival': 0,
          'pendingDeparture': 0,
          'pendingAccounts': 0,
        };
        _monthStats = {
          'pendingArrival': 0,
          'pendingDeparture': 0,
          'pendingAccounts': 0,
        };
        _isLoadingStats = false;
      });
    }
  }

  Future<void> _loadReports() async {
    setState(() => _isLoadingReports = true);
    try {
      final reports = await _reportService.getReports().first;
      setState(() {
        _reports = reports;
        _isLoadingReports = false;
      });
    } catch (e) {
      LoggingService().error('Error loading reports: $e', e);
      setState(() {
        _reports = []; // Ensure reports is empty list on error
        _isLoadingReports = false;
      });
    }
  }

  Future<void> _downloadReport(ReportModel report) async {
    if (report.pdfUrl != null) {
      try {
        await _reportService.downloadReport(report.pdfUrl!, '${report.title}.pdf');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_tr('report_downloaded_successfully')),
              backgroundColor: AppTheme.successColor,
            ),
          );
        }
      } catch (e) {
        LoggingService().error('Error downloading report', e);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_tr('error_downloading_report')),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_tr('pdf_not_available')),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _generateReport(String type) async {
    setState(() => _isGeneratingReport = true);
    try {
      if (type == 'monthly') {
        final result = await _functionsService.generateMonthlyReport(_monthStats);
        if (result['success'] == true && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_tr('report_generated_successfully')),
              backgroundColor: AppTheme.successColor,
            ),
          );
          await _loadReports();
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_tr('error_generating_report')),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      } else {
        final newReport = await _reportService.generateReport(type, _todayStats);

        if (newReport != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_tr('report_generated_successfully')),
              backgroundColor: AppTheme.successColor,
            ),
          );
          // Add the new report to the top of the list
          setState(() {
            _reports.insert(0, newReport);
          });
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_tr('error_generating_report')),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    } catch (e) {
      LoggingService().error('Error generating report: $e', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_tr('error_generating_report')),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      setState(() => _isGeneratingReport = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = screenWidth * 0.06;
    final verticalSpacing = screenWidth * 0.04;

    return Scaffold(
      backgroundColor: AppTheme.whiteColor,
      appBar: CustomAppBar(
        titleText: _tr('title'),
        backgroundColor: AppTheme.whiteColor,
        foregroundColor: AppTheme.blackColor,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadStats();
          await _loadReports();
        },
        child: SingleChildScrollView(
          padding: EdgeInsets.all(horizontalPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // Stats Cards
              if (_isLoadingStats)
                const Center(child: CircularProgressIndicator())
              else ...[
                // Today Stats
                _buildStatsCard(
                  context,
                  title: _tr('today'),
                  stats: _todayStats,
                  color: AppTheme.primaryColor,
                ),
                SizedBox(height: verticalSpacing),

                // This Month Stats
                _buildStatsCard(
                  context,
                  title: _tr('this_month'),
                  stats: _monthStats,
                  color: AppTheme.secondaryColor,
                ),
              ],

              SizedBox(height: verticalSpacing * 2),

              // Create New Report Section
              _buildCreateReportSection(context),

              if (_isGeneratingReport) ...[
                SizedBox(height: verticalSpacing),
                Center(
                  child: Column(
                    children: [
                      const CircularProgressIndicator(),
                      SizedBox(height: verticalSpacing * 0.5),
                      Text(
                        _tr('generating_pdf'),
                        style: AppTheme.bodyMedium(context).copyWith(
                          color: AppTheme.greyColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              SizedBox(height: verticalSpacing),

              // Statistics Chart
              if (!_isLoadingStats)
                _buildStatsChart(context),

              SizedBox(height: verticalSpacing * 2),

              // Report History Section
              Text(
                _tr('report_history'),
                style: AppTheme.labelLarge(context).copyWith(
                  color: AppTheme.blackColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: verticalSpacing),

              // Report History Items
              if (_isLoadingReports)
                const Center(child: CircularProgressIndicator())
              else if (_reports.isEmpty)
                Center(
                  child: Text(
                    _tr('no_reports_found'),
                    style: AppTheme.bodyMedium(context).copyWith(
                      color: AppTheme.greyColor,
                    ),
                  ),
                )
              else
                ..._reports.map((report) => _buildReportHistoryItem(
                  context,
                  report: report,
                  onTap: () => _downloadReport(report),
                )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsCard(BuildContext context, {
    required String title,
    required Map<String, dynamic> stats,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: color.withValues(alpha:0.1),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: AppTheme.headingSmall(context).copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  context,
                  label: _tr('arrival'),
                  value: stats['pendingArrival']?.toString() ?? '0',
                  color: color,
                ),
                _buildStatItem(
                  context,
                  label: _tr('departure'),
                  value: stats['pendingDeparture']?.toString() ?? '0',
                  color: color,
                ),
                _buildStatItem(
                  context,
                  label: _tr('registration'),
                  value: stats['pendingAccounts']?.toString() ?? '0',
                  color: color,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, {
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: AppTheme.headingMedium(context).copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: MediaQuery.of(context).size.width * 0.01),
        Text(
          label,
          style: AppTheme.bodySmall(context).copyWith(
            color: color.withAlpha(179),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsChart(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final chartHeight = screenWidth * 0.6;

    return Container(
      height: chartHeight,
      padding: EdgeInsets.all(screenWidth * 0.05),
      decoration: BoxDecoration(
        color: AppTheme.whiteColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.greyShade200),
        boxShadow: [
          BoxShadow(
            color: AppTheme.greyColor.withAlpha(25),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _tr('statistics_overview'),
            style: AppTheme.headingSmall(context).copyWith(
              color: AppTheme.blackColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: screenWidth * 0.03),
          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: (_todayStats.values.isNotEmpty
                    ? (_todayStats.values
                            .map((e) => e as int)
                            .reduce((a, b) => a > b ? a : b) *
                        1.2)
                    : 10), // Default maxY if no data
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      String category;
                      switch (group.x.toInt()) {
                        case 0:
                          category = _tr('arrival');
                          break;
                        case 1:
                          category = _tr('departure');
                          break;
                        case 2:
                          category = _tr('registration');
                          break;
                        default:
                          category = '';
                      }
                      return BarTooltipItem(
                        '$category\n${rod.toY.round()}',
                        AppTheme.bodySmall(context).copyWith(
                          color: AppTheme.whiteColor,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        String title;
                        switch (value.toInt()) {
                          case 0:
                            title = _tr('arrival');
                            break;
                          case 1:
                            title = _tr('departure');
                            break;
                          case 2:
                            title = _tr('registration');
                            break;
                          default:
                            title = '';
                        }
                        return Text(
                          title,
                          style: AppTheme.bodySmall(context).copyWith(
                            color: AppTheme.greyColor,
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: AppTheme.bodySmall(context).copyWith(
                            color: AppTheme.greyColor,
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: [
                  BarChartGroupData(
                    x: 0,
                    barRods: [
                      BarChartRodData(
                        toY: (_todayStats['pendingArrival'] ?? 0).toDouble(),
                        color: AppTheme.primaryColor,
                        width: screenWidth * 0.08,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  ),
                  BarChartGroupData(
                    x: 1,
                    barRods: [
                      BarChartRodData(
                        toY: (_todayStats['pendingDeparture'] ?? 0).toDouble(),
                        color: AppTheme.secondaryColor,
                        width: screenWidth * 0.08,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  ),
                  BarChartGroupData(
                    x: 2,
                    barRods: [
                      BarChartRodData(
                        toY: (_todayStats['pendingAccounts'] ?? 0).toDouble(),
                        color: AppTheme.secondaryColor,
                        width: screenWidth * 0.08,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateReportSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _tr('create_new_report'),
          style: AppTheme.headingSmall(context).copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.calendar_today),
                label: Text(_tr('daily_report')),
                onPressed: _isGeneratingReport ? null : () => _generateReport('daily'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.calendar_view_month),
                label: Text(_tr('monthly_report_type')),
                onPressed: _isGeneratingReport ? null : () => _generateReport('monthly'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildReportHistoryItem(BuildContext context, {
    ReportModel? report,
    String? title,
    String? createdBy,
    required VoidCallback onTap,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final itemPadding = screenWidth * 0.04;

    final displayTitle = report?.title ?? title ?? '';
    final displayCreatedBy = report?.createdBy ?? createdBy ?? '';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.all(itemPadding),
        margin: EdgeInsets.only(bottom: screenWidth * 0.02),
        decoration: BoxDecoration(
          color: AppTheme.greyShade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.greyShade200),
        ),
        child: Row(
          children: [
            Icon(
              Icons.description,
              color: AppTheme.primaryColor,
              size: screenWidth * 0.06,
            ),
            SizedBox(width: screenWidth * 0.03),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayTitle,
                    style: AppTheme.bodyMedium(context).copyWith(
                      color: AppTheme.blackColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: screenWidth * 0.01),
                  Text(
                    '${_tr('created_by')} $displayCreatedBy',
                    style: AppTheme.bodySmall(context).copyWith(
                      color: AppTheme.greyColor,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: AppTheme.greyColor,
              size: screenWidth * 0.06,
            ),
          ],
        ),
      ),
    );
  }
}