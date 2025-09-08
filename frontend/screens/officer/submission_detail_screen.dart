import 'package:flutter/material.dart';
import '../../models/clearance_application.dart';
import '../../services/user_service.dart';

enum DocumentStatus { pending, approved, revisionNeeded }

class SubmissionDetailScreen extends StatefulWidget {
  final ClearanceApplication application;
  final String adminName;
  final String initialLanguage;
  const SubmissionDetailScreen({
    super.key, 
    required this.application, 
    required this.adminName,
    this.initialLanguage = 'EN',
  });

  @override
  State<SubmissionDetailScreen> createState() => _SubmissionDetailScreenState();
}

class _SubmissionDetailScreenState extends State<SubmissionDetailScreen> {
  final TextEditingController _notesController = TextEditingController();
  late Map<String, DocumentStatus> _documentStatuses;
  late Map<String, String> _revisionNotes;
  late String _selectedLanguage;

  final Map<String, Map<String, String>> _translations = {
    'EN': {
      'title': 'Verification Details',
      'submission_info': 'Submission Information',
      'ship_name': 'Ship Name',
      'flag': 'Flag',
      'agent_name': 'Agent Name',
      'location': 'Location',
      'port': 'Port',
      'arrival_date': 'Arrival Date',
      'departure_date': 'Departure Date',
      'wni_crew': 'WNI Crew',
      'wna_crew': 'WNA Crew',
      'doc_verification': 'Document Verification',
      'port_clearance': 'Port Clearance',
      'crew_list': 'Crew List',
      'notification_letter': 'Notification Letter',
      'action': 'Action',
      'reject_submission': 'Reject Submission',
      'finish_verification': 'Finish Verification',
      'check_all_docs_warning': 'Please check all documents first.',
      'revision_sent_success': 'Revision status has been sent to the agent.',
      'approved_success': 'Submission has been approved.',
      'rejected_success': 'Submission has been rejected.',
      'revision_notes_title': 'Revision Notes for',
      'revision_notes_hint': 'Enter revision notes...',
      'cancel': 'Cancel',
      'save': 'Save',
      'doc_preview_title': 'Document Preview',
      'doc_preview_content': 'This is a simulation preview for the document:\n',
      'close': 'Close',
      'status_pending': 'Pending',
      'status_approved': 'Approved',
      'status_revision': 'Revision',
      'view': 'View',
      'notes': 'Notes',
    },
    'ID': {
      'title': 'Detail Verifikasi',
      'submission_info': 'Informasi Pengajuan',
      'ship_name': 'Nama Kapal',
      'flag': 'Bendera',
      'agent_name': 'Nama Agen',
      'location': 'Lokasi',
      'port': 'Pelabuhan',
      'arrival_date': 'Tanggal Kedatangan',
      'departure_date': 'Tanggal Keberangkatan',
      'wni_crew': 'ABK WNI',
      'wna_crew': 'ABK WNA',
      'doc_verification': 'Verifikasi Dokumen',
      'port_clearance': 'Port Clearance',
      'crew_list': 'Daftar Kru',
      'notification_letter': 'Surat Pemberitahuan',
      'action': 'Tindakan',
      'reject_submission': 'Tolak Pengajuan',
      'finish_verification': 'Selesai Verifikasi',
      'check_all_docs_warning': 'Harap periksa semua dokumen terlebih dahulu.',
      'revision_sent_success': 'Status perbaikan telah dikirim ke agen.',
      'approved_success': 'Pengajuan telah disetujui.',
      'rejected_success': 'Pengajuan telah ditolak.',
      'revision_notes_title': 'Catatan Revisi untuk',
      'revision_notes_hint': 'Masukkan catatan perbaikan...',
      'cancel': 'Batal',
      'save': 'Simpan',
      'doc_preview_title': 'Pratinjau Dokumen',
      'doc_preview_content': 'Ini adalah simulasi pratinjau untuk dokumen:\n',
      'close': 'Tutup',
      'status_pending': 'Menunggu',
      'status_approved': 'Disetujui',
      'status_revision': 'Revisi',
      'view': 'Lihat',
      'notes': 'Catatan',
    }
  };

