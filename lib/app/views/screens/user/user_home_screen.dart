 import 'package:flutter/material.dart';
import '../../../localization/app_strings.dart';
import '../../../models/clearance_application.dart';
import '../../../models/user_account.dart';
import '../../../services/notification_service.dart';
import '../../../services/user_service.dart';
import '../../../config/routes.dart';
import '../../../services/auth_service.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/custom_bottom_navbar.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/bouncing_dots_loader.dart';
import '../../widgets/skeleton_loader.dart';
import '../auth/change_password_screen.dart';
import 'clearance_form_screen.dart';
import 'notification_screen.dart';
import 'history_screen.dart';
import 'language_selection_screen.dart';

class UserHomeScreen extends StatefulWidget {
  final String initialLanguage;

  const UserHomeScreen({super.key, required this.initialLanguage});

  @override
  State<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends State<UserHomeScreen> {
  int _selectedIndex = 0;
  UserAccount? currentUser;
  bool _isLoadingUser = true;
  final UserService _userService = UserService();

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    if (!mounted) return;

    setState(() => _isLoadingUser = true);
    try {
      currentUser = await _userService.getCurrentUserAccount();
      if (currentUser == null) {
        // User not authenticated or account not found
        if (mounted) {
          Navigator.pushReplacementNamed(context, AppRoutes.login);
        }
        return;
      }
    } catch (e) {
      print('Error loading current user: $e');
      if (mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.login);
      }
      return;
    }

