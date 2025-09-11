import 'package:flutter/material.dart';
import '../../../localization/app_strings.dart';
import '../../../config/routes.dart';
import '../../../config/theme.dart';
import '../auth/change_password_screen.dart';
import '../../../services/auth_service.dart';
import 'account_verification_list_screen.dart';
import 'arrival_verification_screen.dart';
import 'departure_verification_screen.dart';
import 'edit_profile_screen.dart';
import 'email_config_screen.dart';
import 'officer_report_screen.dart';
import 'notification_screen.dart';
import '../../../services/functions_service.dart';

class AdminHomeScreen extends StatefulWidget {
  final String adminName;
  final String adminUsername;
  final String initialLanguage;

  const AdminHomeScreen({super.key, required this.adminName, required this.adminUsername, this.initialLanguage = 'EN'});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _selectedIndex = 0;
  late String _selectedLanguage;

  String _tr(String screenKey, String stringKey) => AppStrings.tr(
        context: context,
        screenKey: screenKey,
        stringKey: stringKey,
        langCode: _selectedLanguage,
      );

  @override
  void initState() {
    super.initState();
    _selectedLanguage = widget.initialLanguage;
  }

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
        initialLanguage: _selectedLanguage,
        onLanguageChange: _changeLanguage,
      ),
    ];

    return Scaffold(
      backgroundColor: AppTheme.whiteColor,
      body: pages.elementAt(_selectedIndex),
      bottomNavigationBar: BottomNavigationBar(
        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: const Icon(Icons.home_filled), label: _tr('adminHome', 'home')),
          BottomNavigationBarItem(icon: const Icon(Icons.assessment_outlined), label: _tr('adminHome', 'report')),
          BottomNavigationBarItem(icon: const Icon(Icons.settings), label: _tr('adminHome', 'settings')),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: AppTheme.infoColor,
        unselectedItemColor: AppTheme.greyColor,
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
    String tr(String stringKey) => AppStrings.tr(
          context: context,
          screenKey: 'adminHome',
          stringKey: stringKey,
          langCode: initialLanguage,
        );

    final functions = FunctionsService();

    return Scaffold(
      backgroundColor: AppTheme.whiteColor,
      appBar: AppBar(
        backgroundColor: AppTheme.whiteColor,
        elevation: 0,
        title: Row(
          children: [
            Image.asset('assets/images/logo.png', height: 32,
              errorBuilder: (context, error, stackTrace) => const Icon(Icons.directions_boat),
            ),
            const SizedBox(width: 8),
            Text(tr('immigration_office'), style: const TextStyle(color: AppTheme.blackColor, fontSize: AppTheme.fontSizeExtraLarge, fontWeight: FontWeight.bold)),
          ],
        ),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_outlined, color: AppTheme.blackColor54),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => OfficerNotificationScreen(initialLanguage: initialLanguage)));
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.all(AppTheme.responsivePadding(context)),
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 24,
                backgroundColor: AppTheme.blackColor12,
                child: Icon(Icons.person, size: 30, color: AppTheme.greyColor),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr('welcome'), style: const TextStyle(fontSize: AppTheme.fontSizeLarge, color: AppTheme.greyColor)),
                  Text("$adminName - ${tr('officer')}", style: const TextStyle(fontSize: AppTheme.fontSizeXXLarge, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          FutureBuilder<Map<String, dynamic>>(
            future: functions.getOfficerDashboardStats(),
            builder: (context, snapshot) {
              final stats = snapshot.data ?? const {};
              final pendingArrival = stats['pendingArrival']?.toString() ?? '';
              final subtitle = pendingArrival.isNotEmpty
                  ? '${tr('agent_submissions')} ($pendingArrival)'
                  : tr('agent_submissions');
              return _buildServiceCard(context,
            title: tr('arrival_verification'),
            subtitle: subtitle,
            iconData: Icons.anchor,
            color: AppTheme.infoColor,
            isPrimary: true,
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => ArrivalVerificationScreen(adminName: adminName, initialLanguage: initialLanguage)));
            },
              );
            },
          ),
          const SizedBox(height: 16),
          FutureBuilder<Map<String, dynamic>>(
            future: functions.getOfficerDashboardStats(),
            builder: (context, snapshot) {
              final stats = snapshot.data ?? const {};
              final pendingDeparture = stats['pendingDeparture']?.toString() ?? '';
              final subtitle = pendingDeparture.isNotEmpty
                  ? '${tr('agent_submissions')} ($pendingDeparture)'
                  : tr('agent_submissions');
              return _buildServiceCard(context,
            title: tr('departure_verification'),
            subtitle: subtitle,
            iconData: Icons.directions_boat,
            color: AppTheme.blackColor87,
            isPrimary: false,
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => DepartureVerificationScreen(adminName: adminName, initialLanguage: initialLanguage)));
            },
              );
            },
          ),
          const SizedBox(height: 16),
          FutureBuilder<Map<String, dynamic>>(
            future: functions.getOfficerDashboardStats(),
            builder: (context, snapshot) {
              final stats = snapshot.data ?? const {};
              final pendingAccounts = stats['pendingAccounts']?.toString() ?? '';
              final subtitle = pendingAccounts.isNotEmpty
                  ? '${tr('agent_registrations')} ($pendingAccounts)'
                  : tr('agent_registrations');
              return _buildServiceCard(context,
            title: tr('account_verification'),
            subtitle: subtitle,
            iconData: Icons.person_search,
            color: AppTheme.blackColor87,
            isPrimary: false,
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => AccountVerificationListScreen(initialLanguage: initialLanguage)));
            },
              );
            },
          ),
          const SizedBox(height: 16),
          _buildServiceCard(context,
            title: tr('email_configuration'),
            subtitle: tr('manage_email_settings'),
            iconData: Icons.email_outlined,
            color: AppTheme.successColor,
            isPrimary: false,
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => EmailConfigScreen(initialLanguage: initialLanguage)));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildServiceCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData iconData,
    required Color color,
    required bool isPrimary,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: EdgeInsets.all(AppTheme.responsivePadding(context, mobile: AppTheme.paddingLarge, tablet: AppTheme.paddingLarge)),
        decoration: BoxDecoration(
          color: isPrimary ? color : AppTheme.whiteColor,
          borderRadius: BorderRadius.circular(16),
          border: isPrimary ? null : Border.all(color: AppTheme.greyShade300),
          boxShadow: [
            BoxShadow(color: AppTheme.greyColor.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5)),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: AppTheme.fontSizeXXLarge, fontWeight: FontWeight.bold, color: isPrimary ? AppTheme.whiteColor : color)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(fontSize: AppTheme.fontSizeLarge, color: isPrimary ? AppTheme.whiteColor70 : AppTheme.greyColor)),
                ],
              ),
            ),
            Icon(iconData, size: 32, color: isPrimary ? AppTheme.whiteColor : color),
          ],
        ),
      ),
    );
  }
}

