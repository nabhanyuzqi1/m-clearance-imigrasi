// lib/app/views/screens/officer/officer_report_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/theme.dart';
import '../../../localization/app_localizations.dart';
import '../../../models/report_model.dart';
import '../../../services/auth_service.dart';
import '../../../services/functions_service.dart';
import '../../../services/logging_service.dart';
import '../../../services/report_service.dart';
import '../../widgets/custom_app_bar.dart';
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
  bool _isLoadingStats = true;
  bool _isLoadingReports = true;

  OfficerStats? _stats;
  List<ReportModel> _reports = const [];
  DateTimeRange _selectedRange = _defaultRange();

  static DateTimeRange _defaultRange() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    return DateTimeRange(start: start, end: now);
  }

  String _tr(String key) =>
      AppLocalizations.of(context).get('officerReport.$key');

  @override
  void initState() {
    super.initState();
    _loadStats();
    _loadReports();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoadingStats = true);
    try {
      final raw = await _functionsService.getOfficerStats(
        start: _selectedRange.start,
        end: _selectedRange.end,
      );
      Map<String, dynamic> statsMap = raw;

      if (statsMap.isEmpty || statsMap['arrival'] == null) {
        LoggingService().warning(
          'getOfficerStats returned empty payload, attempting Firestore fallback',
        );
        statsMap = await _buildFallbackStats(_selectedRange);
      }

      if (statsMap.isEmpty) {
        throw StateError('Officer stats unavailable for selected range');
      }
      if (!mounted) return;
      setState(() {
        _stats = OfficerStats.fromMap(statsMap);
        _isLoadingStats = false;
      });
    } catch (error, stackTrace) {
      LoggingService().error('Failed to load officer stats', error, stackTrace);
      if (!mounted) return;
      setState(() {
        _stats = null;
        _isLoadingStats = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_tr('error_loading_stats')),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<Map<String, dynamic>> _buildFallbackStats(DateTimeRange range) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final applications = firestore.collection('applications');
      final users = firestore.collection('users');

      Future<int> countQuery(
        Query<Map<String, dynamic>> query,
        String label,
      ) async {
        try {
          final aggregate = await query.count().get();
          final countValue = aggregate.count;
          return countValue ?? 0;
        } catch (e, stackTrace) {
          LoggingService().warning(
            'Aggregate count failed for $label, falling back to snapshot length',
            e,
            stackTrace,
          );
          try {
            final snapshot = await query.get();
            return snapshot.size;
          } catch (secondaryError, secondaryStack) {
            LoggingService().error(
              'Snapshot count fallback also failed for $label',
              secondaryError,
              secondaryStack,
            );
            return 0;
          }
        }
      }

      DateTime stripToStart(DateTime value) =>
          DateTime(value.year, value.month, value.day);

      DateTime toRangeEnd(DateTime value) =>
          DateTime(value.year, value.month, value.day, 23, 59, 59, 999);

      final start = stripToStart(range.start);
      final end = toRangeEnd(range.end);
      final startTs = Timestamp.fromDate(start);
      final endTs = Timestamp.fromDate(end);

      Query<Map<String, dynamic>> applicationQuery({
        required String type,
        String? status,
        String? producedField,
      }) {
        Query<Map<String, dynamic>> query =
            applications.where('type', isEqualTo: type);

        if (status != null) {
          query = query.where('status', isEqualTo: status);
        }

        if (producedField != null) {
          query = query
              .where(producedField, isGreaterThanOrEqualTo: startTs)
              .where(producedField, isLessThanOrEqualTo: endTs);
        } else {
          query = query
              .where('createdAt', isGreaterThanOrEqualTo: startTs)
              .where('createdAt', isLessThanOrEqualTo: endTs);
        }

        if (status != null && producedField == null) {
          query = query
              .where('updatedAt', isGreaterThanOrEqualTo: startTs)
              .where('updatedAt', isLessThanOrEqualTo: endTs);
        }

        return query;
      }

      Query<Map<String, dynamic>> accountQuery({
        String? status,
        bool useCreatedAt = true,
      }) {
        Query<Map<String, dynamic>> query = users;
        if (status != null) {
          query = query.where('status', isEqualTo: status);
        }

        final field = useCreatedAt ? 'createdAt' : 'updatedAt';
        query = query
            .where(field, isGreaterThanOrEqualTo: startTs)
            .where(field, isLessThanOrEqualTo: endTs);

        return query;
      }

      // Arrival domain counts
      final arrivalTotal = await countQuery(
        applicationQuery(type: 'arrival'),
        'arrival_total',
      );
      final arrivalPending = await countQuery(
        applicationQuery(type: 'arrival', status: 'waiting'),
        'arrival_pending',
      );
      final arrivalApproved = await countQuery(
        applicationQuery(type: 'arrival', status: 'approved'),
        'arrival_approved',
      );
      final arrivalDeclined = await countQuery(
        applicationQuery(type: 'arrival', status: 'declined'),
        'arrival_declined',
      );
      final arrivalRevision = await countQuery(
        applicationQuery(type: 'arrival', status: 'revision'),
        'arrival_revision',
      );
      final arrivalProduced = await countQuery(
        applicationQuery(
          type: 'arrival',
          producedField: 'clearanceResultGeneratedAt',
        ),
        'arrival_produced',
      );

      // Departure domain counts
      final departureTotal = await countQuery(
        applicationQuery(type: 'departure'),
        'departure_total',
      );
      final departurePending = await countQuery(
        applicationQuery(type: 'departure', status: 'waiting'),
        'departure_pending',
      );
      final departureApproved = await countQuery(
        applicationQuery(type: 'departure', status: 'approved'),
        'departure_approved',
      );
      final departureDeclined = await countQuery(
        applicationQuery(type: 'departure', status: 'declined'),
        'departure_declined',
      );
      final departureRevision = await countQuery(
        applicationQuery(type: 'departure', status: 'revision'),
        'departure_revision',
      );
      final departureProduced = await countQuery(
        applicationQuery(
          type: 'departure',
          producedField: 'clearanceResultGeneratedAt',
        ),
        'departure_produced',
      );

      // Accounts counts
      final accountsTotal = await countQuery(
        accountQuery(),
        'accounts_total',
      );
      final accountsPending = await countQuery(
        accountQuery(status: 'pending_approval'),
        'accounts_pending',
      );
      final accountsApproved = await countQuery(
        accountQuery(status: 'approved', useCreatedAt: false),
        'accounts_approved',
      );
      final accountsRejected = await countQuery(
        accountQuery(status: 'rejected', useCreatedAt: false),
        'accounts_rejected',
      );

      final arrivalProcessed = arrivalApproved + arrivalDeclined;
      final departureProcessed = departureApproved + departureDeclined;
      final accountsProcessed = accountsApproved + accountsRejected;

      return {
        'range': {
          'start': start.toIso8601String(),
          'end': end.toIso8601String(),
        },
        'arrival': {
          'total': arrivalTotal,
          'pending': arrivalPending,
          'approved': arrivalApproved,
          'declined': arrivalDeclined,
          'revision': arrivalRevision,
          'produced': arrivalProduced,
          'processed': arrivalProcessed,
        },
        'departure': {
          'total': departureTotal,
          'pending': departurePending,
          'approved': departureApproved,
          'declined': departureDeclined,
          'revision': departureRevision,
          'produced': departureProduced,
          'processed': departureProcessed,
        },
        'accounts': {
          'total': accountsTotal,
          'pending': accountsPending,
          'approved': accountsApproved,
          'rejected': accountsRejected,
          'processed': accountsProcessed,
        },
        'totals': {
          'pending': arrivalPending + departurePending + accountsPending,
          'approved': arrivalApproved + departureApproved + accountsApproved,
          'rejected': arrivalDeclined + departureDeclined + accountsRejected,
          'revision': arrivalRevision + departureRevision,
          'produced': arrivalProduced + departureProduced,
          'applications': arrivalTotal + departureTotal,
        },
      };
    } catch (error, stackTrace) {
      LoggingService().error('Fallback officer stats computation failed', error, stackTrace);
      return {};
    }
  }

  Future<void> _loadReports() async {
    setState(() => _isLoadingReports = true);
    try {
      final reports = await _reportService.getReports().first;
      if (!mounted) return;
      setState(() {
        _reports = reports;
        _isLoadingReports = false;
      });
    } catch (error, stackTrace) {
      LoggingService().error('Error loading reports', error, stackTrace);
      if (!mounted) return;
      setState(() {
        _reports = const [];
        _isLoadingReports = false;
      });
    }
  }

  Future<void> _downloadReport(ReportModel report) async {
    final pdfUrl = report.pdfUrl;
    if (pdfUrl == null || pdfUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_tr('pdf_not_available')),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
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
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        await _openReportExternally(pdfUrl);
        return;
      }

      showSnack(
        SnackBar(
          content: Text(_tr('opening_report')),
          backgroundColor: Theme.of(context).colorScheme.primary,
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
    } catch (error, stackTrace) {
      LoggingService().error('Error downloading report', error, stackTrace);
      if (!mounted) return;
      messenger?.showSnackBar(
        SnackBar(
          content: Text(_tr('error_downloading_report')),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      await _openReportExternally(pdfUrl);
    }
  }

  Future<void> _openReportExternally(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (error) {
      LoggingService().warning(
        'Unable to launch external viewer for $url',
        error,
      );
    }
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: _selectedRange,
      firstDate: DateTime(2023, 1, 1),
      lastDate: DateTime.now(),
      helpText: _tr('select_range'),
    );
    if (picked == null) return;
    setState(() => _selectedRange = picked);
    await _loadStats();
  }

  Future<void> _generateReport(String type) async {
    if (_stats == null) return;
    setState(() => _isGeneratingReport = true);
    try {
      final payload = _stats!.toMap();
      final range = type == 'daily'
          ? DateTimeRange(start: _selectedRange.end, end: _selectedRange.end)
          : _selectedRange;
      final newReport = await _reportService.generateReport(
        type,
        payload,
        range: range,
      );

      if (!mounted) return;

      if (newReport != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_tr('report_generated_successfully')),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
        await _loadReports();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_tr('error_generating_report')),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } catch (error, stackTrace) {
      LoggingService().error('Error generating report', error, stackTrace);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_tr('error_generating_report')),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isGeneratingReport = false);
      }
    }
  }

  void _showCreateReportSheet() {
    if (_stats == null) return;
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (bottomContext) {
        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacing24,
            vertical: AppTheme.spacing16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.today_outlined),
                title: Text(_tr('daily_report')),
                subtitle: Text(_tr('daily_report_hint')),
                onTap: _isGeneratingReport
                    ? null
                    : () {
                        Navigator.of(bottomContext).pop();
                        _generateReport('daily');
                      },
              ),
              ListTile(
                leading: const Icon(Icons.view_week_outlined),
                title: Text(_tr('range_report')),
                subtitle: Text(_tr('range_report_hint')),
                onTap: _isGeneratingReport
                    ? null
                    : () {
                        Navigator.of(bottomContext).pop();
                        _generateReport('monthly');
                      },
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatRange(DateTimeRange range) {
    final formatter = DateFormat('d MMM yyyy');
    return '${formatter.format(range.start)} – ${formatter.format(range.end)}';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: CustomAppBar(
        titleText: _tr('title'),
        centerTitle: true,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isGeneratingReport || _stats == null
            ? null
            : _showCreateReportSheet,
        icon: _isGeneratingReport
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.summarize_outlined),
        label: Text(_tr('create_new_report')),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadStats();
          await _loadReports();
        },
        child: _isLoadingStats && _stats == null
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(AppTheme.spacing24),
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildRangePickerCard(colorScheme),
                    const SizedBox(height: AppTheme.spacing24),
                    if (_stats != null) ...[
                      _buildSummaryGrid(colorScheme),
                      const SizedBox(height: AppTheme.spacing24),
                      _buildAnalyticsChart(colorScheme),
                      const SizedBox(height: AppTheme.spacing24),
                      _buildTotalsRow(colorScheme),
                      const SizedBox(height: AppTheme.spacing32),
                    ],
                    _buildReportHistorySection(colorScheme),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildRangePickerCard(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusExtraLarge),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _tr('selected_range'),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppTheme.spacing4),
                Text(
                  _formatRange(_selectedRange),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: _pickDateRange,
            icon: const Icon(Icons.date_range_outlined),
            label: Text(_tr('change_range')),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryGrid(ColorScheme colorScheme) {
    final stats = _stats!;
    return Wrap(
      spacing: AppTheme.spacing16,
      runSpacing: AppTheme.spacing16,
      children: [
        _SummaryCard(
          title: _tr('arrival'),
          color: colorScheme.primary,
          stats: stats.arrival,
          icon: Icons.directions_boat_outlined,
        ),
        _SummaryCard(
          title: _tr('departure'),
          color: colorScheme.secondary,
          stats: stats.departure,
          icon: Icons.directions_boat,
        ),
        _SummaryCard(
          title: _tr('registration'),
          color: colorScheme.tertiary,
          stats: stats.accounts.asDomain(),
          icon: Icons.how_to_reg_outlined,
        ),
      ],
    );
  }

  Widget _buildAnalyticsChart(ColorScheme colorScheme) {
    final stats = _stats!;
    final groups = <BarChartGroupData>[];
    final maxY = _maxDomainValue(stats);

    DataColumnBuilder builder(DomainStats data, int x) {
      return DataColumnBuilder(data, x, colorScheme);
    }

    final arrivalColumn = builder(stats.arrival, 0);
    final departureColumn = builder(stats.departure, 1);
    final accountsColumn = builder(stats.accounts.asDomain(), 2);

    groups
      ..add(arrivalColumn.toGroup())
      ..add(departureColumn.toGroup())
      ..add(accountsColumn.toGroup());

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusExtraLarge),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      height: 320,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _tr('statistics_overview'),
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppTheme.spacing12),
          Expanded(
            child: BarChart(
              BarChartData(
                maxY: maxY <= 0 ? 5 : maxY * 1.2,
                alignment: BarChartAlignment.spaceAround,
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        switch (value.toInt()) {
                          case 0:
                            return Text(_tr('arrival'));
                          case 1:
                            return Text(_tr('departure'));
                          case 2:
                            return Text(_tr('registration'));
                          default:
                            return const SizedBox.shrink();
                        }
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) =>
                          Text('${value.toInt()}'),
                    ),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final label = group.x == 0
                          ? _tr('arrival')
                          : group.x == 1
                          ? _tr('departure')
                          : _tr('registration');
                      final tooltipStyle =
                          Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ) ??
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          );
                      return BarTooltipItem(
                        '$label\n${rod.toY.toStringAsFixed(0)}',
                        tooltipStyle,
                      );
                    },
                  ),
                ),
                gridData: FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: groups,
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spacing12),
          _ChartLegend(colorScheme: colorScheme, tr: _tr),
        ],
      ),
    );
  }

  double _maxDomainValue(OfficerStats stats) {
    final values = [
      stats.arrival.total,
      stats.departure.total,
      stats.accounts.total,
    ];
    return values.reduce((a, b) => a > b ? a : b).toDouble();
  }

  Widget _buildTotalsRow(ColorScheme colorScheme) {
    final stats = _stats!;
    final textTheme = Theme.of(context).textTheme;
    final items = [
      _TotalMetric(label: _tr('total_pending'), value: stats.totals.pending),
      _TotalMetric(label: _tr('total_processed'), value: stats.totalProcessed),
      _TotalMetric(label: _tr('total_produced'), value: stats.totals.produced),
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children:
          items
              .map(
                (metric) => Expanded(
                  child: Container(
                    margin: const EdgeInsets.only(right: AppTheme.spacing12),
                    padding: const EdgeInsets.all(AppTheme.spacing16),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                      border: Border.all(color: colorScheme.outlineVariant),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          metric.label,
                          style: textTheme.labelMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacing8),
                        Text(
                          metric.value.toString(),
                          style: textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .toList()
            ..last = Expanded(
              child: Container(
                padding: const EdgeInsets.all(AppTheme.spacing16),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                  border: Border.all(color: colorScheme.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      items.last.label,
                      style: textTheme.labelMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing8),
                    Text(
                      items.last.value.toString(),
                      style: textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildReportHistorySection(ColorScheme colorScheme) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _tr('report_history'),
          style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AppTheme.spacing16),
        if (_isLoadingReports)
          const Center(child: CircularProgressIndicator())
        else if (_reports.isEmpty)
          Center(
            child: Text(
              _tr('no_reports_found'),
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          ..._reports.map(
            (report) => _ReportListTile(
              report: report,
              onTap: () => _downloadReport(report),
              tr: _tr,
            ),
          ),
      ],
    );
  }
}

class OfficerStats {
  OfficerStats({
    required this.start,
    required this.end,
    required this.arrival,
    required this.departure,
    required this.accounts,
    required this.totals,
  });

  factory OfficerStats.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic value) {
      if (value is String && value.isNotEmpty) return DateTime.parse(value);
      if (value is DateTime) return value;
      return DateTime.now();
    }

    Map<String, dynamic> mapFor(dynamic value) =>
        (value is Map) ? Map<String, dynamic>.from(value) : <String, dynamic>{};

    final range = mapFor(map['range']);

    return OfficerStats(
      start: parseDate(range['start']),
      end: parseDate(range['end']),
      arrival: DomainStats.fromMap(mapFor(map['arrival'])),
      departure: DomainStats.fromMap(mapFor(map['departure'])),
      accounts: AccountStats.fromMap(mapFor(map['accounts'])),
      totals: OverviewTotals.fromMap(mapFor(map['totals'])),
    );
  }

  final DateTime start;
  final DateTime end;
  final DomainStats arrival;
  final DomainStats departure;
  final AccountStats accounts;
  final OverviewTotals totals;

  int get totalProcessed =>
      arrival.processed + departure.processed + accounts.processed;

  Map<String, dynamic> toMap() {
    return {
      'range': {'start': start.toIso8601String(), 'end': end.toIso8601String()},
      'arrival': arrival.toMap(),
      'departure': departure.toMap(),
      'accounts': accounts.toMap(),
      'totals': totals.toMap(),
    };
  }
}

class DomainStats {
  DomainStats({
    required this.total,
    required this.pending,
    required this.approved,
    required this.declined,
    required this.revision,
    required this.produced,
    required this.processed,
  });

  factory DomainStats.fromMap(Map<String, dynamic> map) {
    int asInt(dynamic value) {
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    return DomainStats(
      total: asInt(map['total']),
      pending: asInt(map['pending']),
      approved: asInt(map['approved']),
      declined: asInt(map['declined']),
      revision: asInt(map['revision']),
      produced: asInt(map['produced']),
      processed: asInt(map['processed']),
    );
  }

  final int total;
  final int pending;
  final int approved;
  final int declined;
  final int revision;
  final int produced;
  final int processed;

  Map<String, dynamic> toMap() {
    return {
      'total': total,
      'pending': pending,
      'approved': approved,
      'declined': declined,
      'revision': revision,
      'produced': produced,
      'processed': processed,
    };
  }
}

class AccountStats {
  AccountStats({
    required this.total,
    required this.pending,
    required this.approved,
    required this.rejected,
    required this.processed,
  });

  factory AccountStats.fromMap(Map<String, dynamic> map) {
    int asInt(dynamic value) {
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    return AccountStats(
      total: asInt(map['total']),
      pending: asInt(map['pending']),
      approved: asInt(map['approved']),
      rejected: asInt(map['rejected']),
      processed: asInt(map['processed']),
    );
  }

  final int total;
  final int pending;
  final int approved;
  final int rejected;
  final int processed;

  Map<String, dynamic> toMap() {
    return {
      'total': total,
      'pending': pending,
      'approved': approved,
      'rejected': rejected,
      'processed': processed,
    };
  }

  DomainStats asDomain() {
    return DomainStats(
      total: total,
      pending: pending,
      approved: approved,
      declined: rejected,
      revision: 0,
      produced: 0,
      processed: processed,
    );
  }
}

class OverviewTotals {
  OverviewTotals({
    required this.pending,
    required this.approved,
    required this.rejected,
    required this.revision,
    required this.produced,
    required this.applications,
  });

  factory OverviewTotals.fromMap(Map<String, dynamic> map) {
    int asInt(dynamic value) {
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    return OverviewTotals(
      pending: asInt(map['pending']),
      approved: asInt(map['approved']),
      rejected: asInt(map['rejected']),
      revision: asInt(map['revision']),
      produced: asInt(map['produced']),
      applications: asInt(map['applications']),
    );
  }

  final int pending;
  final int approved;
  final int rejected;
  final int revision;
  final int produced;
  final int applications;

  Map<String, dynamic> toMap() {
    return {
      'pending': pending,
      'approved': approved,
      'rejected': rejected,
      'revision': revision,
      'produced': produced,
      'applications': applications,
    };
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.color,
    required this.stats,
    required this.icon,
  });

  final String title;
  final Color color;
  final DomainStats stats;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.spacing16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusExtraLarge),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.12),
                foregroundColor: color,
                child: Icon(icon),
              ),
              const SizedBox(width: AppTheme.spacing12),
              Text(
                title,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing12),
          _SummaryMetric(label: 'Total', value: stats.total.toString()),
          _SummaryMetric(label: 'Pending', value: stats.pending.toString()),
          _SummaryMetric(label: 'Processed', value: stats.processed.toString()),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacing8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _ChartLegend extends StatelessWidget {
  const _ChartLegend({required this.colorScheme, required this.tr});

  final ColorScheme colorScheme;
  final String Function(String) tr;

  @override
  Widget build(BuildContext context) {
    final entries = [
      _LegendEntry(colorScheme.primary, tr('pending')),
      _LegendEntry(colorScheme.tertiary, tr('approved')),
      _LegendEntry(colorScheme.error, tr('declined')),
      _LegendEntry(colorScheme.secondary, tr('revision')),
      _LegendEntry(colorScheme.secondary, tr('produced')),
    ];
    return Wrap(
      spacing: AppTheme.spacing12,
      runSpacing: AppTheme.spacing8,
      children: entries
          .map(
            (entry) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: entry.color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: AppTheme.spacing8),
                Text(entry.label),
              ],
            ),
          )
          .toList(),
    );
  }
}

