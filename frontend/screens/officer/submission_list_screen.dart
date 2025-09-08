// lib/screens/officer/submission_list_screen.dart

import 'package:flutter/material.dart';
import '../../models/clearance_application.dart';
import '../../services/user_service.dart';
import 'submission_detail_screen.dart';

class SubmissionListScreen extends StatefulWidget {
  final ApplicationType type;
  final String adminName; // <-- Terima nama admin
  const SubmissionListScreen({super.key, required this.type, required this.adminName});
  @override
  State<SubmissionListScreen> createState() => _SubmissionListScreenState();
}

class _SubmissionListScreenState extends State<SubmissionListScreen> {
  late List<ClearanceApplication> _filteredSubmissions;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filteredSubmissions = UserService.agentHistory.where((s) => s.status == ApplicationStatus.waiting && s.type == widget.type).toList();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }
  
  void _onSearchChanged() {
    _filterAgents(_searchController.text);
  }

  void _filterAgents(String query) {
    final pendingSubmissions = UserService.agentHistory.where((s) => s.status == ApplicationStatus.waiting && s.type == widget.type).toList();
    List<ClearanceApplication> filteredList = pendingSubmissions.where((submission) {
      final agentNameLower = submission.agentName.toLowerCase();
      final shipNameLower = submission.shipName.toLowerCase();
      final queryLower = query.toLowerCase();
      return agentNameLower.contains(queryLower) || shipNameLower.contains(queryLower);
    }).toList();
    setState(() { _filteredSubmissions = filteredList; });
  }

  void _refreshList() {
    setState(() {
      _filteredSubmissions = UserService.agentHistory.where((s) => s.status == ApplicationStatus.waiting && s.type == widget.type).toList();
      _filterAgents(_searchController.text);
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.type == ApplicationType.kedatangan ? 'Verifikasi Kedatangan' : 'Verifikasi Keberangkatan';
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(labelText: "Cari nama kapal atau agen...", prefixIcon: const Icon(Icons.search), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
            ),
          ),
          Expanded(
            child: _filteredSubmissions.isEmpty
                ? const Center(child: Text("Tidak ada pengajuan yang perlu diverifikasi."))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    itemCount: _filteredSubmissions.length,
                    itemBuilder: (context, index) {
                      final submission = _filteredSubmissions[index];
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(child: Icon(widget.type == ApplicationType.kedatangan ? Icons.anchor : Icons.directions_boat, size: 20)),
                          title: Text(submission.shipName, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text("Agen: ${submission.agentName}"),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () async {
                            // --- Kirim nama admin ke halaman detail ---
                            await Navigator.push(context, MaterialPageRoute(builder: (context) => SubmissionDetailScreen(application: submission, adminName: widget.adminName)));
                            _refreshList();
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
}