import 'dart:io';
import 'package:flutter/material.dart';
import '../../models/clearance_application.dart';
import '../../models/user_account.dart';
import '../../services/notification_service.dart';
import '../../services/user_service.dart';
import '../auth/change_password_screen.dart';
import '../auth/login_screen.dart';
import 'clearance_form_screen.dart';
import 'clearance_result_screen.dart';
import 'edit_agent_profile_screen.dart';
import 'notification_screen.dart';

class UserHomeScreen extends StatefulWidget {
  final String username;
  const UserHomeScreen({super.key, required this.username});
  @override
  State<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends State<UserHomeScreen> {
  int _selectedIndex = 0;
  // PERBAIKAN: currentUser dibuat nullable untuk menangani kasus jika user tidak ditemukan.
  UserAccount? currentUser; 
  String _selectedLanguage = 'EN';

  final Map<String, Map<String, String>> _translations = {
    'EN': { 'home': 'Home', 'history': 'History', 'settings': 'Settings' },
    'ID': { 'home': 'Beranda', 'history': 'Riwayat', 'settings': 'Pengaturan' }
  };

  String _tr(String key) => _translations[_selectedLanguage]![key] ?? key;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  // PERBAIKAN: Mencari user dengan cara yang lebih aman menggunakan try-catch
  // untuk mencegah aplikasi crash jika username tidak ditemukan.
  void _loadCurrentUser() {
    try {
      currentUser = UserService.agentAccounts.firstWhere((acc) => acc.username == widget.username);
    } catch (e) {
      currentUser = null;
      // Jika user tidak ditemukan, kembali ke halaman login.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if(mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const LoginScreen()),
            (Route<dynamic> route) => false,
          );
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Error: Sesi pengguna tidak ditemukan. Silakan masuk kembali."), backgroundColor: Colors.red),
          );
        }
      });
    }
    if (mounted) {
      setState(() {});
    }
  }

  void _refresh() {
    setState(() {
      _loadCurrentUser();
    });
  }
  
  void _changeLanguage(String langCode) => setState(() => _selectedLanguage = langCode);
  void _onItemTapped(int index) => setState(() => _selectedIndex = index);

  @override
  Widget build(BuildContext context) {
    // Menampilkan loading indicator jika data user belum siap.
    if (currentUser == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final List<Widget> pages = <Widget>[
      AgentMenuScreen(agentAccount: currentUser!, initialLanguage: _selectedLanguage),
      AgentHistoryScreen(agentAccount: currentUser!, initialLanguage: _selectedLanguage),
      AgentProfileScreen(
        agentAccount: currentUser!,
        onRefresh: _refresh,
        selectedLanguage: _selectedLanguage,
        onLanguageChange: _changeLanguage,
      ),
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      body: pages.elementAt(_selectedIndex),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: const Icon(Icons.home_filled), label: _tr('home')),
          BottomNavigationBarItem(icon: const Icon(Icons.history), label: _tr('history')),
          BottomNavigationBarItem(icon: const Icon(Icons.settings), label: _tr('settings')),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        backgroundColor: Colors.white,
        elevation: 8,
      ),
    );
  }
}

// Sisa widget di bawah ini tidak memiliki error dan tidak diubah.
class AgentMenuScreen extends StatelessWidget {
  final UserAccount agentAccount;
  final String initialLanguage;
  const AgentMenuScreen({super.key, required this.agentAccount, required this.initialLanguage});
  
