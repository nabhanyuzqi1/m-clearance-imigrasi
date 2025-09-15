import 'package:flutter/material.dart';
import '../../../localization/app_localizations.dart';
import '../../../localization/app_strings.dart';
import '../../../repositories/application_repository.dart';
import '../../../models/clearance_application.dart';
import '../../../services/logging_service.dart';
import '../../../config/theme.dart';
import '../../widgets/custom_app_bar.dart';

class ArrivalVerificationScreen extends StatefulWidget {
  final String adminName;

  const ArrivalVerificationScreen({
    super.key,
    required this.adminName,
  });

  @override
  State<ArrivalVerificationScreen> createState() => _ArrivalVerificationScreenState();
}

class _ArrivalVerificationScreenState extends State<ArrivalVerificationScreen> {
  late final ApplicationRepository repo;
  String _selectedFilter = 'all'; // 'all', 'waiting', 'reviewed'
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    LoggingService().info('ArrivalVerificationScreen initialized for admin: ${widget.adminName}');
    repo = ApplicationRepository();
  }

  Future<void> _refreshList() async {
    LoggingService().debug('Refreshing arrival verification list');
    setState(() {});
  }

  @override
  void dispose() {
    LoggingService().debug('Disposing ArrivalVerificationScreen resources');
    _searchController.dispose();
    super.dispose();
  }

  String _tr(String key) => AppLocalizations.of(context).get('verificationList.$key');

  List<ClearanceApplication> _filterApplications(List<ClearanceApplication> apps) {
    // First filter by status
    List<ClearanceApplication> filteredApps;
    switch (_selectedFilter) {
      case 'waiting':
        filteredApps = apps.where((app) => app.status == ApplicationStatus.waiting).toList();
        break;
      case 'reviewed':
        filteredApps = apps.where((app) => app.status != ApplicationStatus.waiting).toList();
        break;
      case 'all':
      default:
        filteredApps = apps;
    }

    // Then filter by search query
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filteredApps = filteredApps.where((app) {
        return app.shipName.toLowerCase().contains(query) ||
               app.agentName.toLowerCase().contains(query) ||
               app.flag.toLowerCase().contains(query);
      }).toList();
    }

    return filteredApps;
  }

  Widget _buildFilterButton(String filter, String label) {
    final isSelected = _selectedFilter == filter;
    return Expanded(
      child: ElevatedButton(
        onPressed: () {
          setState(() => _selectedFilter = filter);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: isSelected ? AppTheme.primaryColor : AppTheme.greyShade200,
          foregroundColor: isSelected ? AppTheme.whiteColor : AppTheme.blackColor87,
          elevation: isSelected ? 2 : 0,
          padding: const EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: AppTheme.fontSizeSmall,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(ApplicationStatus status) {
    switch (status) {
      case ApplicationStatus.waiting:
        return AppTheme.primaryColor;
      case ApplicationStatus.revision:
        return AppTheme.warningColor;
      case ApplicationStatus.approved:
        return AppTheme.successColor;
      case ApplicationStatus.declined:
        return AppTheme.errorColor;
    }
  }

  String _getStatusText(ApplicationStatus status) {
    switch (status) {
      case ApplicationStatus.waiting:
        return _tr('waiting');
      case ApplicationStatus.revision:
        return _tr('revision');
      case ApplicationStatus.approved:
        return _tr('approved');
      case ApplicationStatus.declined:
        return _tr('declined');
    }
  }

  Widget _buildApplicationCard(ClearanceApplication app) {
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = screenWidth * 0.06;
    final verticalSpacing = screenWidth * 0.03;
    final statusColor = _getStatusColor(app.status);
    final statusText = _getStatusText(app.status);

    return Container(
      margin: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: verticalSpacing * 0.5),
      padding: EdgeInsets.all(horizontalPadding),
      decoration: BoxDecoration(
        color: AppTheme.whiteColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.greyShade200),
        boxShadow: [
          BoxShadow(
            color: AppTheme.greyColor.withAlpha(13),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () async {
          final result = await Navigator.pushNamed(
            context,
            '/submission-detail',
            arguments: {
              'application': app,
              'adminName': widget.adminName,
            },
          );

          if (result == true) {
            _refreshList();
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            Icon(
              Icons.anchor,
              color: AppTheme.primaryColor,
              size: screenWidth * 0.08,
            ),
            SizedBox(width: horizontalPadding * 0.5),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    app.shipName,
                    style: AppTheme.bodyMedium(context).copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.blackColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${app.agentName} • ${app.flag}',
                    style: AppTheme.bodySmall(context).copyWith(
                      color: AppTheme.greyColor,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.02,
                vertical: screenWidth * 0.01,
              ),
              decoration: BoxDecoration(
                color: statusColor.withAlpha(25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                statusText,
                style: AppTheme.labelSmall(context).copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    LoggingService().debug('Building ArrivalVerificationScreen');
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: CustomAppBar(
        titleText: AppLocalizations.of(context).get('verificationList.arrival_title'),
        backgroundColor: AppTheme.whiteColor,
        foregroundColor: AppTheme.blackColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: AppTheme.onSurface),
            onPressed: _refreshList,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: AppTheme.whiteColor,
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() => _searchQuery = value);
              },
              decoration: InputDecoration(
                hintText: _tr('search_applications'),
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.greyShade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.greyShade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
                ),
                filled: true,
                fillColor: AppTheme.greyShade50,
                contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              ),
            ),
          ),
          // Filter buttons
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: AppTheme.whiteColor,
            child: Row(
              children: [
                _buildFilterButton('all', _tr('all')),
                const SizedBox(width: 8),
                _buildFilterButton('waiting', _tr('waiting')),
                const SizedBox(width: 8),
                _buildFilterButton('reviewed', _tr('reviewed')),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshList,
              child: StreamBuilder<List<ClearanceApplication>>(
                // Stream to fetch the list of arrival applications
                stream: repo.streamApplications(type: 'arrival'),
                builder: (context, snapshot) {
                  // Display a loading indicator while waiting for the data
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  // Display an error message if there's an error fetching the data
                  if (snapshot.hasError) {
                    LoggingService().error('Error fetching arrival applications: ${snapshot.error}');
                    return Center(child: Text(_tr('error_loading')));
                  }
                  // Get the list of applications from the snapshot
                  final allApps = snapshot.data ?? const [];

                  // Filter applications based on selected filter
                  final apps = _filterApplications(allApps);

                  // Display a message if there are no applications
                  if (apps.isEmpty) {
                    return Center(child: Text(_tr('no_data')));
                  }
                  // Display the list of applications
                  return ListView.builder(
                    itemCount: apps.length,
                    itemBuilder: (context, index) {
                      final a = apps[index];
                      return _buildApplicationCard(a);
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
