import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/notification_service.dart';
import '../../../localization/app_localizations.dart';
import '../../../providers/language_provider.dart';
import '../../../models/clearance_application.dart';
import '../../../models/user_account.dart';
import '../../../services/user_service.dart';
import '../../../config/routes.dart';
import '../../../services/auth_service.dart';
import '../../../config/theme.dart';
import '../../../services/logging_service.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/custom_bottom_navbar.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/bouncing_dots_loader.dart';
import '../../widgets/skeleton_loader.dart';
import 'history_screen.dart';
import 'user_settings_screen.dart';

ImageProvider<Object> _buildProfileImage(String imageUrl, double screenWidth) {
  try {
    return NetworkImage(imageUrl);
  } catch (e) {
    LoggingService().error('Error loading profile image: $e');
    return const AssetImage('assets/images/logo.png'); // Fallback image
  }
}

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
  final NotificationService _notificationService = NotificationService();
  StreamSubscription<int>? _notificationSubscription;
  int _unreadNotifications = 0;

  @override
  void initState() {
    super.initState();
    LoggingService().info(
      'UserHomeScreen initialized with language: ${widget.initialLanguage}',
    );
    _loadSelectedIndex();
    _loadCurrentUser();
    _notificationSubscription = _notificationService.getUnreadCount().listen(
      (count) {
        if (!mounted) return;
        setState(() => _unreadNotifications = count);
      },
      onError: (error) {
        LoggingService().error(
          'Error listening to user notification count',
          error,
        );
      },
    );
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
      LoggingService().error('Error loading current user: $e', e);
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

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadSelectedIndex() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedIndex = prefs.getInt('user_selected_index') ?? 0;
    });
  }

  Future<void> _onItemTapped(int index) async {
    setState(() => _selectedIndex = index);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('user_selected_index', index);
  }

  void _showLogoutDialog(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final maxWidth = isTablet ? 400.0 : double.infinity;
    final fontSize = AppTheme.responsiveFontSize(
      context,
      mobile: AppTheme.fontSizeBody1,
      tablet: AppTheme.fontSizeH6,
      desktop: AppTheme.fontSizeH6,
    );

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return Container(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Center(
              child: Text(
                AppLocalizations.of(
                  context,
                ).get('userProfile.logout_confirm_title'),
                style: AppTheme.labelLarge(
                  context,
                ).copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            content: Text(
              AppLocalizations.of(
                context,
              ).get('userProfile.logout_confirm_body'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: fontSize),
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: <Widget>[
              CustomButton(
                text: AppLocalizations.of(context).get('userProfile.cancel'),
                type: CustomButtonType.outlined,
                borderColor: AppTheme.errorShade200,
                foregroundColor: AppTheme.errorColor,
                onPressed: () => Navigator.of(dialogContext).pop(),
              ),
              SizedBox(width: screenWidth * 0.02),
              CustomButton(
                text: AppLocalizations.of(context).get('userProfile.logout'),
                type: CustomButtonType.elevated,
                backgroundColor: AppTheme.errorShade400,
                onPressed: () async {
                  Navigator.of(dialogContext).pop();
                  await AuthService().signOut();
                  if (mounted) {
                    Navigator.pushReplacementNamed(context, AppRoutes.login);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        final currentLangCode = languageProvider.locale.languageCode
            .toUpperCase();

        if (_isLoadingUser && currentUser == null) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const BouncingDotsLoader(),
                  const SizedBox(height: 16),
                  Text(
                    AppLocalizations.of(context).get('userHome.loading_user'),
                    style: TextStyle(
                      fontSize: AppTheme.responsiveFontSize(context),
                      color: AppTheme.greyColor,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (currentUser == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final List<Widget> pages = <Widget>[
          UserMenuScreen(
            userAccount: currentUser!,
            initialLanguage: currentLangCode,
            unreadNotifications: _unreadNotifications,
            onNotificationsTap: () {
              Navigator.pushNamed(context, AppRoutes.userNotification);
            },
          ),
          UserHistoryScreen(
            userAccount: currentUser!,
            initialLanguage: currentLangCode,
          ),
          UserSettingsScreen(
            userAccount: currentUser!,
            initialLanguage: currentLangCode,
            onRefresh: _refresh,
            onLogout: () => _showLogoutDialog(context),
          ),
        ];

        return Scaffold(
          backgroundColor: AppTheme.whiteColor,
          body: pages.elementAt(_selectedIndex),
          bottomNavigationBar: CustomBottomNavbar(
            items: NavigationItems.userItems,
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
      },
    );
  }
}

// User Menu Screen - Main home screen with service cards
class UserMenuScreen extends StatelessWidget {
  final UserAccount userAccount;
  final String initialLanguage;
  final int unreadNotifications;
  final VoidCallback onNotificationsTap;

  const UserMenuScreen({
    super.key,
    required this.userAccount,
    required this.initialLanguage,
    required this.unreadNotifications,
    required this.onNotificationsTap,
  });

  String _tr(BuildContext context, String screenKey, String stringKey) =>
      AppLocalizations.of(context).get('$screenKey.$stringKey');

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = screenWidth * 0.06;
    final verticalSpacing = screenWidth * 0.04;

    return Scaffold(
      backgroundColor: AppTheme.whiteColor,
      appBar: CustomAppBar(
        title: LogoTitle(
          text: AppLocalizations.of(context).get('splash.app_name'),
        ),
        backgroundColor: AppTheme.whiteColor,
        foregroundColor: AppTheme.blackColor,
        elevation: 0,
        actions: [
          NotificationIconWithBadge(
            badgeCount: unreadNotifications,
            onPressed: onNotificationsTap,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(horizontalPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome section
            Row(
              children: [
                CircleAvatar(
                  radius: screenWidth * 0.08,
                  backgroundColor: AppTheme.greyShade200,
                  backgroundImage: userAccount.profileImageUrl != null
                      ? _buildProfileImage(
                          userAccount.profileImageUrl!,
                          screenWidth,
                        )
                      : null,
                  child: userAccount.profileImageUrl == null
                      ? Icon(
                          Icons.person,
                          size: screenWidth * 0.08,
                          color: AppTheme.greyColor,
                        )
                      : null,
                ),
                SizedBox(width: screenWidth * 0.04),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _tr(context, 'userHome', 'hello'),
                        style: AppTheme.bodyMedium(
                          context,
                        ).copyWith(color: AppTheme.greyColor),
                      ),
                      Text(
                        userAccount.name,
                        style: AppTheme.headingSmall(
                          context,
                        ).copyWith(color: AppTheme.blackColor),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: verticalSpacing * 1.5),

            // Service cards
            Text(
              _tr(context, 'userHome', 'services'),
              style: AppTheme.headingSmall(
                context,
              ).copyWith(color: AppTheme.blackColor),
            ),
            SizedBox(height: verticalSpacing),

            // Arrival Clearance Card
            _buildServiceCard(
              context,
              title: _tr(context, 'userHome', 'arrival_clearance'),
              subtitle: _tr(context, 'userHome', 'arrival_description'),
              icon: Icons.anchor,
              color: AppTheme.primaryColor,
              serviceIcon: Icons.anchor,
              isPrimary: true,
              onTap: () {
                LoggingService().info('Navigating to arrival clearance form');
                Navigator.pushNamed(
                  context,
                  AppRoutes.clearanceForm,
                  arguments: {
                    'type': ApplicationType.kedatangan,
                    'agentName': userAccount.name,
                    'initialLanguage': initialLanguage,
                  },
                );
              },
            ),
            SizedBox(height: verticalSpacing),

            // Departure Clearance Card
            _buildServiceCard(
              context,
              title: _tr(context, 'userHome', 'departure_clearance'),
              subtitle: _tr(context, 'userHome', 'departure_description'),
              icon: Icons.directions_boat,
              color: AppTheme.secondaryColor,
              serviceIcon: Icons.directions_boat,
              isPrimary: false,
              onTap: () {
                LoggingService().info('Navigating to departure clearance form');
                Navigator.pushNamed(
                  context,
                  AppRoutes.clearanceForm,
                  arguments: {
                    'type': ApplicationType.keberangkatan,
                    'agentName': userAccount.name,
                    'initialLanguage': initialLanguage,
                  },
                );
              },
            ),
            SizedBox(height: verticalSpacing * 2),

            // Recent applications section
            Text(
              _tr(context, 'userHome', 'recent_applications'),
              style: AppTheme.labelLarge(
                context,
              ).copyWith(color: AppTheme.blackColor),
            ),
            SizedBox(height: verticalSpacing),

            // Recent applications list (placeholder for now)
            StreamBuilder<List<ClearanceApplication>>(
              stream: UserService().getUserApplications(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SkeletonListLoader(itemCount: 3);
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      _tr(context, 'userHome', 'error_loading_applications'),
                      style: TextStyle(color: AppTheme.errorColor),
                    ),
                  );
                }

                final applications = snapshot.data ?? [];
                final recentApps = applications.take(3).toList();

                if (recentApps.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inbox,
                          size: screenWidth * 0.15,
                          color: AppTheme.greyColor,
                        ),
                        SizedBox(height: verticalSpacing),
                        Text(
                          _tr(context, 'userHome', 'no_applications'),
                          style: AppTheme.bodyMedium(
                            context,
                          ).copyWith(color: AppTheme.greyColor),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  children: recentApps.map((app) {
                    final statusColor = _getStatusColor(app.status);
                    final statusText = _getStatusText(app.status, context);

                    return Container(
                      margin: EdgeInsets.only(bottom: verticalSpacing * 0.5),
                      padding: EdgeInsets.all(verticalSpacing),
                      decoration: BoxDecoration(
                        color: AppTheme.whiteColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.greyShade200),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.greyColor.withAlpha(13),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(
                            app.type == ApplicationType.kedatangan
                                ? Icons.anchor
                                : Icons.directions_boat,
                            color: AppTheme.primaryColor,
                            size: screenWidth * 0.06,
                          ),
                          SizedBox(width: horizontalPadding * 0.5),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  app.shipName,
                                  style: AppTheme.bodyMedium(context).copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.blackColor,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  app.date ?? 'No Date',
                                  style: AppTheme.bodySmall(
                                    context,
                                  ).copyWith(color: AppTheme.greyColor),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: screenWidth * 0.02,
                              vertical: screenWidth * 0.01,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withAlpha(25),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              statusText,
                              style: AppTheme.labelSmall(context).copyWith(
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required IconData serviceIcon,
    required bool isPrimary,
    required VoidCallback onTap,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cardPadding = screenWidth * 0.05;
    final iconSize = screenWidth * 0.08;
    final titleFontSize = AppTheme.responsiveFontSize(
      context,
      mobile: AppTheme.fontSizeH6,
      tablet: AppTheme.fontSizeH5,
      desktop: AppTheme.fontSizeH4,
    );
    final subtitleFontSize = AppTheme.responsiveFontSize(
      context,
      mobile: AppTheme.fontSizeBody2,
      tablet: AppTheme.fontSizeBody1,
      desktop: AppTheme.fontSizeBody1,
    );

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: EdgeInsets.all(cardPadding),
        decoration: BoxDecoration(
          color: isPrimary ? color : AppTheme.whiteColor,
          borderRadius: BorderRadius.circular(16),
          border: isPrimary ? null : Border.all(color: AppTheme.greyShade300),
          boxShadow: [
            BoxShadow(
              color: AppTheme.greyColor.withAlpha(25),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
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
                      color: isPrimary ? Colors.white : AppTheme.blackColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: screenWidth * 0.01),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: subtitleFontSize,
                      color: isPrimary
                          ? AppTheme.whiteColor70
                          : AppTheme.greyColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            SizedBox(width: screenWidth * 0.02),
            Icon(
              serviceIcon,
              size: iconSize,
              color: isPrimary ? Colors.white : AppTheme.primaryColor,
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(ApplicationStatus status) {
    switch (status) {
      case ApplicationStatus.waiting:
        return AppTheme.primaryColor;
      case ApplicationStatus.revision:
        return AppTheme.warningColor;
      case ApplicationStatus.approved:
        return AppTheme.successColor;
      case ApplicationStatus.declined:
        return AppTheme.errorColor;
    }
  }

  String _getStatusText(ApplicationStatus status, BuildContext context) {
    switch (status) {
      case ApplicationStatus.waiting:
        return _tr(context, 'userHistory', 'waiting');
      case ApplicationStatus.revision:
        return _tr(context, 'userHistory', 'revision');
      case ApplicationStatus.approved:
        return _tr(context, 'userHistory', 'approved');
      case ApplicationStatus.declined:
        return _tr(context, 'userHistory', 'declined');
    }
  }
}

// User History Screen - now imported from history_screen.dart