    if (mounted) {
      setState(() => _isLoadingUser = false);
    }
  }

  void _refresh() {
    _loadCurrentUser();
  }

  void _onItemTapped(int index) => setState(() => _selectedIndex = index);

  void _showLogoutDialog(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final fontSize = screenWidth * 0.04;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Center(
              child: Text(
            AppStrings.tr(
              context: context,
              screenKey: 'userProfile',
              stringKey: 'logout_confirm_title',
              langCode: widget.initialLanguage,
            ),
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: screenWidth * 0.045),
          )),
          content: Text(
            AppStrings.tr(
              context: context,
              screenKey: 'userProfile',
              stringKey: 'logout_confirm_body',
              langCode: widget.initialLanguage,
            ),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: fontSize),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: <Widget>[
            CustomButton(
              text: AppStrings.tr(
                context: context,
                screenKey: 'userProfile',
                stringKey: 'cancel',
                langCode: widget.initialLanguage,
              ),
              type: CustomButtonType.outlined,
              borderColor: Colors.red.shade200,
              foregroundColor: Colors.red,
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            SizedBox(width: screenWidth * 0.02),
            CustomButton(
              text: AppStrings.tr(
                context: context,
                screenKey: 'userProfile',
                stringKey: 'logout',
                langCode: widget.initialLanguage,
              ),
              type: CustomButtonType.elevated,
              backgroundColor: Colors.red.shade400,
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await AuthService().signOut();
                if (mounted) {
                  Navigator.pushReplacementNamed(context, AppRoutes.login);
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
    if (_isLoadingUser && currentUser == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const BouncingDotsLoader(),
              const SizedBox(height: 16),
              Text(
                AppStrings.tr(
                  context: context,
                  screenKey: 'userHome',
                  stringKey: 'loading_user',
                  langCode: widget.initialLanguage,
                ),
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    if (currentUser == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final List<Widget> pages = <Widget>[
      UserMenuScreen(
        userAccount: currentUser!,
        initialLanguage: widget.initialLanguage,
      ),
      UserHistoryScreen(
        userAccount: currentUser!,
        initialLanguage: widget.initialLanguage,
      ),
      UserProfileScreen(
        userAccount: currentUser!,
        initialLanguage: widget.initialLanguage,
        onRefresh: _refresh,
        onLogout: () => _showLogoutDialog(context),
      ),
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      body: pages.elementAt(_selectedIndex),
      bottomNavigationBar: CustomBottomNavbar(
        items: NavigationItems.userItems,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        showSelectedLabels: true,
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

  const UserMenuScreen({
    super.key,
    required this.userAccount,
    required this.initialLanguage,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = screenWidth * 0.04;
    final verticalSpacing = screenWidth * 0.03;

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
          appBar: CustomAppBar(
            title: LogoTitle(text: 'M-Clearance ISam'),
            actions: [
              NotificationIconWithBadge(
                badgeCount: unreadCount,
                onPressed: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => NotificationScreen(
                                initialLanguage: initialLanguage,
                              )));
                },
              ),
              SizedBox(width: screenWidth * 0.02),
            ],
          ),
          body: StreamBuilder<List<ClearanceApplication>>(
            stream: UserService().getUserApplications(),
            builder: (context, snapshot) {
              final applications = snapshot.data ?? [];
              final lastTwoTransactions = applications.take(2).toList();

              return ListView(
                padding: EdgeInsets.all(horizontalPadding),
                children: [
                  // User Profile Section
                  Row(
                    children: [
                      CircleAvatar(
                        radius: screenWidth * 0.06,
                        backgroundColor: Colors.grey.shade200,
                        backgroundImage: userAccount.profileImageUrl != null
                            ? NetworkImage(userAccount.profileImageUrl!)
                            : null,
                        child: userAccount.profileImageUrl == null
                            ? Icon(Icons.person, size: screenWidth * 0.075, color: Colors.grey)
                            : null,
                      ),
                      SizedBox(width: screenWidth * 0.03),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(screenTr('welcome'), style: TextStyle(fontSize: screenWidth * 0.04, color: Colors.grey)),
                            Text(userAccount.name, style: TextStyle(fontSize: screenWidth * 0.05, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: verticalSpacing * 2),

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
                              initialLanguage: initialLanguage),
                        ),
                      );
                    },
                  ),
                  SizedBox(height: verticalSpacing),
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
                              initialLanguage: initialLanguage),
                        ),
                      );
                    },
                  ),
                  SizedBox(height: verticalSpacing * 3),

                  // Last Transactions
                  Text(screenTr('last_transactions'), style: TextStyle(fontSize: screenWidth * 0.045, fontWeight: FontWeight.bold)),
                  SizedBox(height: verticalSpacing),
                  if (snapshot.connectionState == ConnectionState.waiting)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: verticalSpacing),
                      child: Column(
                        children: List.generate(2, (index) => Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              SkeletonLoader(
                                width: screenWidth * 0.08,
                                height: screenWidth * 0.08,
                                borderRadius: BorderRadius.circular(screenWidth * 0.04),
                              ),
                              SizedBox(width: screenWidth * 0.03),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SkeletonLoader(
                                      width: double.infinity,
                                      height: screenWidth * 0.04,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    const SizedBox(height: 4),
                                    SkeletonLoader(
                                      width: screenWidth * 0.5,
                                      height: screenWidth * 0.035,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )),
                      ),
                    )
                  else if (lastTwoTransactions.isEmpty)
                    Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: verticalSpacing * 2),
                        child: Text(screenTr('no_transactions'), style: TextStyle(color: Colors.grey, fontSize: screenWidth * 0.04))
                      )
                    )
                  else
                    ...lastTwoTransactions.map((app) => _buildTransactionItem(
                      context,
                      key: ValueKey(app.id),
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
    final screenWidth = MediaQuery.of(context).size.width;
    final cardPadding = screenWidth * 0.05;
    final iconSize = screenWidth * 0.08;
    final titleFontSize = screenWidth * 0.05;
    final subtitleFontSize = screenWidth * 0.04;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: EdgeInsets.all(cardPadding),
        decoration: BoxDecoration(
          color: isPrimary ? color : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: isPrimary ? null : Border.all(color: Colors.grey.shade300),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 5)
            )
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: titleFontSize,
                      fontWeight: FontWeight.bold,
                      color: isPrimary ? Colors.white : color,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: screenWidth * 0.01),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: subtitleFontSize,
                      color: isPrimary ? Colors.white70 : Colors.grey,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            SizedBox(width: screenWidth * 0.02),
            Icon(iconData, size: iconSize, color: isPrimary ? Colors.white : color),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionItem(BuildContext context, {
    Key? key,
    required String type,
    required String detail,
    required String date,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final verticalPadding = screenWidth * 0.03;
    final horizontalSpacing = screenWidth * 0.03;
    final iconSize = screenWidth * 0.05;
    final fontSize = screenWidth * 0.04;

    return Container(
      margin: EdgeInsets.only(bottom: verticalPadding),
      padding: EdgeInsets.all(verticalPadding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.star, color: Colors.blue, size: iconSize),
          SizedBox(width: horizontalSpacing),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(fontSize: fontSize, color: Colors.black87, height: 1.4),
                children: [
                  TextSpan(text: '$type: ', style: const TextStyle(fontWeight: FontWeight.bold)),
                  TextSpan(text: '$detail '),
                  TextSpan(text: date, style: const TextStyle(color: Colors.grey)),
                ],
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
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
  final VoidCallback onLogout;

  final String initialLanguage;

  const UserProfileScreen({
    super.key,
    required this.userAccount,
    required this.onRefresh,
    required this.onLogout,
    required this.initialLanguage,
  });

  String _tr(BuildContext context, String screenKey, String stringKey) =>
      AppStrings.tr(
        context: context,
        screenKey: screenKey,
        stringKey: stringKey,
        langCode: initialLanguage,
      );

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = screenWidth * 0.04;
    final verticalSpacing = screenWidth * 0.03;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: CustomAppBar(
        titleText: _tr(context, 'userProfile', 'profile'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(horizontalPadding),
        child: Column(
          children: [
            // Profile Picture Section
            Center(
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: screenWidth * 0.15,
                    backgroundColor: Colors.grey.shade200,
                    backgroundImage: userAccount.profileImageUrl != null
                        ? NetworkImage(userAccount.profileImageUrl!)
                        : null,
                    child: userAccount.profileImageUrl == null
                        ? Icon(Icons.person, size: screenWidth * 0.15, color: Colors.grey)
                        : null,
                  ),
                ],
              ),
            ),
            SizedBox(height: verticalSpacing),

            // User Info
            Text(
              userAccount.name,
              style: TextStyle(fontSize: screenWidth * 0.06, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: screenWidth * 0.02),
            Text(
              userAccount.email,
              style: TextStyle(fontSize: screenWidth * 0.04, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: verticalSpacing * 2),

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
                    'currentProfileImageUrl': userAccount.profileImageUrl,
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
              icon: Icons.notifications_none_outlined,
              title: _tr(context, 'userProfile', 'notifications'),
              onTap: () {
                Navigator.pushNamed(context, AppRoutes.userNotification);
              },
            ),

            _buildMenuItem(
              context,
              icon: Icons.language,
              title: _tr(context, 'userProfile', 'language'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LanguageSelectionScreen(),
                  ),
                );
              },
            ),

            _buildMenuItem(
              context,
              icon: Icons.lock_outline,
              title: _tr(context, 'userProfile', 'privacy_security'),
              onTap: () {
                Navigator.pushNamed(context, AppRoutes.privacySecurity);
              },
            ),

            _buildMenuItem(
              context,
              icon: Icons.password_outlined,
              title: _tr(context, 'userProfile', 'change_password'),
              onTap: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => ChangePasswordScreen(
                              initialLanguage: initialLanguage,
                            )));
              },
            ),

            Divider(height: verticalSpacing * 2),

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
    final screenWidth = MediaQuery.of(context).size.width;
    final iconSize = screenWidth * 0.06;
    final fontSize = screenWidth * 0.04;
    final verticalPadding = screenWidth * 0.02;

    return ListTile(
      leading: Icon(icon, color: textColor ?? Colors.black, size: iconSize),
      title: Text(
        title,
        style: TextStyle(
          color: textColor ?? Colors.black,
          fontSize: fontSize,
        ),
        overflow: TextOverflow.ellipsis,
      ),
      trailing: trailing != null
          ? Text(trailing, style: TextStyle(color: Colors.grey.shade600, fontSize: fontSize))
          : Icon(Icons.arrow_forward_ios, size: iconSize * 0.6),
      onTap: onTap,
      contentPadding: EdgeInsets.symmetric(horizontal: 0, vertical: verticalPadding),
    );
  }

}

