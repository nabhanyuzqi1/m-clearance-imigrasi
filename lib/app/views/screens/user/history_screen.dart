import 'package:flutter/material.dart';
import '../../../localization/app_strings.dart';
import '../../../models/clearance_application.dart';
import '../../../models/user_account.dart';
import '../../../services/user_service.dart';

enum HistoryFilter { all, arrival, departure }

class UserHistoryScreen extends StatefulWidget {
  final UserAccount userAccount;
  final String initialLanguage;

  const UserHistoryScreen({
    super.key,
    required this.userAccount,
    required this.initialLanguage,
  });

  @override
  State<UserHistoryScreen> createState() => _UserHistoryScreenState();
}

class _UserHistoryScreenState extends State<UserHistoryScreen> {
  HistoryFilter _currentFilter = HistoryFilter.all;
  late String _selectedLanguage;

  String _tr(String key) => AppStrings.tr(
        context: context,
        screenKey: 'userHistory',
        stringKey: key,
        langCode: _selectedLanguage,
      );

  @override
  void initState() {
    super.initState();
    _selectedLanguage = widget.initialLanguage;
  }

  void _applyFilter(HistoryFilter filter) {
    setState(() {
      _currentFilter = filter;
    });
  }

  List<ClearanceApplication> _filterApplications(List<ClearanceApplication> applications) {
    switch (_currentFilter) {
      case HistoryFilter.arrival:
        return applications.where((app) => app.type == ApplicationType.kedatangan).toList();
      case HistoryFilter.departure:
        return applications.where((app) => app.type == ApplicationType.keberangkatan).toList();
      case HistoryFilter.all:
      default:
        return applications;
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

  Color _getStatusColor(ApplicationStatus status) {
    switch (status) {
      case ApplicationStatus.waiting:
        return Colors.orange;
      case ApplicationStatus.revision:
        return Colors.blue;
      case ApplicationStatus.approved:
        return Colors.green;
      case ApplicationStatus.declined:
        return Colors.red;
    }
  }

  void _showApplicationDetail(ClearanceApplication app) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final isArrival = app.type == ApplicationType.kedatangan;
        final typeText = isArrival ? _tr('arrival') : _tr('departure');
        final detailTitle = isArrival ? _tr('arrival_detail') : _tr('departure_detail');

        return AlertDialog(
          title: Text(detailTitle),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetailRow(_tr('ship_name'), app.shipName),
                _buildDetailRow(_tr('flag'), app.flag),
                _buildDetailRow(_tr('agent'), app.agentName),
                _buildDetailRow(_tr('about'), typeText),
                if (app.port != null) _buildDetailRow(_tr('last_port'), app.port!),
                if (app.date != null) _buildDetailRow(_tr('eta'), app.date!),
                if (app.wniCrew != null) _buildDetailRow(_tr('wni_crew'), app.wniCrew!),
                if (app.wnaCrew != null) _buildDetailRow(_tr('wna_crew'), app.wnaCrew!),
                const SizedBox(height: 16),
                Text(
                  _tr('note_by_officer'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    app.notes?.isNotEmpty == true ? app.notes! : _tr('no_notes'),
                    style: TextStyle(
                      color: app.notes?.isNotEmpty == true ? Colors.black : Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(_tr('done_button')),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_tr('history')),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
            child: Text(
              'Filter by type:',
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Wrap(
              spacing: 8.0,
              runSpacing: 4.0,
              children: [
                FilterChip(
                  label: Text(_tr('all')),
                  selected: _currentFilter == HistoryFilter.all,
                  onSelected: (selected) => _applyFilter(HistoryFilter.all),
                ),
                FilterChip(
                  label: Text(_tr('arrival')),
                  selected: _currentFilter == HistoryFilter.arrival,
                  onSelected: (selected) => _applyFilter(HistoryFilter.arrival),
                ),
                FilterChip(
                  label: Text(_tr('departure')),
                  selected: _currentFilter == HistoryFilter.departure,
                  onSelected: (selected) => _applyFilter(HistoryFilter.departure),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: StreamBuilder<List<ClearanceApplication>>(
              stream: UserService().getUserApplications(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}'),
                  );
                }

                final applications = snapshot.data ?? [];
                final filteredApplications = _filterApplications(applications);

                if (filteredApplications.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _tr('empty_title'),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _tr('empty_subtitle'),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(8.0),
                  itemCount: filteredApplications.length,
                  itemBuilder: (context, index) {
                    final app = filteredApplications[index];
                    final isArrival = app.type == ApplicationType.kedatangan;
                    final iconData = isArrival ? Icons.anchor : Icons.directions_boat;
                    final typeText = isArrival ? _tr('arrival') : _tr('departure');

                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Icon(iconData, size: 20),
                        ),
                        title: Text(
                          app.shipName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("${_tr('agent')}: ${app.agentName}"),
                            Text("${_tr('about')}: $typeText"),
                            if (app.port != null) Text("${_tr('last_port')}: ${app.port}"),
                          ],
                        ),
                        trailing: Chip(
                          label: Text(
                            _getStatusText(app.status),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                          backgroundColor: _getStatusColor(app.status),
                        ),
                        isThreeLine: true,
                        onTap: () => _showApplicationDetail(app),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}