import 'package:flutter/material.dart';
import '../../models/clearance_application.dart';
import '../../services/user_service.dart';

enum HistoryFilter { semua, menunggu, disetujui, perbaikan, ditolak }

class HistoryScreen extends StatefulWidget {
  // PERBAIKAN: Menambahkan parameter initialLanguage untuk mendukung terjemahan.
  final String initialLanguage;
  const HistoryScreen({super.key, this.initialLanguage = 'EN'});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final List<ClearanceApplication> _allApplications = UserService.agentHistory;
  late List<ClearanceApplication> _filteredApplications;
  HistoryFilter _currentFilter = HistoryFilter.semua;

  // PERBAIKAN: Menambahkan state untuk bahasa yang dipilih.
  late String _selectedLanguage;

  // PERBAIKAN: Menambahkan map terjemahan untuk semua teks di layar ini.
  final Map<String, Map<String, String>> _translations = {
    'EN': {
      'title': 'History',
      'filter_by_status': 'Filter by status:',
      'all': 'All',
      'waiting': 'Waiting',
      'approved': 'Approved',
      'revision': 'Revision',
      'declined': 'Declined',
      'no_history': 'No history matches this filter.',
      'agent': 'Agent',
      'type': 'Type',
      'status': 'Status',
      'arrival': 'Arrival',
      'departure': 'Departure',
      'note': 'Note',
      'status_waiting': 'Waiting Verification',
      'status_revision': 'Needs Revision',
      'status_approved': 'Approved',
      'status_declined': 'Declined',
    },
    'ID': {
      'title': 'Riwayat',
      'filter_by_status': 'Filter berdasarkan status:',
      'all': 'Semua',
      'waiting': 'Menunggu',
      'approved': 'Disetujui',
      'revision': 'Revisi',
      'declined': 'Ditolak',
      'no_history': 'Tidak ada riwayat yang cocok dengan filter ini.',
      'agent': 'Agen',
      'type': 'Tipe',
      'status': 'Status',
      'arrival': 'Kedatangan',
      'departure': 'Keberangkatan',
      'note': 'Catatan',
      'status_waiting': 'Menunggu Verifikasi',
      'status_revision': 'Perlu Revisi',
      'status_approved': 'Disetujui',
      'status_declined': 'Ditolak',
    }
  };

  String _tr(String key) => _translations[_selectedLanguage]![key] ?? key;

  @override
  void initState() {
    super.initState();
    _selectedLanguage = widget.initialLanguage;
    _filteredApplications = _allApplications;
  }

  void _applyFilter(HistoryFilter filter) {
    setState(() {
      _currentFilter = filter;
      switch (filter) {
        case HistoryFilter.menunggu:
          _filteredApplications = _allApplications.where((app) => app.status == ApplicationStatus.waiting).toList();
          break;
        case HistoryFilter.disetujui:
          _filteredApplications = _allApplications.where((app) => app.status == ApplicationStatus.approved).toList();
          break;
        case HistoryFilter.perbaikan:
          _filteredApplications = _allApplications.where((app) => app.status == ApplicationStatus.revision).toList();
          break;
        case HistoryFilter.ditolak:
          _filteredApplications = _allApplications.where((app) => app.status == ApplicationStatus.declined).toList();
          break;
        case HistoryFilter.semua:
          _filteredApplications = _allApplications;
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_tr('title')),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
            child: Text(_tr('filter_by_status'), style: TextStyle(color: Colors.grey.shade700)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Wrap(
              spacing: 8.0,
              runSpacing: 4.0,
              children: [
                FilterChip(label: Text(_tr('all')), selected: _currentFilter == HistoryFilter.semua, onSelected: (selected) => _applyFilter(HistoryFilter.semua)),
                FilterChip(label: Text(_tr('waiting')), selected: _currentFilter == HistoryFilter.menunggu, onSelected: (selected) => _applyFilter(HistoryFilter.menunggu)),
                FilterChip(label: Text(_tr('approved')), selected: _currentFilter == HistoryFilter.disetujui, onSelected: (selected) => _applyFilter(HistoryFilter.disetujui)),
                FilterChip(label: Text(_tr('revision')), selected: _currentFilter == HistoryFilter.perbaikan, onSelected: (selected) => _applyFilter(HistoryFilter.perbaikan)),
                FilterChip(label: Text(_tr('declined')), selected: _currentFilter == HistoryFilter.ditolak, onSelected: (selected) => _applyFilter(HistoryFilter.ditolak)),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: _filteredApplications.isEmpty
                ? Center(child: Text(_tr('no_history')))
                : ListView.builder(
                    padding: const EdgeInsets.all(8.0),
                    itemCount: _filteredApplications.length,
                    itemBuilder: (context, index) {
                      final app = _filteredApplications[index];
                      final isArrival = app.type == ApplicationType.kedatangan;
                      final iconData = isArrival ? Icons.anchor : Icons.directions_boat;
                      final typeText = isArrival ? _tr('arrival') : _tr('departure');
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(child: Icon(iconData, size: 20)),
                          title: Text(app.shipName, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text("${_tr('agent')}: ${app.agentName}\n${_tr('type')}: $typeText\n${_tr('status')}: ${_getStatusText(app.status)}"),
                          isThreeLine: true,
                          trailing: Icon(Icons.circle, color: _getStatusColor(app.status)),
                          onTap: () { 
                            if (app.notes != null && app.notes!.isNotEmpty) { 
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${_tr('note')}: ${app.notes}'))); 
                            } 
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _getStatusText(ApplicationStatus status) {
    switch (status) {
      case ApplicationStatus.waiting: return _tr('status_waiting');
      case ApplicationStatus.revision: return _tr('status_revision');
      case ApplicationStatus.approved: return _tr('status_approved');
      case ApplicationStatus.declined: return _tr('status_declined');
    }
  }

  Color _getStatusColor(ApplicationStatus status) {
    switch (status) {
      case ApplicationStatus.waiting: return Colors.orange;
      case ApplicationStatus.revision: return Colors.blue;
      case ApplicationStatus.approved: return Colors.green;
      case ApplicationStatus.declined: return Colors.red;
    }
  }
}