  @override
  Widget build(BuildContext context) {
     final Map<String, Map<String, String>> screenTranslations = {
      'EN': { 'welcome': 'Welcome,', 'last_transactions': 'Last Transactions', 'no_transactions': 'No recent transactions yet.', 'arrival': 'Arrival', 'departure': 'Departure', 'last_port': 'Last Port', 'next_port': 'Next Port', },
      'ID': { 'welcome': 'Selamat Datang,', 'last_transactions': 'Transaksi Terakhir', 'no_transactions': 'Belum ada transaksi terakhir.', 'arrival': 'Kedatangan', 'departure': 'Keberangkatan', 'last_port': 'Pelabuhan Asal', 'next_port': 'Pelabuhan Tujuan', }
    };

    String screenTr(String key) => screenTranslations[initialLanguage]![key] ?? key;

    final int unreadNotifications = NotificationService.unreadCount;
    final List<ClearanceApplication> lastTwoTransactions = UserService.agentHistory.where((app) => app.agentName == agentAccount.name).take(2).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset('assets/images/logo.png', height: 32, errorBuilder: (context, error, stackTrace) => const Icon(Icons.directions_boat)),
            const SizedBox(width: 8),
            const Text('Isam - Travel Planner', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none_outlined),
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => NotificationScreen(initialLanguage: initialLanguage)));
                },
              ),
              if (unreadNotifications > 0)
                Positioned(
                  right: 8, top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text('$unreadNotifications', style: const TextStyle(color: Colors.white, fontSize: 10), textAlign: TextAlign.center),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.grey.shade200,
                backgroundImage: UserService.currentProfileImagePath != null ? FileImage(File(UserService.currentProfileImagePath!)) : null,
                child: UserService.currentProfileImagePath == null ? const Icon(Icons.person, size: 30, color: Colors.grey) : null,
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(screenTr('welcome'), style: const TextStyle(fontSize: 16, color: Colors.grey)),
                  Text(agentAccount.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildServiceCard(context, title: screenTr('arrival'), subtitle: screenTr('last_port'), iconData: Icons.anchor, color: Colors.blue, isPrimary: true,
            onTap: () { Navigator.push(context, MaterialPageRoute(builder: (context) => ClearanceFormScreen(type: ApplicationType.kedatangan, agentName: agentAccount.name, initialLanguage: initialLanguage))); },
          ),
          const SizedBox(height: 16),
          _buildServiceCard(context, title: screenTr('departure'), subtitle: screenTr('next_port'), iconData: Icons.directions_boat, color: Colors.black87, isPrimary: false,
            onTap: () { Navigator.push(context, MaterialPageRoute(builder: (context) => ClearanceFormScreen(type: ApplicationType.keberangkatan, agentName: agentAccount.name, initialLanguage: initialLanguage))); },
          ),
          const SizedBox(height: 32),
          Text(screenTr('last_transactions'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          if (lastTwoTransactions.isEmpty)
            Center(child: Padding(padding: const EdgeInsets.symmetric(vertical: 24.0), child: Text(screenTr('no_transactions'), style: const TextStyle(color: Colors.grey))))
          else
            ...lastTwoTransactions.map((app) => _buildTransactionItem(context, type: app.type == ApplicationType.kedatangan ? screenTr('arrival') : screenTr('departure'), detail: "${app.shipName} - ${app.port ?? 'N/A'}", date: "(${app.date ?? 'No Date'})")),
        ],
      ),
    );
  }
  Widget _buildServiceCard(BuildContext context, {required String title, required String subtitle, required IconData iconData, required Color color, required bool isPrimary, required VoidCallback onTap}) { return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(16), child: Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: isPrimary ? color : Colors.white, borderRadius: BorderRadius.circular(16), border: isPrimary ? null : Border.all(color: Colors.grey.shade300), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))]), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isPrimary ? Colors.white : color)), const SizedBox(height: 4), Text(subtitle, style: TextStyle(fontSize: 16, color: isPrimary ? Colors.white70 : Colors.grey))]), Icon(iconData, size: 32, color: isPrimary ? Colors.white : color)]))); }
  Widget _buildTransactionItem(BuildContext context, {required String type, required String detail, required String date}) { return Padding(padding: const EdgeInsets.only(bottom: 12.0), child: Row(children: [const Icon(Icons.star, color: Colors.blue, size: 20), const SizedBox(width: 12), Expanded(child: RichText(text: TextSpan(style: const TextStyle(fontSize: 16, color: Colors.black), children: [TextSpan(text: '$type: ', style: const TextStyle(fontWeight: FontWeight.bold)), TextSpan(text: '$detail '), TextSpan(text: date, style: const TextStyle(color: Colors.grey))])))])); }
}

enum HistoryFilter { arrival, departure, all }
class AgentHistoryScreen extends StatefulWidget {
  final UserAccount agentAccount;
  final String initialLanguage;
  const AgentHistoryScreen({super.key, required this.agentAccount, required this.initialLanguage});
  @override
  State<AgentHistoryScreen> createState() => _AgentHistoryScreenState();
}
class _AgentHistoryScreenState extends State<AgentHistoryScreen> {
  HistoryFilter _currentFilter = HistoryFilter.all;

