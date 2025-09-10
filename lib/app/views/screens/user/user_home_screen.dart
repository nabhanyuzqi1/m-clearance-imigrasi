import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../localization/app_strings.dart';
import '../../../models/clearance_application.dart';
import '../../../models/user_account.dart';
import '../../../services/notification_service.dart';
import '../../../services/user_service.dart';
import '../../../config/routes.dart';
import 'clearance_form_screen.dart';
import 'notification_screen.dart';
import 'history_screen.dart';

class UserHomeScreen extends StatefulWidget {
  final String initialLanguage;

  const UserHomeScreen({
    super.key,
    this.initialLanguage = 'EN'
  });

  @override
  State<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends State<UserHomeScreen> {
  int _selectedIndex = 0;
  UserAccount? currentUser;
  String _selectedLanguage = 'EN';
  final UserService _userService = UserService();
  final NotificationService _notificationService = NotificationService();

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
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    try {
      currentUser = await _userService.getCurrentUserAccount();
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('Error loading current user: $e');
      // If user not found, redirect to login
      if (mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.login);
      }
    }
  }

  void _refresh() {
    setState(() {
      _loadCurrentUser();
    });
  }

  void _changeLanguage(String langCode) => setState(() => _selectedLanguage = langCode);
  void _onItemTapped(int index) => setState(() => _selectedIndex = index);

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Center(child: Text(_tr('userProfile', 'logout_confirm_title'), style: const TextStyle(fontWeight: FontWeight.bold))),
          content: Text(_tr('userProfile', 'logout_confirm_body'), textAlign: TextAlign.center),
          actionsAlignment: MainAxisAlignment.center,
          actions: <Widget>[
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                side: BorderSide(color: Colors.red.shade200),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12)
              ),
              child: Text(_tr('userProfile', 'cancel'), style: TextStyle(color: Colors.red)),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade400,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12)
              ),
              child: Text(_tr('userProfile', 'logout'), style: const TextStyle(color: Colors.white)),
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await FirebaseAuth.instance.signOut();
                if (mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                    (Route<dynamic> route) => false,
                  );
                }
              },
            )
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final List<Widget> pages = <Widget>[
      UserMenuScreen(
        userAccount: currentUser!,
        initialLanguage: _selectedLanguage,
        onLanguageChange: _changeLanguage,
      ),
      UserHistoryScreen(
        userAccount: currentUser!,
        initialLanguage: _selectedLanguage,
      ),
      UserProfileScreen(
        userAccount: currentUser!,
        onRefresh: _refresh,
        selectedLanguage: _selectedLanguage,
        onLanguageChange: _changeLanguage,
        onLogout: () => _showLogoutDialog(context),
      ),
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      body: pages.elementAt(_selectedIndex),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: const Icon(Icons.home_filled), label: _tr('userHome', 'home')),
          BottomNavigationBarItem(icon: const Icon(Icons.history), label: _tr('userHome', 'history')),
          BottomNavigationBarItem(icon: const Icon(Icons.settings), label: _tr('userHome', 'settings')),
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

// Import statement for LoginScreen - this needs to be added at the top
// import '../auth/login_screen.dart';

// User Menu Screen Component
class UserMenuScreen extends StatelessWidget {
  final UserAccount userAccount;
  final String initialLanguage;
  final Function(String) onLanguageChange;

  const UserMenuScreen({
    super.key,
    required this.userAccount,
    required this.initialLanguage,
    required this.onLanguageChange,
  });