  String _tr(String key) => _translations[_selectedLanguage]![key] ?? key;

  @override
  void initState() {
    super.initState();
    _selectedLanguage = widget.initialLanguage;
    _documentStatuses = {
      "Port Clearance": DocumentStatus.pending,
      "Crew List": DocumentStatus.pending,
      "Surat Pemberitahuan": DocumentStatus.pending,
    };
    _revisionNotes = {};
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _finishVerification() {
    bool allChecked = _documentStatuses.values.every((status) => status != DocumentStatus.pending);
    if (!allChecked) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_tr('check_all_docs_warning')),
        backgroundColor: Colors.red,
      ));
      return;
    }

    bool hasRevision = _documentStatuses.values.any((status) => status == DocumentStatus.revisionNeeded);
    
    int index = UserService.agentHistory.indexWhere((app) =>
        app.shipName == widget.application.shipName && app.date == widget.application.date && app.type == widget.application.type);

    if (index != -1) {
      if (hasRevision) {
        String finalNotes = _revisionNotes.entries
            .where((entry) => _documentStatuses[entry.key] == DocumentStatus.revisionNeeded)
            .map((e) => "${e.key}: ${e.value}")
            .join('\n');
        
        UserService.agentHistory[index] = widget.application.copyWith(
          status: ApplicationStatus.revision,
          notes: finalNotes.isEmpty ? "Diperlukan perbaikan dokumen." : finalNotes,
        );
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_tr('revision_sent_success')),
          backgroundColor: Colors.orange,
        ));
      } else {
        UserService.agentHistory[index] = widget.application.copyWith(
          status: ApplicationStatus.approved,
          officerName: widget.adminName,
        );
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_tr('approved_success')),
          backgroundColor: Colors.green,
        ));
      }
    }
    Navigator.pop(context);
  }

  void _showRevisionNotesDialog(String documentName) {
    showDialog(
      context: context,
      builder: (context) {
        _notesController.text = _revisionNotes[documentName] ?? '';
        return AlertDialog(
          title: Text("${_tr('revision_notes_title')} $documentName"),
          content: TextField(
            controller: _notesController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: _tr('revision_notes_hint'),
              border: const OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(_tr('cancel')),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _revisionNotes[documentName] = _notesController.text;
                });
                Navigator.pop(context);
              },
              child: Text(_tr('save')),
            ),
          ],
        );
      },
    );
  }

  void _showDocumentDialog(String documentName) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(_tr('doc_preview_title')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.picture_as_pdf, size: 70, color: Colors.red.shade700),
              const SizedBox(height: 20),
              Text(
                "${_tr('doc_preview_content')}$documentName.pdf",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(_tr('close')),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isKedatangan = widget.application.type == ApplicationType.kedatangan;

    return Scaffold(
      appBar: AppBar(
        title: Text(_tr('title')),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle(_tr('submission_info')),
            _buildInfoCard(
              children: [
                _buildDetailRow(Icons.directions_boat, _tr('ship_name'), widget.application.shipName),
                _buildDetailRow(Icons.flag, _tr('flag'), widget.application.flag),
                _buildDetailRow(Icons.person, _tr('agent_name'), widget.application.agentName),
                _buildDetailRow(Icons.pin_drop, _tr('location'), widget.application.location ?? 'N/A'),
                _buildDetailRow(Icons.location_on, _tr('port'), widget.application.port ?? 'N/A'),
                _buildDetailRow(Icons.calendar_today, isKedatangan ? _tr('arrival_date') : _tr('departure_date'), widget.application.date ?? 'N/A'),
                _buildDetailRow(Icons.group, _tr('wni_crew'), widget.application.wniCrew ?? 'N/A'),
                _buildDetailRow(Icons.group, _tr('wna_crew'), widget.application.wnaCrew ?? 'N/A'),
              ],
            ),
            const SizedBox(height: 20),

            _buildSectionTitle(_tr('doc_verification')),
            _buildInfoCard(
              children: [
                _buildDocumentCheckbox(_tr('port_clearance')),
                _buildDocumentCheckbox(_tr('crew_list')),
                _buildDocumentCheckbox(_tr('notification_letter')),
              ],
            ),
            const SizedBox(height: 20),

            _buildSectionTitle(_tr('action')),
            _buildInfoCard(
              children: [
                ListTile(
                  leading: const Icon(Icons.cancel, color: Colors.red),
                  title: Text(_tr('reject_submission'), style: const TextStyle(color: Colors.red)),
                  onTap: () {
                    int index = UserService.agentHistory.indexWhere((app) =>
                        app.shipName == widget.application.shipName && app.date == widget.application.date && app.type == widget.application.type);
                    if (index != -1) {
                      setState(() {
                        UserService.agentHistory[index] = widget.application.copyWith(status: ApplicationStatus.declined, notes: "Pengajuan ditolak oleh petugas.");
                      });
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(_tr('rejected_success')),
                        backgroundColor: Colors.red,
                      ));
                    }
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _finishVerification,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(_tr('finish_verification'), style: const TextStyle(fontSize: 18, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildInfoCard({required List<Widget> children}) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: children,
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.blue),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontSize: 16)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentCheckbox(String documentName) {
    DocumentStatus status = _documentStatuses[documentName]!;
    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (status) {
      case DocumentStatus.pending:
        statusColor = Colors.grey;
        statusIcon = Icons.help_outline;
        statusText = _tr('status_pending');
        break;
      case DocumentStatus.approved:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle_outline;
        statusText = _tr('status_approved');
        break;
      case DocumentStatus.revisionNeeded:
        statusColor = Colors.orange;
        statusIcon = Icons.error_outline;
        statusText = _tr('status_revision');
        break;
    }

    return CheckboxListTile(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(documentName)),
          TextButton.icon(
            icon: const Icon(Icons.visibility_outlined, size: 16, color: Colors.blueGrey),
            label: Text(_tr('view'), style: const TextStyle(color: Colors.blueGrey)),
            onPressed: () => _showDocumentDialog(documentName),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
      subtitle: status == DocumentStatus.revisionNeeded && _revisionNotes.containsKey(documentName)
          ? Text("${_tr('notes')}: ${_revisionNotes[documentName]}", style: const TextStyle(color: Colors.orange, fontSize: 12))
          : Text(statusText, style: TextStyle(color: statusColor, fontSize: 12)),
      secondary: GestureDetector(
        onTap: () {
          if (status == DocumentStatus.revisionNeeded) {
            _showRevisionNotesDialog(documentName);
          }
        },
        child: Icon(statusIcon, color: statusColor),
      ),
      value: status == DocumentStatus.approved,
      onChanged: (bool? newValue) {
        setState(() {
          if (newValue == true) {
            _documentStatuses[documentName] = DocumentStatus.approved;
            _revisionNotes.remove(documentName);
          } else {
            showDialog(
              context: context,
              builder: (context) {
                return AlertDialog(
                  title: Text("${_tr('doc_verification')}: $documentName"),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        title: Text(_tr('status_revision')),
                        leading: const Icon(Icons.error_outline, color: Colors.orange),
                        onTap: () {
                          Navigator.pop(context);
                          setState(() {
                            _documentStatuses[documentName] = DocumentStatus.revisionNeeded;
                            _showRevisionNotesDialog(documentName);
                          });
                        },
                      ),
                      ListTile(
                        title: Text(_tr('status_pending')),
                        leading: const Icon(Icons.help_outline, color: Colors.grey),
                        onTap: () {
                          Navigator.pop(context);
                          setState(() {
                            _documentStatuses[documentName] = DocumentStatus.pending;
                            _revisionNotes.remove(documentName);
                          });
                        },
                      ),
                    ],
                  ),
                );
              },
            );
          }
        });
      },
    );
  }
}