  final Map<String, Map<String, String>> _screenTranslations = {
      'EN': { 'history': 'History', 'arrival': 'Arrival', 'departure': 'Departure', 'all': 'All', 'empty_title': 'Nothing here. For now.', 'empty_subtitle': "This is where you'll find your\nfinished application.", 'waiting': 'WAITING FOR VERIFICATION', 'revision': 'REQUIRES FIXING', 'approved': 'ACCEPTED', 'declined': 'DECLINED', 'arrival_detail': 'Arrival Detail', 'departure_detail': 'Departure Detail', 'about': 'About', 'last_port': 'Last Port', 'next_port': 'Next Port', 'crewlist': 'Crewlist', 'agent': 'Agent', 'note_by_officer': 'Note By Officer', 'need_fix': 'Need Fix', 'no_notes': 'No notes.', 'fix_button': 'Fix', 'done_button': 'Done', 'reports_button': 'See Reports', },
      'ID': { 'history': 'Riwayat', 'arrival': 'Kedatangan', 'departure': 'Keberangkatan', 'all': 'Semua', 'empty_title': 'Tidak ada apa-apa. Untuk saat ini.', 'empty_subtitle': 'Di sinilah Anda akan menemukan\nriwayat pengajuan Anda.', 'waiting': 'MENUNGGU VERIFIKASI', 'revision': 'PERLU DIPERBAIKI', 'approved': 'DITERIMA', 'declined': 'DITOLAK', 'arrival_detail': 'Detail Kedatangan', 'departure_detail': 'Detail Keberangkatan', 'about': 'Tentang', 'last_port': 'Pelabuhan Asal', 'next_port': 'Pelabuhan Tujuan', 'crewlist': 'Daftar Kru', 'agent': 'Agen', 'note_by_officer': 'Catatan dari Petugas', 'need_fix': 'Perlu Perbaikan', 'no_notes': 'Tidak ada catatan.', 'fix_button': 'Perbaiki', 'done_button': 'Selesai', 'reports_button': 'Lihat Laporan', }
  };

  String _screenTr(String key) => _screenTranslations[widget.initialLanguage]![key] ?? key;

  List<ClearanceApplication> _getFilteredList() {
    final myHistory = UserService.agentHistory.where((app) => app.agentName == widget.agentAccount.name).toList();
    switch (_currentFilter) {
      case HistoryFilter.arrival: return myHistory.where((app) => app.type == ApplicationType.kedatangan).toList();
      case HistoryFilter.departure: return myHistory.where((app) => app.type == ApplicationType.keberangkatan).toList();
      case HistoryFilter.all: default: return myHistory;
    }
  }
  @override
  Widget build(BuildContext context) {
    final filteredList = _getFilteredList();
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(_screenTr("history"), style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [IconButton(icon: const Icon(Icons.search, color: Colors.blue), onPressed: () {})],
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
            child: Container(
              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(24)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildFilterButton(_screenTr('arrival'), HistoryFilter.arrival),
                  _buildFilterButton(_screenTr('departure'), HistoryFilter.departure),
                  _buildFilterButton(_screenTr('all'), HistoryFilter.all),
                ],
              ),
            ),
          ),
          Expanded(
            child: filteredList.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: filteredList.length,
                    itemBuilder: (context, index) { return _buildHistoryItem(context, filteredList[index]); },
                  ),
          ),
        ],
      ),
    );
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
  Widget _buildHistoryItem(BuildContext context, ClearanceApplication app) {
    return GestureDetector(
      onTap: () => _showHistoryDetailDialog(context, app),
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
                      Text(app.type == ApplicationType.kedatangan ? _screenTr('arrival') : _screenTr('departure'), style: const TextStyle(fontWeight: FontWeight.bold)),
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
  Widget _buildEmptyState() {
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
          Text(_screenTr('empty_title'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(_screenTr('empty_subtitle'), textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
        ],
      ),
    );
  }
  String _getStatusText(ApplicationStatus status) { switch (status) { case ApplicationStatus.waiting: return _screenTr('waiting'); case ApplicationStatus.revision: return _screenTr('revision'); case ApplicationStatus.approved: return _screenTr('approved'); case ApplicationStatus.declined: return _screenTr('declined'); } }
  Color _getStatusColor(ApplicationStatus status) { switch (status) { case ApplicationStatus.waiting: return Colors.blue; case ApplicationStatus.revision: return Colors.orange; case ApplicationStatus.approved: return Colors.green; case ApplicationStatus.declined: return Colors.red; } }
  void _showHistoryDetailDialog(BuildContext context, ClearanceApplication app) { showDialog(context: context, builder: (BuildContext context) { return AlertDialog(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), title: _buildDialogTitle(app), content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [_buildAboutSection(app), const SizedBox(height: 16), _buildAgentSection(app), const SizedBox(height: 16), _buildNoteSection(app)])), actions: [_buildDialogActions(context, app)]); }); }
  Widget _buildDialogTitle(ClearanceApplication app) { final title = app.type == ApplicationType.kedatangan ? _screenTr('arrival_detail') : _screenTr('departure_detail'); return Center(child: Column(children: [Text(title, style: const TextStyle(fontWeight: FontWeight.bold)), Text(app.shipName, style: const TextStyle(fontSize: 14, color: Colors.grey)), const Divider()])); }
  Widget _buildAboutSection(ClearanceApplication app) { final isArrival = app.type == ApplicationType.kedatangan; return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_screenTr('about'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), const SizedBox(height: 8), Text("${isArrival ? _screenTr('last_port') : _screenTr('next_port')}: ${app.port ?? 'N/A'}, ${app.flag}"), Text("${_screenTr('crewlist')}: ${app.wniCrew ?? '0'} WNI - ${app.wnaCrew ?? '0'} WNA")]); }
  Widget _buildAgentSection(ClearanceApplication app) { return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_screenTr('agent'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), const SizedBox(height: 8), Row(children: [const CircleAvatar(radius: 12, child: Icon(Icons.person, size: 14)), const SizedBox(width: 8), Text(app.agentName)])]); }
  Widget _buildNoteSection(ClearanceApplication app) { if (app.status == ApplicationStatus.waiting || app.status == ApplicationStatus.approved) { return const SizedBox.shrink(); } return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_screenTr('note_by_officer'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), const SizedBox(height: 8), Text(app.status == ApplicationStatus.revision ? "${_screenTr('need_fix')} - ${app.notes ?? _screenTr('no_notes')}" : app.status == ApplicationStatus.declined ? "${_screenTr('declined')} - ${app.notes ?? _screenTr('no_notes')}" : "", style: const TextStyle(color: Colors.red))]); }
  Widget _buildDialogActions(BuildContext context, ClearanceApplication app) { switch (app.status) { case ApplicationStatus.revision: return ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.orange), onPressed: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => ClearanceFormScreen(type: app.type, agentName: app.agentName, existingApplication: app, initialLanguage: widget.initialLanguage))); }, child: Text(_screenTr('fix_button'))); case ApplicationStatus.declined: return ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.pop(context), child: Text(_screenTr('done_button'))); case ApplicationStatus.approved: return ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.blue), onPressed: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => ClearanceResultScreen(application: app, initialLanguage: widget.initialLanguage))); }, child: Text(_screenTr('reports_button'))); case ApplicationStatus.waiting: default: return TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK")); } }
}