class _LegendEntry {
  const _LegendEntry(this.color, this.label);

  final Color color;
  final String label;
}

class DataColumnBuilder {
  DataColumnBuilder(this.data, this.x, this.scheme);

  final DomainStats data;
  final int x;
  final ColorScheme scheme;

  BarChartGroupData toGroup() {
    final rod = BarChartRodData(
      toY: data.total.toDouble(),
      width: 32,
      borderRadius: BorderRadius.circular(6),
      rodStackItems: _buildStacks(),
      color: scheme.primary,
    );
    return BarChartGroupData(x: x, barRods: [rod]);
  }

  List<BarChartRodStackItem> _buildStacks() {
    double current = 0;
    final items = <BarChartRodStackItem>[];

    void addStack(int value, Color color) {
      if (value <= 0) return;
      final start = current;
      current += value;
      items.add(BarChartRodStackItem(start, current, color));
    }

    addStack(data.pending, scheme.primary);
    addStack(data.approved, scheme.tertiary);
    addStack(data.declined, scheme.error);
    addStack(data.revision, scheme.secondary);
    addStack(data.produced, scheme.secondary);

    if (items.isEmpty) {
      items.add(BarChartRodStackItem(0, 0, scheme.primary));
    }

    return items;
  }
}

class _ReportListTile extends StatelessWidget {
  const _ReportListTile({
    required this.report,
    required this.onTap,
    required this.tr,
  });

  final ReportModel report;
  final VoidCallback onTap;
  final String Function(String) tr;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        margin: const EdgeInsets.only(bottom: AppTheme.spacing12),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Row(
          children: [
            Icon(
              Icons.description_outlined,
              color: colorScheme.primary,
              size: 28,
            ),
            const SizedBox(width: AppTheme.spacing16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    report.title,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacing4),
                  Text(
                    '${tr('created_by')} ${report.createdBy}',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _TotalMetric {
  const _TotalMetric({required this.label, required this.value});

  final String label;
  final int value;
}
