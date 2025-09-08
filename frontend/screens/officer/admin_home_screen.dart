import 'dart:io';
import 'package:flutter/material.dart';
import '../../services/user_service.dart';
import '../auth/change_password_screen.dart';
import '../auth/login_screen.dart';
import 'account_verification_list_screen.dart';
import 'arrival_verification_screen.dart';
import 'departure_verification_screen.dart';
import 'edit_profile_screen.dart';
import 'officer_report_screen.dart';
import 'notification_screen.dart';

// CATATAN: File ini sebagian besar sudah benar setelah perbaikan yang Anda lakukan.
// Perubahan di sini hanya untuk memastikan konsistensi dan menghilangkan potensi
// masalah kecil seperti 'const' pada constructor yang tidak perlu.

class AdminHomeScreen extends StatefulWidget {
  final String adminName;
  final String adminUsername;
  
  AdminHomeScreen({super.key, required this.adminName, required this.adminUsername});
  
  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _selectedIndex = 0;
  String _selectedLanguage = 'EN';

  final Map<String, Map<String, String>> _translations = {
    'EN': { 'home': 'Home', 'report': 'Report', 'settings': 'Settings' },
    'ID': { 'home': 'Beranda', 'report': 'Laporan', 'settings': 'Pengaturan' }
  };

  String _tr(String key) => _translations[_selectedLanguage]![key] ?? key;
  
  void _changeLanguage(String langCode) => setState(() => _selectedLanguage = langCode);
  void _onItemTapped(int index) => setState(() => _selectedIndex = index);

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = <Widget>[
      AdminMenuScreen(adminName: widget.adminName, initialLanguage: _selectedLanguage),
      OfficerReportScreen(initialLanguage: _selectedLanguage),
      ProfileScreen(
        adminName: widget.adminName,
        adminUsername: widget.adminUsername,
        selectedLanguage: _selectedLanguage,
        onLanguageChange: _changeLanguage,
      ),
    ];
    
    return Scaffold(
      backgroundColor: Colors.white,
      body: pages.elementAt(_selectedIndex),
      bottomNavigationBar: BottomNavigationBar(
        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: const Icon(Icons.home_filled), label: _tr('home')),
          BottomNavigationBarItem(icon: const Icon(Icons.assessment_outlined), label: _tr('report')),
          BottomNavigationBarItem(icon: const Icon(Icons.settings), label: _tr('settings')),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
      ),
    );
  }
}

class AdminMenuScreen extends StatelessWidget {
  final String adminName;
  final String initialLanguage;
  const AdminMenuScreen({super.key, required this.adminName, required this.initialLanguage});
  
  @override
  Widget build(BuildContext context) {
     final Map<String, Map<String, String>> translations = {
      'EN': { 'welcome': 'Welcome,', 'officer': 'Officer', 'arrival_verification': 'Arrival Verification', 'departure_verification': 'Departure Verification', 'account_verification': 'Account Verification', 'agent_submissions': 'Agent Submissions Check', 'agent_registrations': 'Agent Registrations Check' },
      'ID': { 'welcome': 'Selamat Datang,', 'officer': 'Petugas', 'arrival_verification': 'Verifikasi Kedatangan', 'departure_verification': 'Verifikasi Keberangkatan', 'account_verification': 'Verifikasi Akun', 'agent_submissions': 'Pemeriksaan Pengajuan Agen', 'agent_registrations': 'Pemeriksaan Registrasi Agen' }
    };
    String tr(String key) => translations[initialLanguage]![key] ?? key;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            Image.asset('assets/images/logo.png', height: 32,
              errorBuilder: (context, error, stackTrace) => const Icon(Icons.directions_boat),
            ),
            const SizedBox(width: 8),
            const Text('Imigrasi Kelas II Sampit', style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_outlined, color: Colors.black54),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => OfficerNotificationScreen(initialLanguage: initialLanguage)));
            },
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
                backgroundImage: UserService.officerProfileImagePath != null ? FileImage(File(UserService.officerProfileImagePath!)) : null,
                child: UserService.officerProfileImagePath == null ? const Icon(Icons.person, size: 30, color: Colors.grey) : null,
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr('welcome'), style: const TextStyle(fontSize: 16, color: Colors.grey)),
                  Text("$adminName - ${tr('officer')}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildServiceCard(context, title: tr('arrival_verification'), subtitle: tr('agent_submissions'), iconData: Icons.anchor, color: Colors.blue, isPrimary: true,
            onTap: () { Navigator.push(context, MaterialPageRoute(builder: (context) => ArrivalVerificationScreen(adminName: adminName, initialLanguage: initialLanguage))); },
          ),
          const SizedBox(height: 16),
          _buildServiceCard(context, title: tr('departure_verification'), subtitle: tr('agent_submissions'), iconData: Icons.directions_boat, color: Colors.black87, isPrimary: false,
            onTap: () { Navigator.push(context, MaterialPageRoute(builder: (context) => DepartureVerificationScreen(adminName: adminName, initialLanguage: initialLanguage))); },
          ),
          const SizedBox(height: 16),
          _buildServiceCard(context, title: tr('account_verification'), subtitle: tr('agent_registrations'), iconData: Icons.person_search, color: Colors.black87, isPrimary: false,
            onTap: () { Navigator.push(context, MaterialPageRoute(builder: (context) => AccountVerificationListScreen(initialLanguage: initialLanguage))); },
          ),
        ],
      ),
    );
  }
  
  Widget _buildServiceCard(BuildContext context, {required String title, required String subtitle, required IconData iconData, required Color color, required bool isPrimary, required VoidCallback onTap}) { return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(16), child: Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: isPrimary ? color : Colors.white, borderRadius: BorderRadius.circular(16), border: isPrimary ? null : Border.all(color: Colors.grey.shade300), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))]), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isPrimary ? Colors.white : color)), const SizedBox(height: 4), Text(subtitle, style: TextStyle(fontSize: 16, color: isPrimary ? Colors.white70 : Colors.grey))]), Icon(iconData, size: 32, color: isPrimary ? Colors.white : color)]))); }
}