class ProfileScreen extends StatefulWidget {
  final String adminName;
  final String adminUsername;
  final String initialLanguage;
  final Function(String) onLanguageChange;

  const ProfileScreen({
    super.key,
    required this.adminName,
    required this.adminUsername,
    required this.initialLanguage,
    required this.onLanguageChange,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late String _selectedLanguage;

  @override
  void initState() {
    super.initState();
    _selectedLanguage = widget.initialLanguage;
  }

  @override
  Widget build(BuildContext context) {
    String tr(String stringKey) => AppStrings.tr(
          context: context,
          screenKey: 'adminProfile',
          stringKey: stringKey,
          langCode: _selectedLanguage,
        );

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
                style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), side: BorderSide(color: AppTheme.errorShade200), padding: EdgeInsets.symmetric(horizontal: AppTheme.paddingLarge, vertical: AppTheme.paddingMedium)),
                child: Text(tr('cancel'), style: const TextStyle(color: AppTheme.errorColor)),
                onPressed: () => Navigator.of(dialogContext).pop(),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorShade400, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: EdgeInsets.symmetric(horizontal: AppTheme.paddingLarge, vertical: AppTheme.paddingMedium)),
                child: Text(tr('logout'), style: const TextStyle(color: AppTheme.whiteColor)),
                onPressed: () async {
                  // Ensure true logout from Firebase
                  try {
                    await AuthService().signOut();
                  } catch (_) {}
                  if (context.mounted) {
                    Navigator.of(dialogContext).pop();
                    Navigator.pushReplacementNamed(context, AppRoutes.login);
                  }
                },
              )
            ],
          );
        },
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.whiteColor,
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
                const CircleAvatar(
                  radius: 50,
                  backgroundColor: AppTheme.greyShade50,
                  child: Icon(Icons.person, size: 60, color: Color(0xFF90CAF9)),
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
                            initialLanguage: _selectedLanguage,
                          ),
                        ),
                      );
                      if (result == true) {
                        setState(() {});
                      }
                    },
                    child: Container(
                      padding: EdgeInsets.all(AppTheme.paddingSmall),
                      decoration: BoxDecoration(
                        color: AppTheme.infoColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.whiteColor, width: 2),
                      ),
                      child: const Icon(Icons.edit, color: AppTheme.whiteColor, size: 18),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(widget.adminName, style: const TextStyle(fontSize: AppTheme.fontSizeXXXXLarge, fontWeight: FontWeight.bold, color: AppTheme.blackColor)),
          ),
          Center(
            child: Text('@${widget.adminUsername}', style: const TextStyle(fontSize: AppTheme.fontSizeSmall, color: AppTheme.greyColor)),
          ),
          const SizedBox(height: 30),
          _buildSettingsMenuItem(context, title: tr('notifications'), icon: Icons.notifications_none_outlined, onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => OfficerNotificationScreen(initialLanguage: _selectedLanguage)));
          }),
          const Divider(height: 1, indent: 20, endIndent: 20),
          _buildLanguageSection(tr('language'), tr),
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
              Navigator.push(context, MaterialPageRoute(builder: (context) => ChangePasswordScreen(initialLanguage: _selectedLanguage)));
            },
          ),
          const Divider(height: 1, indent: 20, endIndent: 20),
          _buildLogoutMenuItem(context, title: tr('logout'), onTap: showLogoutDialog),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildLanguageSection(String title, String Function(String) tr) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppTheme.responsivePadding(context, mobile: AppTheme.paddingLarge, tablet: AppTheme.paddingLarge),
        vertical: AppTheme.paddingSmall,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: AppTheme.fontSizeLarge,
            ),
          ),
          DropdownButton<String>(
            value: _selectedLanguage,
            icon: const Icon(Icons.arrow_drop_down),
            items: ['EN', 'ID'].map((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(tr(value == 'EN' ? 'english' : 'indonesian')),
              );
            }).toList(),
            onChanged: (String? newValue) {
              if (newValue != null) {
                setState(() => _selectedLanguage = newValue);
                widget.onLanguageChange(newValue);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsMenuItem(BuildContext context, {required String title, required IconData icon, VoidCallback? onTap}) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.blackColor87),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: AppTheme.fontSizeLarge)),
      trailing: const Icon(Icons.chevron_right, color: AppTheme.greyColor),
      onTap: onTap,
      contentPadding: EdgeInsets.symmetric(horizontal: AppTheme.responsivePadding(context, mobile: AppTheme.paddingLarge, tablet: AppTheme.paddingLarge)),
    );
  }

  Widget _buildLogoutMenuItem(BuildContext context, {required String title, VoidCallback? onTap}) {
    return ListTile(
      leading: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: AppTheme.errorShade100,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.logout, color: AppTheme.errorColor, size: 16),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: AppTheme.fontSizeLarge, color: AppTheme.errorColor)),
      onTap: onTap,
      contentPadding: EdgeInsets.symmetric(horizontal: AppTheme.responsivePadding(context, mobile: AppTheme.paddingLarge, tablet: AppTheme.paddingLarge)),
    );
  }
}
