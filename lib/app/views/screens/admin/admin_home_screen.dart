import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../localization/app_strings.dart';
import '../../../config/routes.dart';
import '../../../config/theme.dart';
import '../auth/change_password_screen.dart';
import '../../../services/auth_service.dart';
import '../../widgets/custom_bottom_navbar.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/custom_button.dart';

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

  @override
  void initState() {
    super.initState();
    _selectedLanguage = widget.initialLanguage;
    _loadSelectedIndex();
  }

  void _changeLanguage(String langCode) => setState(() => _selectedLanguage = langCode);

  Future<void> _loadSelectedIndex() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedIndex = prefs.getInt('admin_selected_index') ?? 0;
    });
  }

  Future<void> _onItemTapped(int index) async {
    setState(() => _selectedIndex = index);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('admin_selected_index', index);
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = <Widget>[
      AdminMenuScreen(adminName: widget.adminName, initialLanguage: _selectedLanguage),
      AdminAnalyticsScreen(initialLanguage: _selectedLanguage),
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
      bottomNavigationBar: CustomBottomNavbar(
        items: NavigationItems.adminItems,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: AppTheme.primaryColor,
        unselectedItemColor: AppTheme.greyColor,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        backgroundColor: AppTheme.whiteColor,
        elevation: 8,
        languageCode: widget.initialLanguage,
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


    return Scaffold(
      backgroundColor: AppTheme.whiteColor,
      appBar: CustomAppBar(
        title: LogoTitle(text: tr('home')),
        backgroundColor: AppTheme.whiteColor,
        foregroundColor: AppTheme.blackColor,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          NotificationIconWithBadge(
            badgeCount: 0, // You can implement notification count logic here
            onPressed: () {
              // Navigate to admin notifications
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
                child: Icon(Icons.admin_panel_settings, size: 30, color: AppTheme.greyColor),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr('welcome'), style: const TextStyle(fontSize: AppTheme.fontSizeLarge, color: AppTheme.greyColor)),
                  Text("$adminName - ${tr('admin')}", style: const TextStyle(fontSize: AppTheme.fontSizeXXLarge, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildServiceCard(context,
            title: tr('user_management'),
            subtitle: tr('manage_user_roles'),
            iconData: Icons.people,
            color: AppTheme.primaryColor,
            isPrimary: true,
            onTap: () {
              // Navigate to user management screen
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
              // Navigate to email config
            },
          ),
          const SizedBox(height: 16),
          _buildServiceCard(context,
            title: tr('system_maintenance'),
            subtitle: tr('maintenance_mode'),
            iconData: Icons.build,
            color: AppTheme.warningColor,
            isPrimary: false,
            onTap: () {
              // Navigate to maintenance settings
            },
          ),
          const SizedBox(height: 16),
          _buildServiceCard(context,
            title: tr('batch_notifications'),
            subtitle: tr('send_bulk_notifications'),
            iconData: Icons.notifications_active,
            color: AppTheme.infoColor,
            isPrimary: false,
            onTap: () {
              // Navigate to batch notifications
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
            BoxShadow(color: AppTheme.greyColor.withAlpha(25), blurRadius: 10, offset: const Offset(0, 5)),
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

class AdminAnalyticsScreen extends StatelessWidget {
  final String initialLanguage;
  const AdminAnalyticsScreen({super.key, required this.initialLanguage});

  @override
  Widget build(BuildContext context) {
    String tr(String stringKey) => AppStrings.tr(
          context: context,
          screenKey: 'adminAnalytics',
          stringKey: stringKey,
          langCode: initialLanguage,
        );

    return Scaffold(
      backgroundColor: AppTheme.whiteColor,
      appBar: CustomAppBar(
        title: LogoTitle(
          text: AppStrings.tr(
            context: context,
            screenKey: 'splash',
            stringKey: 'app_name',
            langCode: initialLanguage,
          ),
        ),
        backgroundColor: AppTheme.whiteColor,
        foregroundColor: AppTheme.blackColor,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Text(tr('analytics_dashboard')),
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
              CustomButton(
                text: tr('cancel'),
                type: CustomButtonType.outlined,
                borderColor: AppTheme.errorShade200,
                foregroundColor: AppTheme.errorColor,
                onPressed: () => Navigator.of(dialogContext).pop(),
              ),
              const SizedBox(width: 8),
              CustomButton(
                text: tr('logout'),
                type: CustomButtonType.elevated,
                backgroundColor: AppTheme.errorShade400,
                onPressed: () async {
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
      appBar: CustomAppBar(
        title: LogoTitle(
          text: AppStrings.tr(
            context: context,
            screenKey: 'splash',
            stringKey: 'app_name',
            langCode: _selectedLanguage,
          ),
        ),
        backgroundColor: AppTheme.whiteColor,
        foregroundColor: AppTheme.blackColor,
        elevation: 0,
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
                  child: Icon(Icons.admin_panel_settings, size: 60, color: AppTheme.primaryColor),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: InkWell(
                    onTap: () async {
                      // Navigate to edit profile
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
          _buildSettingsMenuItem(context, title: tr('notifications'), icon: Icons.notifications_none_outlined, onTap: () {}),
          const Divider(height: 1, indent: 20, endIndent: 20),
          _buildLanguageSection(tr('language'), tr),
          const Divider(height: 1, indent: 20, endIndent: 20),
          _buildSettingsMenuItem(context, title: tr('privacy_security'), icon: Icons.lock_outline, onTap: () {}),
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