class ProfileScreen extends StatefulWidget {
  final String adminName;
  final String adminUsername;
  final String selectedLanguage;
  final Function(String) onLanguageChange;

  ProfileScreen({
    super.key, 
    required this.adminName,
    required this.adminUsername,
    required this.selectedLanguage,
    required this.onLanguageChange,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final Map<String, Map<String, String>> translations = {
      'EN': { 'settings': 'Settings', 'notifications': 'Notifications', 'language': 'Language', 'privacy_security': 'Privacy & Security', 'change_password': 'Change Password', 'logout': 'Logout', 'page_not_available': 'page is not yet available.', 'logout_confirm_title': 'Logout', 'logout_confirm_body': 'Are you sure you want to logout?', 'cancel': 'Cancel' },
      'ID': { 'settings': 'Pengaturan', 'notifications': 'Notifikasi', 'language': 'Bahasa', 'privacy_security': 'Privasi & Keamanan', 'change_password': 'Ubah Password', 'logout': 'Keluar', 'page_not_available': 'halaman belum tersedia.', 'logout_confirm_title': 'Keluar', 'logout_confirm_body': 'Apakah Anda yakin ingin keluar?', 'cancel': 'Batal' }
    };

    String tr(String key) => translations[widget.selectedLanguage]![key] ?? key;
    
    void showLogoutDialog() {
      showDialog(
        context: context,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Center(child: Text(tr('logout_confirm_title'), style: const TextStyle(fontWeight: FontWeight.bold))),
            content: Text(tr('logout_confirm_body'), textAlign: TextAlign.center),
            actionsAlignment: MainAxisAlignment.center,
            actions: <Widget>[
              OutlinedButton(
                style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), side: BorderSide(color: Colors.red.shade200), padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12)),
                child: Text(tr('cancel'), style: const TextStyle(color: Colors.red)),
                onPressed: () => Navigator.of(dialogContext).pop(),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade400, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12)),
                child: Text(tr('logout'), style: const TextStyle(color: Colors.white)),
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
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(tr('settings')),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        children: [
          const SizedBox(height: 20),
          Center(
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: const Color(0xFFE3F2FD),
                  backgroundImage: UserService.officerProfileImagePath != null
                      ? FileImage(File(UserService.officerProfileImagePath!))
                      : null,
                  child: UserService.officerProfileImagePath == null
                      ? const Icon(Icons.person, size: 60, color: Color(0xFF90CAF9))
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: InkWell(
                    onTap: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EditProfileScreen(
                            initialLanguage: widget.selectedLanguage,
                          ),
                        ),
                      );
                      if (result == true) {
                        setState(() {});
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.edit, color: Colors.white, size: 18),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(widget.adminName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black)),
          ),
          Center(
            child: Text('@${widget.adminUsername}', style: const TextStyle(fontSize: 15, color: Colors.grey)),
          ),
          const SizedBox(height: 30),
          _buildSettingsMenuItem(context, title: tr('notifications'), icon: Icons.notifications_none_outlined, onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => OfficerNotificationScreen(initialLanguage: widget.selectedLanguage)));
          }),
          const Divider(height: 1, indent: 20, endIndent: 20),
           _buildLanguageSection(tr('language')),
          const Divider(height: 1, indent: 20, endIndent: 20),
          _buildSettingsMenuItem(context, title: tr('privacy_security'), icon: Icons.lock_outline, onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("'${tr('privacy_security')}' ${tr('page_not_available')}")));
          }),
          const Divider(height: 1, indent: 20, endIndent: 20),
           _buildSettingsMenuItem(
            context,
            title: tr('change_password'),
            icon: Icons.password_outlined,
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => ChangePasswordScreen(initialLanguage: widget.selectedLanguage)));
            },
          ),
          const Divider(height: 1, indent: 20, endIndent: 20),
          _buildLogoutMenuItem(context, title: tr('logout'), onTap: showLogoutDialog),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

   Widget _buildLanguageSection(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           Text(title, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
          const SizedBox(height: 12),
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
    final isSelected = widget.selectedLanguage == code;
    return OutlinedButton(
      onPressed: () => widget.onLanguageChange(code),
      style: OutlinedButton.styleFrom(
        backgroundColor: isSelected ? Colors.blue.withOpacity(0.1) : Colors.transparent,
        side: BorderSide(color: isSelected ? Colors.blue : Colors.grey.shade300, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(name, style: TextStyle(color: isSelected ? Colors.blue.shade800 : Colors.black87, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
    );
  }

  Widget _buildSettingsMenuItem(BuildContext context, {required String title, required IconData icon, VoidCallback? onTap}) {
    return ListTile(
      leading: Icon(icon, color: Colors.black87),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
    );
  }

  Widget _buildLogoutMenuItem(BuildContext context, {required String title, VoidCallback? onTap}) {
    return ListTile(
      leading: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: Colors.red.shade100,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.logout, color: Colors.red, size: 16),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16, color: Colors.red)),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
    );
  }
}
