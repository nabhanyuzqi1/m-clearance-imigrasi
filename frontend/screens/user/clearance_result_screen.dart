import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/clearance_application.dart';

class ClearanceResultScreen extends StatelessWidget {
  final ClearanceApplication application;
  final String initialLanguage;

  const ClearanceResultScreen({
    super.key, 
    required this.application,
    this.initialLanguage = 'EN'
  });

  @override
  Widget build(BuildContext context) {
    final Map<String, Map<String, String>> translations = {
      'EN': {
        'title': 'Clearance Result',
        'print_simulation': 'Printing document... (simulation)',
        'share_simulation': 'Sharing document... (simulation)',
        'spb_title': 'Sailing Approval Letter',
        'immigration_office': 'Immigration Office Class II TPI Sampit',
        'approved_status': 'APPROVED',
        'approved_subtitle_arrival': 'The arrival clearance application has been approved.',
        'approved_subtitle_departure': 'The departure clearance application has been approved.',
        'ship_details': 'Ship Details',
        'ship_name': 'Ship Name',
        'flag': 'Flag',
        'agent': 'Agent',
        'voyage_details': 'Voyage Details',
        'last_port': 'Last Port',
        'next_port': 'Next Port',
        'eta': 'Arrival Date (ETA)',
        'etd': 'Departure Date (ETD)',
        'wni_crew': 'WNI Crew',
        'wna_crew': 'WNA Crew',
        'approved_by': 'Approved by Immigration Officer:',
        'officer_name': 'Officer Name',
        'approval_date': 'On Date:',
        'close_button': 'Close',
      },
      'ID': {
        'title': 'Hasil Clearance',
        'print_simulation': 'Mencetak dokumen... (simulasi)',
        'share_simulation': 'Membagikan dokumen... (simulasi)',
        'spb_title': 'Surat Persetujuan Berlayar',
        'immigration_office': 'Imigrasi Kelas II TPI Sampit',
        'approved_status': 'DISETUJUI',
        'approved_subtitle_arrival': 'Permohonan clearance kedatangan telah disetujui.',
        'approved_subtitle_departure': 'Permohonan clearance keberangkatan telah disetujui.',
        'ship_details': 'Detail Kapal',
        'ship_name': 'Nama Kapal',
        'flag': 'Bendera',
        'agent': 'Agen',
        'voyage_details': 'Detail Pelayaran',
        'last_port': 'Pelabuhan Asal',
        'next_port': 'Pelabuhan Tujuan',
        'eta': 'Tanggal Tiba (ETA)',
        'etd': 'Tanggal Berangkat (ETD)',
        'wni_crew': 'Kru WNI',
        'wna_crew': 'Kru WNA',
        'approved_by': 'Disetujui oleh Petugas Imigrasi:',
        'officer_name': 'Nama Petugas',
        'approval_date': 'Pada tanggal:',
        'close_button': 'Tutup',
      }
    };

    String tr(String key) => translations[initialLanguage]![key] ?? key;

    final officerName = application.officerName ?? "N/A";
    final approvalDate = DateFormat('dd MMMM yyyy').format(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('title')),
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(tr('print_simulation'))),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(tr('share_simulation'))),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildHeader(tr),
          const SizedBox(height: 24),
          _buildResultCard(tr),
          const SizedBox(height: 24),
          _buildDetailSection(tr('ship_details'), [
            _buildDetailRow(tr('ship_name'), application.shipName),
            _buildDetailRow(tr('flag'), application.flag),
            _buildDetailRow(tr('agent'), application.agentName),
          ]),
          const SizedBox(height: 24),
          _buildDetailSection(tr('voyage_details'), [
            _buildDetailRow(
              application.type == ApplicationType.kedatangan ? tr('last_port') : tr('next_port'),
              application.port ?? "N/A",
            ),
            _buildDetailRow(
              application.type == ApplicationType.kedatangan ? tr('eta') : tr('etd'),
              application.date ?? "N/A",
            ),
            _buildDetailRow(tr('wni_crew'), application.wniCrew ?? "0"),
            _buildDetailRow(tr('wna_crew'), application.wnaCrew ?? "0"),
          ]),
          const SizedBox(height: 32),
          _buildApprovalSection(officerName, approvalDate, tr),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(tr('close_button')),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(String Function(String) tr) {
    return Center(
      child: Column(
        children: [
          Image.asset(
            'assets/images/logo.png',
            height: 60,
            errorBuilder: (context, error, stackTrace) => const Icon(Icons.directions_boat, size: 60),
          ),
          const SizedBox(height: 8),
          Text(
            tr('spb_title'),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          Text(
            tr('immigration_office'),
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(String Function(String) tr) {
    return Card(
      elevation: 4,
      color: Colors.green,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 48),
            const SizedBox(height: 12),
            Text(
              tr('approved_status'),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              application.type == ApplicationType.kedatangan 
                ? tr('approved_subtitle_arrival') 
                : tr('approved_subtitle_departure'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailSection(String title, List<Widget> details) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const Divider(thickness: 1),
        const SizedBox(height: 8),
        ...details,
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.black54)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildApprovalSection(String officerName, String approvalDate, String Function(String) tr) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            tr('approved_by'),
            style: TextStyle(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 12),
          Text(
            officerName,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            "${tr('approval_date')} $approvalDate",
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 20),
          const Icon(Icons.verified_user, color: Colors.blue, size: 32),
        ],
      ),
    );
  }
}
