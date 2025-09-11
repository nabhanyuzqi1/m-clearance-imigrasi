import 'package:flutter/material.dart';
import '../../models/user_account.dart';
import '../../services/user_service.dart';
import 'account_detail_screen.dart';

enum AccountFilter { reviewed, waiting, all }

class AccountVerificationListScreen extends StatefulWidget {
  final String initialLanguage;
  const AccountVerificationListScreen({super.key, this.initialLanguage = 'EN'});
  @override
  State<AccountVerificationListScreen> createState() => _AccountVerificationListScreenState();
}

class _AccountVerificationListScreenState extends State<AccountVerificationListScreen> {
  AccountFilter _currentFilter = AccountFilter.all;
  late String _selectedLanguage;

  final Map<String, Map<String, String>> _translations = {
    'EN': {
      'title': 'Account Verification',
      'reviewed': 'Reviewed',
      'waiting': 'Waiting',
      'all': 'All',
      'no_data': 'No data for this filter.',
      'agent_name': 'Agent Name:',
      'verified': 'VERIFIED',
      'reviewed_rejected': 'REVIEWED - REJECTED',
      'review_submission': 'REVIEW SUBMISSION',
    },
    'ID': {
      'title': 'Verifikasi Akun',
      'reviewed': 'Ditinjau',
      'waiting': 'Menunggu',
      'all': 'Semua',
      'no_data': 'Tidak ada data untuk filter ini.',
      'agent_name': 'Nama Agen:',
      'verified': 'DIVERIFIKASI',
      'reviewed_rejected': 'DITINJAU - DITOLAK',
      'review_submission': 'TINJAU PENGAJUAN',
    }
  };

  String _tr(String key) => _translations[_selectedLanguage]![key] ?? key;
  
  @override
  void initState() {
    super.initState();
    _selectedLanguage = widget.initialLanguage;
  }

  List<UserAccount> _getFilteredList() {
    switch (_currentFilter) {
      case AccountFilter.waiting:
        return UserService.agentAccounts.where((user) => user.status == AccountStatus.pending).toList();
      case AccountFilter.reviewed:
        return UserService.agentAccounts.where((user) => user.status != AccountStatus.pending).toList();
      case AccountFilter.all:
        return UserService.agentAccounts;
    }
  }

  Future<void> _navigateToDetail(UserAccount user) async {
    final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => AccountDetailScreen(user: user, initialLanguage: _selectedLanguage,)));
    if (result != null && mounted) {
      setState(() {
        if (result == VerificationAction.verified) {
          user.status = AccountStatus.verified;
        } else if (result == VerificationAction.rejected) {
          user.status = AccountStatus.rejected;
        }
      });
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
                  _buildFilterButton(_tr('reviewed'), AccountFilter.reviewed),
                  _buildFilterButton(_tr('waiting'), AccountFilter.waiting),
                  _buildFilterButton(_tr('all'), AccountFilter.all),
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

  Widget _buildFilterButton(String text, AccountFilter filter) {
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
            boxShadow: isSelected ? [BoxShadow(color: Colors.black.withAlpha(25), blurRadius: 5, spreadRadius: 1)] : [],
          ),
          child: Center(
            child: Text(text, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: Colors.black)),
          ),
        ),
      ),
    );
  }

  Widget _buildVerificationItem(BuildContext context, UserAccount user) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_tr('agent_name'), style: const TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.person_pin_circle_outlined, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(user.email, style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Username: ${user.username}', style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            _buildStatusButton(context, user),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusButton(BuildContext context, UserAccount user) {
    String text;
    Color color;
    bool isWaiting = false;

    switch (user.status) {
      case AccountStatus.verified:
        text = _tr('verified');
        color = Colors.green;
        break;
      case AccountStatus.rejected:
        text = _tr('reviewed_rejected');
        color = Colors.red;
        break;
      case AccountStatus.pending:
        text = _tr('review_submission');
        color = Colors.blue;
        isWaiting = true;
        break;
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: user.status == AccountStatus.pending ? () => _navigateToDetail(user) : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: isWaiting ? color : color.withAlpha(25),
          foregroundColor: isWaiting ? Colors.white : color,
          disabledBackgroundColor: color.withAlpha(25),
          disabledForegroundColor: color,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        icon: const Icon(Icons.circle, color: Colors.white, size: 8),
        label: Text(text),
      ),
    );
  }
}