  @override
  Widget build(BuildContext context) {
    String screenTr(String key) => AppStrings.tr(
      context: context,
      screenKey: 'userHome',
      stringKey: key,
      langCode: initialLanguage,
    );

    return StreamBuilder<int>(
      stream: NotificationService().getUnreadCount(),
      builder: (context, snapshot) {
        final unreadCount = snapshot.data ?? 0;

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            title: Row(
              children: [
                Image.asset('assets/images/logo.png', height: 32, errorBuilder: (context, error, stackTrace) => const Icon(Icons.directions_boat)),
                const SizedBox(width: 8),
                const Text('M-Clearance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
                  if (unreadCount > 0)
                    Positioned(
                      right: 8, top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        child: Text('$unreadCount', style: const TextStyle(color: Colors.white, fontSize: 10), textAlign: TextAlign.center),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: StreamBuilder<List<ClearanceApplication>>(
            stream: UserService().getUserApplications(),
            builder: (context, snapshot) {
              final applications = snapshot.data ?? [];
              final lastTwoTransactions = applications.take(2).toList();

              return ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  // User Profile Section
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.grey.shade200,
                        backgroundImage: null, // Web doesn't support local file images
                        child: const Icon(Icons.person, size: 30, color: Colors.grey),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(screenTr('welcome'), style: const TextStyle(fontSize: 16, color: Colors.grey)),
                          Text(userAccount.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Service Cards
                  _buildServiceCard(
                    context,
                    title: screenTr('arrival'),
                    subtitle: screenTr('last_port'),
                    iconData: Icons.anchor,
                    color: Colors.blue,
                    isPrimary: true,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ClearanceFormScreen(
                            type: ApplicationType.kedatangan,
                            agentName: userAccount.name,
                            initialLanguage: initialLanguage,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildServiceCard(
                    context,
                    title: screenTr('departure'),
                    subtitle: screenTr('next_port'),
                    iconData: Icons.directions_boat,
                    color: Colors.black87,
                    isPrimary: false,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ClearanceFormScreen(
                            type: ApplicationType.keberangkatan,
                            agentName: userAccount.name,
                            initialLanguage: initialLanguage,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 32),

                  // Last Transactions
                  Text(screenTr('last_transactions'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  if (lastTwoTransactions.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24.0),
                        child: Text(screenTr('no_transactions'), style: const TextStyle(color: Colors.grey))
                      )
                    )
                  else
                    ...lastTwoTransactions.map((app) => _buildTransactionItem(
                      context,
                      type: app.type == ApplicationType.kedatangan ? screenTr('arrival') : screenTr('departure'),
                      detail: "${app.shipName} - ${app.port ?? 'N/A'}",
                      date: "(${app.date ?? 'No Date'})",
                    )),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildServiceCard(BuildContext context, {
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
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isPrimary ? color : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: isPrimary ? null : Border.all(color: Colors.grey.shade300),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 5)
            )
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isPrimary ? Colors.white : color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 16,
                    color: isPrimary ? Colors.white70 : Colors.grey,
                  ),
                ),
              ],
            ),
            Icon(iconData, size: 32, color: isPrimary ? Colors.white : color),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionItem(BuildContext context, {
    required String type,
    required String detail,
    required String date,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          const Icon(Icons.star, color: Colors.blue, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 16, color: Colors.black),
                children: [
                  TextSpan(text: '$type: ', style: const TextStyle(fontWeight: FontWeight.bold)),
                  TextSpan(text: '$detail '),
                  TextSpan(text: date, style: const TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// User History Screen - now imported from history_screen.dart

class UserProfileScreen extends StatelessWidget {
  final UserAccount userAccount;
  final VoidCallback onRefresh;
  final String selectedLanguage;
  final Function(String) onLanguageChange;
  final VoidCallback onLogout;

  const UserProfileScreen({
    super.key,
    required this.userAccount,
    required this.onRefresh,
    required this.selectedLanguage,
    required this.onLanguageChange,
    required this.onLogout,
  });

  String _tr(BuildContext context, String screenKey, String stringKey) => AppStrings.tr(
    context: context,
    screenKey: screenKey,
    stringKey: stringKey,
    langCode: selectedLanguage,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(_tr(context, 'userProfile', 'profile')),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Profile Picture Section
            Center(
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.grey.shade200,
                    backgroundImage: null, // Web doesn't support local file images
                    child: const Icon(Icons.person, size: 60, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // User Info
            Text(
              userAccount.name,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              userAccount.email,
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 32),

            // Menu Items
            _buildMenuItem(
              context,
              icon: Icons.edit,
              title: _tr(context, 'userProfile', 'edit_profile'),
              onTap: () {
                Navigator.pushNamed(
                  context,
                  AppRoutes.editAgentProfile,
                  arguments: {
                    'username': userAccount.username,
                    'currentName': userAccount.name,
                    'currentEmail': userAccount.email,
                    'initialLanguage': selectedLanguage,
                  },
                ).then((result) {
                  if (result == true) {
                    onRefresh();
                  }
                });
              },
            ),

            _buildMenuItem(
              context,
              icon: Icons.language,
              title: _tr(context, 'userProfile', 'language'),
              trailing: selectedLanguage == 'EN' ? 'English' : 'Bahasa Indonesia',
              onTap: () {
                _showLanguageDialog(context);
              },
            ),

            const Divider(height: 32),

            _buildMenuItem(
              context,
              icon: Icons.logout,
              title: _tr(context, 'userProfile', 'logout'),
              textColor: Colors.red,
              onTap: onLogout,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? trailing,
    Color? textColor,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: textColor ?? Colors.black),
      title: Text(
        title,
        style: TextStyle(
          color: textColor ?? Colors.black,
          fontSize: 16,
        ),
      ),
      trailing: trailing != null
          ? Text(trailing, style: TextStyle(color: Colors.grey.shade600))
          : const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
    );
  }

  void _showLanguageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(_tr(context, 'userProfile', 'select_language')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('English'),
                leading: Radio<String>(
                  value: 'EN',
                  groupValue: selectedLanguage,
                  onChanged: (value) {
                    if (value != null) {
                      onLanguageChange(value);
                      Navigator.of(dialogContext).pop();
                    }
                  },
                ),
                onTap: () {
                  onLanguageChange('EN');
                  Navigator.of(dialogContext).pop();
                },
              ),
              ListTile(
                title: const Text('Bahasa Indonesia'),
                leading: Radio<String>(
                  value: 'ID',
                  groupValue: selectedLanguage,
                  onChanged: (value) {
                    if (value != null) {
                      onLanguageChange(value);
                      Navigator.of(dialogContext).pop();
                    }
                  },
                ),
                onTap: () {
                  onLanguageChange('ID');
                  Navigator.of(dialogContext).pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

// For now, I'll create a placeholder LoginScreen class
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Login Screen')));
  }
}
