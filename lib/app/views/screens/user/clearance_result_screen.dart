import 'package:flutter/material.dart';
import '../../../localization/app_strings.dart';
import '../../../models/clearance_application.dart';

class ClearanceResultScreen extends StatelessWidget {
  final ClearanceApplication application;
  final String initialLanguage;

  const ClearanceResultScreen({
    super.key,
    required this.application,
    required this.initialLanguage,
  });

  @override
  Widget build(BuildContext context) {
    final Map<String, Map<String, String>> translations = {
      'EN': {
        'application_submitted': 'Application Submitted',
        'application_details': 'Application Details',
        'ship_name': 'Ship Name',
        'flag': 'Flag',
        'type': 'Type',
        'port': 'Port',
        'date': 'Date',
        'wni_crew': 'WNI Crew',
        'wna_crew': 'WNA Crew',
        'officer_name': 'Officer Name',
        'location': 'Location',
        'status': 'Status',
        'notes': 'Notes',
        'arrival': 'Arrival',
        'departure': 'Departure',
        'waiting': 'Waiting for Verification',
        'approved': 'Approved',
        'revision': 'Requires Revision',
        'declined': 'Declined',
        'back_to_home': 'Back to Home',
        'view_reports': 'View Reports',
        'edit_application': 'Edit Application',
        'application_id': 'Application ID',
        'submitted_at': 'Submitted At',
        'no_notes': 'No additional notes',
      },
      'ID': {
        'application_submitted': 'Permohonan Dikirim',
        'application_details': 'Detail Permohonan',
        'ship_name': 'Nama Kapal',
        'flag': 'Bendera',
        'type': 'Tipe',
        'port': 'Pelabuhan',
        'date': 'Tanggal',
        'wni_crew': 'ABK WNI',
        'wna_crew': 'ABK WNA',
        'officer_name': 'Nama Petugas',
        'location': 'Lokasi',
        'status': 'Status',
        'notes': 'Catatan',
        'arrival': 'Kedatangan',
        'departure': 'Keberangkatan',
        'waiting': 'Menunggu Verifikasi',
        'approved': 'Disetujui',
        'revision': 'Perlu Revisi',
        'declined': 'Ditolak',
        'back_to_home': 'Kembali ke Beranda',
        'view_reports': 'Lihat Laporan',
        'edit_application': 'Edit Permohonan',
        'application_id': 'ID Permohonan',
        'submitted_at': 'Dikirim Pada',
        'no_notes': 'Tidak ada catatan tambahan',
      }
    };

    String tr(String key) => translations[initialLanguage]![key] ?? key;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(tr('application_submitted')),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Success Icon and Message
            Center(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 64,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    tr('application_submitted'),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Application ID: ${application.id}',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Application Details Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('application_details'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Ship Information
                    _buildDetailRow(tr('ship_name'), application.shipName),
                    _buildDetailRow(tr('flag'), application.flag),
                    _buildDetailRow(tr('type'),
                      application.type == ApplicationType.kedatangan
                          ? tr('arrival')
                          : tr('departure')
                    ),

                    if (application.port != null)
                      _buildDetailRow(tr('port'), application.port!),

                    if (application.date != null)
                      _buildDetailRow(tr('date'), application.date!),

                    // Crew Information
                    if (application.wniCrew != null)
                      _buildDetailRow(tr('wni_crew'), application.wniCrew!),

                    if (application.wnaCrew != null)
                      _buildDetailRow(tr('wna_crew'), application.wnaCrew!),

                    // Officer Information
                    if (application.officerName != null)
                      _buildDetailRow(tr('officer_name'), application.officerName!),

                    if (application.location != null)
                      _buildDetailRow(tr('location'), application.location!),

                    // Status
                    _buildDetailRow(tr('status'), _getStatusText(application.status, tr)),

                    // Notes
                    if (application.notes != null && application.notes!.isNotEmpty)
                      _buildDetailRow(tr('notes'), application.notes!)
                    else
                      _buildDetailRow(tr('notes'), tr('no_notes')),

                    // Submitted At
                    _buildDetailRow(
                      tr('submitted_at'),
                      '${application.createdAt.day}/${application.createdAt.month}/${application.createdAt.year} ${application.createdAt.hour}:${application.createdAt.minute.toString().padLeft(2, '0')}'
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(tr('back_to_home')),
                  ),
                ),
                const SizedBox(width: 16),
                if (application.status == ApplicationStatus.approved)
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        // TODO: Navigate to reports screen
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Reports feature coming soon')),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(tr('view_reports')),
                    ),
                  )
                else if (application.status == ApplicationStatus.revision)
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        // Navigate back to form for editing
                        Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(tr('edit_application')),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusText(ApplicationStatus status, String Function(String) tr) {
    switch (status) {
      case ApplicationStatus.waiting:
        return tr('waiting');
      case ApplicationStatus.approved:
        return tr('approved');
      case ApplicationStatus.revision:
        return tr('revision');
      case ApplicationStatus.declined:
        return tr('declined');
    }
  }
}