class AgentProfileScreen extends StatefulWidget {
  final UserAccount agentAccount;
  final VoidCallback onRefresh;
  final String selectedLanguage;
  final Function(String) onLanguageChange;

  const AgentProfileScreen({
    super.key,
    required this.agentAccount,
    required this.onRefresh,
    required this.selectedLanguage,
    required this.onLanguageChange,
  });

  @override
  State<AgentProfileScreen> createState() => _AgentProfileScreenState();
}

class _AgentProfileScreenState extends State<AgentProfileScreen> {
  late UserAccount _currentAgentAccount;
  late String _currentLanguage;

  final Map<String, Map<String, String>> _screenTranslations = {
    'EN': { 'settings': 'Settings', 'notifications': 'Notifications', 'language': 'Language', 'privacy_security': 'Privacy & Security', 'change_password': 'Change Password', 'logout': 'Logout', 'logout_confirm_title': 'Logout', 'logout_confirm_body': 'Are you sure you want to logout?', 'cancel': 'Cancel', },
    'ID': { 'settings': 'Pengaturan', 'notifications': 'Notifikasi', 'language': 'Bahasa', 'privacy_security': 'Privasi & Keamanan', 'change_password': 'Ubah Password', 'logout': 'Keluar', 'logout_confirm_title': 'Keluar', 'logout_confirm_body': 'Apakah Anda yakin ingin keluar?', 'cancel': 'Batal', }
  };

  String _screenTr(String key) => _screenTranslations[_currentLanguage]![key] ?? key;

  @override
  void initState() {
    super.initState();
    _currentAgentAccount = widget.agentAccount;
    _currentLanguage = widget.selectedLanguage;
  }

