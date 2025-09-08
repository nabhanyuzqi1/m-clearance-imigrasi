import 'package:flutter/material.dart';
import '../../models/clearance_application.dart';
import '../../services/user_service.dart';
import 'submission_detail_screen.dart';

enum VerificationFilter { Reviewed, Waiting, All }

class ArrivalVerificationScreen extends StatefulWidget {
  final String adminName;
  final String initialLanguage;
  const ArrivalVerificationScreen({
    super.key, 
    required this.adminName,
    this.initialLanguage = 'EN',
  });

  @override
  State<ArrivalVerificationScreen> createState() => _ArrivalVerificationScreenState();
}

class _ArrivalVerificationScreenState extends State<ArrivalVerificationScreen> {
  VerificationFilter _currentFilter = VerificationFilter.All;
  late String _selectedLanguage;

   final Map<String, Map<String, String>> _translations = {
    'EN': {
      'title': 'Arrival Verification',
      'reviewed': 'Reviewed',
      'waiting': 'Waiting',
      'all': 'All',
      'no_data': 'No data for this filter.',
      'vessel_name': 'Vessel Name:',
      'verified': 'VERIFIED',
      'reviewed_decline': 'REVIEWED - DECLINE',
      'reviewed_fixing': 'REVIEWED - REQUIRE FIXING',
      'review_submission': 'REVIEW SUBMISSION',
    },
    'ID': {
      'title': 'Verifikasi Kedatangan',
      'reviewed': 'Ditinjau',
      'waiting': 'Menunggu',
      'all': 'Semua',
      'no_data': 'Tidak ada data untuk filter ini.',
      'vessel_name': 'Nama Kapal:',
      'verified': 'DIVERIFIKASI',
      'reviewed_decline': 'DITINJAU - DITOLAK',
      'reviewed_fixing': 'DITINJAU - PERLU PERBAIKAN',
      'review_submission': 'TINJAU PENGAJUAN',
    }
  };

  String _tr(String key) => _translations[_selectedLanguage]![key] ?? key;

  @override
  void initState() {
    super.initState();
    _selectedLanguage = widget.initialLanguage;
  }
  
  List<ClearanceApplication> _getFilteredList() {
    final arrivalList = UserService.agentHistory.where((app) => app.type == ApplicationType.kedatangan).toList();

    switch (_currentFilter) {
      case VerificationFilter.Waiting:
        return arrivalList.where((app) => app.status == ApplicationStatus.waiting).toList();
      case VerificationFilter.Reviewed:
        return arrivalList.where((app) => app.status != ApplicationStatus.waiting).toList();
      case VerificationFilter.All:
      default:
        return arrivalList;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredList = _getFilteredList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(_tr('title')),
        leading: const BackButton(color: Colors.black),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.blue),
            onPressed: () { /* TODO: Implement search */ },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildFilterButton(_tr('reviewed'), VerificationFilter.Reviewed),
                  _buildFilterButton(_tr('waiting'), VerificationFilter.Waiting),
                  _buildFilterButton(_tr('all'), VerificationFilter.All),
                ],
              ),
            ),
          ),
          Expanded(
            child: filteredList.isEmpty
                ? Center(child: Text(_tr('no_data')))
                : ListView.builder(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: filteredList.length,
                    itemBuilder: (context, index) {
                      return _buildVerificationItem(context, filteredList[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton(String text, VerificationFilter filter) {
    final isSelected = _currentFilter == filter;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _currentFilter = filter;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
            boxShadow: isSelected ? [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 5, spreadRadius: 1)] : [],
          ),
          child: Center(
            child: Text(text, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: Colors.black)),
          ),
        ),
      ),
    );
  }

  Widget _buildVerificationItem(BuildContext context, ClearanceApplication app) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_tr('vessel_name'), style: const TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("${app.shipName} - ${app.port}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(app.agentName, style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(app.date ?? 'No Date', style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            _buildStatusButton(context, app),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatusButton(BuildContext context, ClearanceApplication app) {
    String text;
    Color color;
    bool isWaiting = false;

    switch (app.status) {
      case ApplicationStatus.approved:
        text = _tr('verified');
        color = Colors.green;
        break;
      case ApplicationStatus.declined:
        text = _tr('reviewed_decline');
        color = Colors.red;
        break;
      case ApplicationStatus.revision:
        text = _tr('reviewed_fixing');
        color = Colors.orange;
        break;
      case ApplicationStatus.waiting:
      default:
        text = _tr('review_submission');
        color = Colors.blue;
        isWaiting = true;
        break;
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (context) => SubmissionDetailScreen(application: app, adminName: widget.adminName, initialLanguage: _selectedLanguage,)));
          setState(() {});
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: isWaiting ? color : color.withOpacity(0.1),
          foregroundColor: isWaiting ? Colors.white : color,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        icon: const Icon(Icons.circle, color: Colors.white, size: 8),
        label: Text(text),
      ),
    );
  }
}
