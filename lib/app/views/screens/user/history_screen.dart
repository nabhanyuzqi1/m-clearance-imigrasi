import 'package:flutter/material.dart';
import 'arrival_detail_screen.dart';
import 'departure_detail_screen.dart';
import '../../../localization/app_strings.dart';
import '../../../models/clearance_application.dart';
import '../../../models/user_account.dart';
import '../../../services/user_service.dart';
import '../../widgets/skeleton_loader.dart';
import 'clearance_form_screen.dart';
import 'clearance_result_screen.dart';

enum HistoryFilter { all, arrival, departure }

class UserHistoryScreen extends StatefulWidget {
  final UserAccount userAccount;

  const UserHistoryScreen({
    super.key,
    required this.userAccount,
  });

  @override
  State<UserHistoryScreen> createState() => _UserHistoryScreenState();
}

class _UserHistoryScreenState extends State<UserHistoryScreen> {
  HistoryFilter _currentFilter = HistoryFilter.all;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  String _tr(String key) => AppStrings.tr(
        context: context,
        screenKey: 'userHistory',
        stringKey: key,
      );

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _applyFilter(HistoryFilter filter) {
    setState(() {
      _currentFilter = filter;
    });
  }

  Widget _buildFilterButton(String text, HistoryFilter filter) {
    final isSelected = _currentFilter == filter;
    return Expanded(
      child: GestureDetector(
        onTap: () { setState(() { _currentFilter = filter; }); },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
            boxShadow: isSelected ? [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 5, spreadRadius: 1)] : [],
          ),
          child: Center(child: Text(text, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: Colors.black))),
        ),
      ),
    );
  }

  List<ClearanceApplication> _filterApplications(List<ClearanceApplication> applications) {
    List<ClearanceApplication> filteredList;
    switch (_currentFilter) {
      case HistoryFilter.arrival:
        filteredList = applications.where((app) => app.type == ApplicationType.kedatangan).toList();
        break;
      case HistoryFilter.departure:
        filteredList = applications.where((app) => app.type == ApplicationType.keberangkatan).toList();
        break;
      case HistoryFilter.all:
      default:
        filteredList = applications;
    }

    if (_searchQuery.isNotEmpty) {
      filteredList = filteredList.where((app) {
        final query = _searchQuery.toLowerCase();
        return app.shipName.toLowerCase().contains(query) ||
            (app.port?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    return filteredList;
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
        return Colors.blue;
      case ApplicationStatus.revision:
        return Colors.orange;
      case ApplicationStatus.approved:
        return Colors.green;
      case ApplicationStatus.declined:
        return Colors.red;
    }
  }

  Widget _buildStatusChip(ApplicationStatus status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: _getStatusColor(status).withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, color: _getStatusColor(status), size: 10),
          const SizedBox(width: 8),
          Text(_getStatusText(status), style: TextStyle(color: _getStatusColor(status), fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _showApplicationDetail(ClearanceApplication app) {
    if (app.type == ApplicationType.kedatangan) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ArrivalDetailScreen(
            application: app,
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DepartureDetailScreen(
            application: app,
          ),
        ),
      );
    }
  }

  Widget _buildDialogTitle(ClearanceApplication app) {
    final title = app.type == ApplicationType.kedatangan ? _tr('arrival_detail') : _tr('departure_detail');
    return Center(child: Column(children: [Text(title, style: const TextStyle(fontWeight: FontWeight.bold)), Text(app.shipName, style: const TextStyle(fontSize: 14, color: Colors.grey)), const Divider()]));
  }

  Widget _buildAboutSection(ClearanceApplication app) {
    final isArrival = app.type == ApplicationType.kedatangan;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_tr('about'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), const SizedBox(height: 8), Text("${isArrival ? _tr('last_port') : _tr('next_port')}: ${app.port ?? 'N/A'}, ${app.flag}"), Text("${_tr('crewlist')}: ${app.wniCrew ?? '0'} WNI - ${app.wnaCrew ?? '0'} WNA")]);
  }

  Widget _buildAgentSection(ClearanceApplication app) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_tr('agent'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), const SizedBox(height: 8), Row(children: [const CircleAvatar(radius: 12, child: Icon(Icons.person, size: 14)), const SizedBox(width: 8), Text(app.agentName)])]);
  }

  Widget _buildNoteSection(ClearanceApplication app) {
    if (app.status == ApplicationStatus.waiting || app.status == ApplicationStatus.approved) {
      return const SizedBox.shrink();
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_tr('note_by_officer'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), const SizedBox(height: 8), Text(app.status == ApplicationStatus.revision ? "${_tr('need_fix')} - ${app.notes ?? _tr('no_notes')}" : app.status == ApplicationStatus.declined ? "${_tr('declined')} - ${app.notes ?? _tr('no_notes')}" : "", style: const TextStyle(color: Colors.red))]);
  }

  Widget _buildDialogActions(ClearanceApplication app) {
    switch (app.status) {
      case ApplicationStatus.revision:
        return ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.orange), onPressed: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => ClearanceFormScreen(type: app.type, agentName: widget.userAccount.name, existingApplication: app))); }, child: Text(_tr('fix_button')));
      case ApplicationStatus.declined:
        return ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.pop(context), child: Text(_tr('done_button')));
      case ApplicationStatus.approved:
        return ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.blue), onPressed: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => ClearanceResultScreen(application: app))); }, child: Text(_tr('reports_button')));
      case ApplicationStatus.waiting:
      default:
        return TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"));
    }
  }


  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final horizontalPadding = screenWidth * 0.04;
    final verticalPadding = screenHeight * 0.02;

    return Scaffold(
      appBar: AppBar(
        title: Text(_tr('history'), style: TextStyle(fontSize: screenWidth * 0.045)),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by ship name or port...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
            child: Container(
              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(24)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildFilterButton(_tr('all'), HistoryFilter.all),
                  _buildFilterButton(_tr('arrival'), HistoryFilter.arrival),
                  _buildFilterButton(_tr('departure'), HistoryFilter.departure),
                ],
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<ClearanceApplication>>(
              stream: UserService().getUserApplications(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SkeletonListLoader(itemCount: 6);
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}', style: TextStyle(fontSize: screenWidth * 0.04)),
                  );
                }

                final applications = snapshot.data ?? [];
                final filteredApplications = _filterApplications(applications);

                if (filteredApplications.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(color: Colors.blue.withOpacity(0.05), shape: BoxShape.circle),
                          child: Icon(Icons.image_outlined, size: 60, color: Colors.blue.shade200),
                        ),
                        const SizedBox(height: 24),
                        Text(_tr('empty_title'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text(_tr('empty_subtitle'), textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: EdgeInsets.all(horizontalPadding * 0.5),
                  itemCount: filteredApplications.length,
                  itemBuilder: (context, index) {
                    final app = filteredApplications[index];
                    return GestureDetector(
                      onTap: () => _showApplicationDetail(app),
                      child: Card(
                        elevation: 2, margin: const EdgeInsets.only(bottom: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(app.type == ApplicationType.kedatangan ? Icons.anchor : Icons.directions_boat, color: Colors.grey.shade600),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(app.type == ApplicationType.kedatangan ? _tr('arrival') : _tr('departure'), style: const TextStyle(fontWeight: FontWeight.bold)),
                                      Text("${app.shipName} - ${app.port ?? 'N/A'}", style: const TextStyle(color: Colors.grey)),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(app.date ?? 'No Date', style: const TextStyle(color: Colors.grey)),
                              const SizedBox(height: 12),
                              _buildStatusChip(app.status),
                            ],
                          ),
                        ),
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