  @override
  void didUpdateWidget(covariant AgentProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.agentAccount != oldWidget.agentAccount) {
      _currentAgentAccount = widget.agentAccount;
    }
    if (widget.selectedLanguage != oldWidget.selectedLanguage) {
      _currentLanguage = widget.selectedLanguage;
    }
    setState(() {});
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Center(child: Text(_screenTr('logout_confirm_title'), style: const TextStyle(fontWeight: FontWeight.bold))),
          content: Text(_screenTr('logout_confirm_body'), textAlign: TextAlign.center),
          actionsAlignment: MainAxisAlignment.center,
          actions: <Widget>[
            OutlinedButton(
              style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), side: BorderSide(color: Colors.red.shade200), padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12)),
              child: Text(_screenTr('cancel'), style: const TextStyle(color: Colors.red)),
              onPressed: () { Navigator.of(dialogContext).pop(); },
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade400, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12)),
              child: Text(_screenTr('logout'), style: const TextStyle(color: Colors.white)),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginScreen()), (Route<dynamic> route) => false);
              },
            )
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(_screenTr("settings")),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        children: [
          const SizedBox(height: 24),
          Column(
            children: [
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.blue.shade100,
                    backgroundImage: UserService.currentProfileImagePath != null ? FileImage(File(UserService.currentProfileImagePath!)) : null,
                    child: UserService.currentProfileImagePath == null ? Icon(Icons.person, size: 60, color: Colors.blue.shade800) : null,
                  ),
                  InkWell(
                    onTap: () async {
                      final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => EditAgentProfileScreen(
                        username: _currentAgentAccount.username,
                        currentName: _currentAgentAccount.name,
                        currentEmail: _currentAgentAccount.email,
                        initialLanguage: _currentLanguage,
                      )));
                      if (result == true) {
                        widget.onRefresh();
                      }
                    },
                    child: Container(
                      decoration: BoxDecoration(color: Colors.blue, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                      padding: const EdgeInsets.all(4),
                      child: const Icon(Icons.edit, color: Colors.white, size: 16),
                    ),
                  )
                ],
              ),
              const SizedBox(height: 16),
              Text(_currentAgentAccount.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text("@${_currentAgentAccount.username}", style: const TextStyle(fontSize: 16, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 32),
          _buildProfileMenu(context, title: _screenTr('notifications'), icon: Icons.notifications_none_outlined, onTap: () async {
             await Navigator.push(context, MaterialPageRoute(builder: (context) => NotificationScreen(initialLanguage: _currentLanguage)));
             widget.onRefresh();
          }),
          const Divider(indent: 16, endIndent: 16),
          _buildLanguageSection(),
          const Divider(indent: 16, endIndent: 16),
          _buildProfileMenu(context, title: _screenTr('privacy_security'), icon: Icons.lock_outline),
          const Divider(indent: 16, endIndent: 16),
          _buildProfileMenu(
            context,
            title: _screenTr('change_password'),
            icon: Icons.password_outlined,
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => ChangePasswordScreen(initialLanguage: _currentLanguage)));
            },
          ),
          const Divider(height: 32, indent: 16, endIndent: 16),
          _buildProfileMenu(context, title: _screenTr('logout'), icon: Icons.logout, isLogout: true, onTap: () { _showLogoutDialog(context); }),
        ],
      ),
    );
  }

  Widget _buildLanguageSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16.0),
            child: Text(_screenTr('language'), style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w500, fontSize: 16)),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildLanguageButton('EN', 'English')),
              const SizedBox(width: 12),
              Expanded(child: _buildLanguageButton('ID', 'Indonesia')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageButton(String code, String name) {
    final isSelected = _currentLanguage == code;
    return OutlinedButton(
      onPressed: () {
        widget.onLanguageChange(code);
      },
      style: OutlinedButton.styleFrom(
        backgroundColor: isSelected ? Colors.blue.withOpacity(0.1) : Colors.transparent,
        side: BorderSide(color: isSelected ? Colors.blue : Colors.grey.shade300, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(name, style: TextStyle(color: isSelected ? Colors.blue.shade800 : Colors.black87, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
    );
  }

  Widget _buildProfileMenu(BuildContext context, {required String title, required IconData icon, bool isLogout = false, VoidCallback? onTap}) {
    return ListTile(
      leading: Icon(icon, color: isLogout ? Colors.red : Colors.grey.shade600),
      title: Text(title, style: TextStyle(color: isLogout ? Colors.red : Colors.black, fontWeight: FontWeight.w500)),
      trailing: isLogout ? null : const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap ?? () { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Halaman "$title" belum tersedia.'))); },
    );
  }
}
