// lib/app/views/screens/officer/officer_report_screen.dart

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../localization/app_localizations.dart';
import '../../../services/logging_service.dart';
import '../../../config/theme.dart';
import '../../../services/auth_service.dart';
import '../../../services/functions_service.dart';
import '../../../services/report_service.dart';
import '../../../models/report_model.dart';
import '../../widgets/custom_app_bar.dart';
import 'package:url_launcher/url_launcher.dart';
import '../user/document_view_screen.dart';

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

  String _tr(String key) =>
      AppLocalizations.of(context).get('officerReport.$key');

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
      final countersSnap = await FirebaseFirestore.instance
          .collection('counters')
          .doc('dashboard')
          .get();

      Map<String, int> todayStats = {
        'pendingArrival': 0,
        'pendingDeparture': 0,
        'pendingAccounts': 0,
      };
      if (countersSnap.exists) {
        final data = countersSnap.data() ?? {};
        todayStats = {
          'pendingArrival': (data['pendingArrival'] as num?)?.toInt() ?? 0,
          'pendingDeparture': (data['pendingDeparture'] as num?)?.toInt() ?? 0,
          'pendingAccounts': (data['pendingAccounts'] as num?)?.toInt() ?? 0,
        };
      }

      Map<String, dynamic>? monthStats;
      try {
        monthStats = await _functionsService.getOfficerMonthlyStats();
      } catch (e, stack) {
        LoggingService().warning(
          'Failed to fetch monthly stats via Cloud Function, falling back to dashboard counters.',
          e,
          stack,
        );
        monthStats = null;
      }

      final normalizedMonthStats = _normalizeStats(monthStats, todayStats);

      if (mounted) {
        setState(() {
          _todayStats = todayStats;
          _monthStats = normalizedMonthStats;
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      LoggingService().error('Error loading stats: $e', e);
      // Provide default values if stats loading fails
      if (mounted) {
        setState(() {
          _todayStats = const {
            'pendingArrival': 0,
            'pendingDeparture': 0,
            'pendingAccounts': 0,
          };
          _monthStats = _todayStats;
          _isLoadingStats = false;
        });
      }
    }
  }

  Map<String, int> _normalizeStats(
    Map<String, dynamic>? raw,
    Map<String, int> fallback,
  ) {
    if (raw == null || raw.isEmpty) {
      return Map<String, int>.from(fallback);
    }
    return {
      'pendingArrival':
          (raw['pendingArrival'] as num?)?.toInt() ??
          fallback['pendingArrival'] ??
          0,
      'pendingDeparture':
          (raw['pendingDeparture'] as num?)?.toInt() ??
          fallback['pendingDeparture'] ??
          0,
      'pendingAccounts':
          (raw['pendingAccounts'] as num?)?.toInt() ??
          fallback['pendingAccounts'] ??
          0,
    };
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
    final pdfUrl = report.pdfUrl;
    if (pdfUrl == null || pdfUrl.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_tr('pdf_not_available')),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
      return;
    }

    final messenger = ScaffoldMessenger.maybeOf(context);

    void showSnack(SnackBar snackBar) {
      if (!mounted) return;
      messenger?.showSnackBar(snackBar);
    }

    try {
      final fileData = await AuthService().downloadFileData(pdfUrl);

      if (!mounted) {
        await _openReportExternally(pdfUrl);
        return;
      }

      if (fileData == null) {
        showSnack(
          SnackBar(
            content: Text(_tr('error_downloading_report')),
            backgroundColor: AppTheme.errorColor,
          ),
        );
        await _openReportExternally(pdfUrl);
        return;
      }

      showSnack(
        SnackBar(
          content: Text(_tr('opening_report')),
          backgroundColor: AppTheme.primaryColor,
        ),
      );

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => DocumentViewScreen(
            fileData: fileData,
            fileName: '${report.title}.pdf',
          ),
        ),
      );
    } catch (e) {
      LoggingService().error('Error downloading report', e);
      if (mounted) {
        messenger?.showSnackBar(
          SnackBar(
            content: Text(_tr('error_downloading_report')),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
      await _openReportExternally(pdfUrl);
    }
  }

  Future<void> _generateReport(String type) async {
    setState(() => _isGeneratingReport = true);
    try {
      final stats = type == 'monthly' ? _monthStats : _todayStats;
      final newReport = await _reportService.generateReport(type, stats);

      if (newReport != null && mounted) {
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

  Future<void> _openReportExternally(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      LoggingService().warning('Unable to launch external viewer for $url', e);
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
                        style: AppTheme.bodyMedium(
                          context,
                        ).copyWith(color: AppTheme.greyColor),
                      ),
                    ],
                  ),
                ),
              ],

              SizedBox(height: verticalSpacing),

              // Statistics Chart
              if (!_isLoadingStats) _buildStatsChart(context),

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
                    style: AppTheme.bodyMedium(
                      context,
                    ).copyWith(color: AppTheme.greyColor),
                  ),
                )
              else
                ..._reports.map(
                  (report) => _buildReportHistoryItem(
                    context,
                    report: report,
                    onTap: () => _downloadReport(report),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsCard(
    BuildContext context, {
    required String title,
    required Map<String, dynamic> stats,
    required Color color,
  }) {
    String formatStat(String key) {
      final value = stats[key];
      if (value is num) return value.toStringAsFixed(0);
      if (value is String) {
        final parsed = double.tryParse(value);
        if (parsed != null) return parsed.toStringAsFixed(0);
      }
      return '0';
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: color.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: AppTheme.headingSmall(
                context,
              ).copyWith(color: color, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  context,
                  label: _tr('arrival'),
                  value: formatStat('pendingArrival'),
                  color: color,
                ),
                _buildStatItem(
                  context,
                  label: _tr('departure'),
                  value: formatStat('pendingDeparture'),
                  color: color,
                ),
                _buildStatItem(
                  context,
                  label: _tr('registration'),
                  value: formatStat('pendingAccounts'),
                  color: color,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context, {
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: AppTheme.headingMedium(
            context,
          ).copyWith(color: color, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: MediaQuery.of(context).size.width * 0.01),
        Text(
          label,
          style: AppTheme.bodySmall(
            context,
          ).copyWith(color: color.withAlpha(179)),
        ),
      ],
    );
  }

  Widget _buildStatsChart(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final chartHeight = screenWidth * 0.6;

    double getStatValue(String key) {
      final value = _todayStats[key];
      if (value is num) return value.toDouble();
      if (value is String) {
        return double.tryParse(value) ?? 0;
      }
      return 0;
    }

    final arrival = getStatValue('pendingArrival');
    final departure = getStatValue('pendingDeparture');
    final accounts = getStatValue('pendingAccounts');
    final maxStat = [
      arrival,
      departure,
      accounts,
    ].reduce((a, b) => a > b ? a : b);
    final double chartMaxY = maxStat > 0 ? maxStat * 1.2 : 10.0;

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
            style: AppTheme.headingSmall(
              context,
            ).copyWith(color: AppTheme.blackColor, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: screenWidth * 0.03),
          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: chartMaxY,
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
                          style: AppTheme.bodySmall(
                            context,
                          ).copyWith(color: AppTheme.greyColor),
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
                          style: AppTheme.bodySmall(
                            context,
                          ).copyWith(color: AppTheme.greyColor),
                        );
                      },
                    ),
                  ),
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: [
                  BarChartGroupData(
                    x: 0,
                    barRods: [
                      BarChartRodData(
                        toY: arrival,
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
                        toY: departure,
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
                        toY: accounts,
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
          style: AppTheme.headingSmall(
            context,
          ).copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.calendar_today),
                label: Text(_tr('daily_report')),
                onPressed: _isGeneratingReport
                    ? null
                    : () => _generateReport('daily'),
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
                onPressed: _isGeneratingReport
                    ? null
                    : () => _generateReport('monthly'),
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

  Widget _buildReportHistoryItem(
    BuildContext context, {
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
                    style: AppTheme.bodySmall(
                      context,
                    ).copyWith(color: AppTheme.greyColor),
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
