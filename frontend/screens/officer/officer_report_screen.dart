import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/user_service.dart';
import '../../models/clearance_application.dart';

class OfficerReportScreen extends StatefulWidget {
  final String initialLanguage;
  const OfficerReportScreen({super.key, this.initialLanguage = 'EN'});

  @override
  State<OfficerReportScreen> createState() => _OfficerReportScreenState();
}

class _OfficerReportScreenState extends State<OfficerReportScreen> {
   late String _selectedLanguage;

  final Map<String, Map<String, String>> _translations = {
    'EN': {
      'title': 'Officer Report',
      'daily_monthly_report': 'Daily & Monthly Report',
      'today': 'Today',
      'this_month': 'This Month',
      'arrival': 'Arrival',
      'departure': 'Departure',
      'registration': 'Registration',
      'daily_report': 'Daily Report',
      'create_new_report': 'Create New Report',
      'generating_pdf': 'Generating .pdf',
      'pdf_generation_simulation': 'Creating PDF report... (simulation)',
      'report_history': 'Report History',
      'created_by': 'Created by',
      'see_details': 'SEE DETAILS',
      'daily_report_type': 'Daily Report',
      'monthly_report_type': 'Monthly Report',
    },
    'ID': {
      'title': 'Laporan Petugas',
      'daily_monthly_report': 'Laporan Harian & Bulanan',
      'today': 'Hari Ini',
      'this_month': 'Bulan Ini',
      'arrival': 'Kedatangan',
      'departure': 'Keberangkatan',
      'registration': 'Pendaftaran',
      'daily_report': 'Laporan Harian',
      'create_new_report': 'Buat Laporan Baru',
      'generating_pdf': 'Membuat .pdf',
      'pdf_generation_simulation': 'Membuat laporan PDF... (simulasi)',
      'report_history': 'Riwayat Laporan',
      'created_by': 'Dibuat oleh',
      'see_details': 'LIHAT DETAIL',
      'daily_report_type': 'Laporan Harian',
      'monthly_report_type': 'Laporan Bulanan',
    }
  };

  String _tr(String key) => _translations[_selectedLanguage]![key] ?? key;

  @override
  void initState() {
    super.initState();
    _selectedLanguage = widget.initialLanguage;
  }
  
  final List<Map<String, String>> _reportHistory = [
    {"typeKey": "daily_report_type", "date": "10 September 2025", "createdBy": "Maulana Akbar"},
    {"typeKey": "monthly_report_type", "date": "August 2025", "createdBy": "Maulana Akbar"}
  ];

  DateTime? _parseDate(String? dateString) {
    if (dateString == null) return null;
    try {
      return DateFormat('dd MMMM yyyy').parse(dateString);
    } catch (e) {
      try {
        return DateFormat('dd-MM-yyyy').parse(dateString);
      } catch (e) {
        print("Gagal mem-parsing tanggal: $dateString");
        return null;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);
    final startOfMonth = DateTime(today.year, today.month, 1);

    int todayArrival = 0;
    int todayDeparture = 0;
    int monthArrival = 0;
    int monthDeparture = 0;

    for (var app in UserService.agentHistory) {
      final appDate = _parseDate(app.date);
      if (appDate != null) {
        if (appDate.year == startOfToday.year && appDate.month == startOfToday.month && appDate.day == startOfToday.day) {
          if (app.type == ApplicationType.kedatangan) todayArrival++;
          if (app.type == ApplicationType.keberangkatan) todayDeparture++;
        }
        if (appDate.year == startOfMonth.year && appDate.month == startOfMonth.month) {
          if (app.type == ApplicationType.kedatangan) monthArrival++;
          if (app.type == ApplicationType.keberangkatan) monthDeparture++;
        }
      }
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(_tr('title'), style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        leading: const BackButton(color: Colors.black),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.blue),
            onPressed: () {},
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildSectionTitle(_tr('daily_monthly_report')),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildStatCard(_tr('today'), "${_tr('arrival')}: $todayArrival\n${_tr('departure')}: $todayDeparture\n${_tr('registration')}: 0"),
              const SizedBox(width: 16),
              _buildStatCard(_tr('this_month'), "${_tr('arrival')}: $monthArrival\n${_tr('departure')}: $monthDeparture\n${_tr('registration')}: 2"),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildStatCard(_tr('arrival'), "Bagendang"),
              const SizedBox(width: 16),
              _buildStatCard(_tr('departure'), "Bagendang"),
            ],
          ),
          const SizedBox(height: 24),
          Text(_tr('daily_report'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              title: Text(_tr('create_new_report'), style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(_tr('generating_pdf')),
              trailing: IconButton(
                icon: const Icon(Icons.send, color: Colors.blue),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_tr('pdf_generation_simulation')), backgroundColor: Colors.green));
                },
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionTitle(_tr('report_history')),
          const SizedBox(height: 16),
          ..._reportHistory.map((report) => _buildReportHistoryItem(
            type: _tr(report["typeKey"]!),
            date: report["date"]!,
            createdBy: report["createdBy"]!,
          )),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87));
  }

  Widget _buildStatCard(String title, String subtitle) {
    return Expanded(
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              Text(subtitle, style: TextStyle(color: Colors.grey.shade600, height: 1.5)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReportHistoryItem({required String type, required String date, required String createdBy}) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(type, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            Text(date, style: const TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_tr('created_by'), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    Text(createdBy, style: const TextStyle(fontWeight: FontWeight.w500)),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  icon: const Icon(Icons.circle, color: Colors.white, size: 8),
                  label: Text(_tr('see_details')),
                )
              ],
            )
          ],
        ),
      ),
    );
  }
}
