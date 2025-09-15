import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../localization/app_localizations.dart';
import '../../../localization/app_strings.dart';
import '../../../config/theme.dart';
import '../../../services/auth_service.dart';
import '../../../services/logging_service.dart';
import '../../../services/officer_service.dart';
import '../../../models/officer_activity.dart';
import 'account_verification_list_screen.dart';
import 'arrival_verification_screen.dart';
import 'departure_verification_screen.dart';
import 'email_config_screen.dart';
import 'officer_report_screen.dart';
import 'notification_screen.dart';
import 'officer_settings_screen.dart';
import '../../../services/functions_service.dart';
import '../../widgets/custom_bottom_navbar.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/skeleton_loader.dart';

class AdminHomeScreen extends StatefulWidget {
  final String adminName;
  final String adminUsername;

  const AdminHomeScreen({super.key, required this.adminName, required this.adminUsername});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    LoggingService().info('ProfileScreen initialized for admin: ${widget.adminName}');
    _loadSelectedIndex();
  }


  Future<void> _loadSelectedIndex() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedIndex = prefs.getInt('officer_selected_index') ?? 0;
    });
  }

  Future<void> _onItemTapped(int index) async {
    setState(() => _selectedIndex = index);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('officer_selected_index', index);
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = <Widget>[
      AdminMenuScreen(adminName: widget.adminName),
      const OfficerReportScreen(),
      const OfficerSettingsScreen(),
    ];

    return Scaffold(
      backgroundColor: AppTheme.whiteColor,
      body: pages.elementAt(_selectedIndex),
      bottomNavigationBar: CustomBottomNavbar(
        items: NavigationItems.officerItems,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: AppTheme.primaryColor,
        unselectedItemColor: AppTheme.greyColor,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        backgroundColor: AppTheme.whiteColor,
        elevation: 8,
      ),
    );
  }
}

class AdminMenuScreen extends StatelessWidget {
  final String adminName;
  const AdminMenuScreen({super.key, required this.adminName});

  @override
  Widget build(BuildContext context) {
    String tr(String stringKey) => AppLocalizations.of(context).get('adminHome.$stringKey');
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = screenWidth * 0.06;
    final verticalSpacing = screenWidth * 0.04;

    final functions = FunctionsService();
    final authService = AuthService();
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: AppTheme.whiteColor,
      appBar: CustomAppBar(
        title: LogoTitle(text: "M-Clearance ISam"),
        backgroundColor: AppTheme.whiteColor,
        foregroundColor: AppTheme.blackColor,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          NotificationIconWithBadge(
            badgeCount: 0, // You can implement notification count logic here
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const OfficerNotificationScreen()));
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(horizontalPadding),
        child: FutureBuilder(
          future: currentUser != null ? authService.getUserData(currentUser.uid) : null,
          builder: (context, userSnapshot) {
            final userRole = userSnapshot.data?.role ?? 'officer'; // Default to officer if not loaded
            LoggingService().info('Admin Home Screen: photoURL = ${userSnapshot.data?.photoURL}');
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: verticalSpacing),
                // Welcome section
                Row(
                  children: [
                    CircleAvatar(
                      radius: screenWidth * 0.08,
                      backgroundColor: AppTheme.greyShade200,
                      backgroundImage: (userSnapshot.data?.photoURL != null && userSnapshot.data!.photoURL!.isNotEmpty)
                          ? NetworkImage(userSnapshot.data!.photoURL!)
                          : null,
                      child: (userSnapshot.data?.photoURL == null || userSnapshot.data!.photoURL!.isEmpty)
                          ? Icon(Icons.person, size: screenWidth * 0.08, color: AppTheme.greyColor)
                          : null,
                    ),
                    SizedBox(width: screenWidth * 0.04),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "${tr('welcome')},",
                            style: AppTheme.bodyMedium(context).copyWith(color: AppTheme.greyColor),
                          ),
                          Text(
                            adminName,
                            style: AppTheme.headingSmall(context).copyWith(color: AppTheme.blackColor),
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
                  tr('services'),
                  style: AppTheme.headingSmall(context).copyWith(color: AppTheme.blackColor),
                ),
                SizedBox(height: verticalSpacing),

                FutureBuilder<Map<String, dynamic>>(
                  future: functions.getOfficerDashboardStats(),
                builder: (context, snapshot) {
                  final stats = snapshot.data ?? const {};
                  final pendingArrival = stats['pendingArrival']?.toString() ?? '';
                  final subtitle = pendingArrival.isNotEmpty
                      ? '${tr('agent_submissions')} ($pendingArrival)'
                      : tr('agent_submissions');
                  return _buildServiceCard(
                    context,
                    title: tr('arrival_verification'),
                    subtitle: subtitle,
                    iconData: Icons.anchor,
                    color: AppTheme.infoColor,
                    isPrimary: true,
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => ArrivalVerificationScreen(adminName: adminName)));
                    },
                  );
                },
                ),
                SizedBox(height: verticalSpacing),
                FutureBuilder<Map<String, dynamic>>(
                  future: functions.getOfficerDashboardStats(),
                  builder: (context, snapshot) {
                    final stats = snapshot.data ?? const {};
                    final pendingDeparture = stats['pendingDeparture']?.toString() ?? '';
                    final subtitle = pendingDeparture.isNotEmpty
                        ? '${tr('agent_submissions')} ($pendingDeparture)'
                        : tr('agent_submissions');
                    return _buildServiceCard(
                      context,
                      title: tr('departure_verification'),
                      subtitle: subtitle,
                      iconData: Icons.directions_boat,
                      color: AppTheme.secondaryColor,
                      isPrimary: false,
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => DepartureVerificationScreen(adminName: adminName)));
                      },
                    );
                  },
                ),
                SizedBox(height: verticalSpacing),
                FutureBuilder<Map<String, dynamic>>(
                  future: functions.getOfficerDashboardStats(),
                  builder: (context, snapshot) {
                    final stats = snapshot.data ?? const {};
                    final pendingAccounts = stats['pendingAccounts']?.toString() ?? '';
                    final subtitle = pendingAccounts.isNotEmpty
                        ? '${tr('agent_registrations')} ($pendingAccounts)'
                        : tr('agent_registrations');
                    return _buildServiceCard(
                      context,
                      title: tr('account_verification'),
                      subtitle: subtitle,
                      iconData: Icons.person_search,
                      color: AppTheme.secondaryColor,
                      isPrimary: false,
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const AccountVerificationListScreen()));
                      },
                    );
                  },
                ),
                if (userRole == 'admin') ...[
                  SizedBox(height: verticalSpacing),
                  _buildServiceCard(
                    context,
                    title: tr('email_configuration'),
                    subtitle: tr('manage_email_settings'),
                    iconData: Icons.email_outlined,
                    color: AppTheme.successColor,
                    isPrimary: false,
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const EmailConfigScreen()));
                    },
                  ),
                ],
                SizedBox(height: verticalSpacing * 2),
                Text(
                  tr('recent_activities'),
                  style: AppTheme.labelLarge(context).copyWith(color: AppTheme.blackColor),
                ),
                SizedBox(height: verticalSpacing),
                StreamBuilder<List<OfficerActivity>>(
                  stream: OfficerService().getOfficerActivities(limit: 3),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SkeletonListLoader(itemCount: 3);
                  }

                  if (snapshot.hasError) {
                    LoggingService().error('Error loading officer activities', snapshot.error);
                    return Center(
                      child: Text(
                        tr('error_loading_activities'),
                        style: TextStyle(color: AppTheme.errorColor),
                      ),
                    );
                  }

                  final activities = snapshot.data ?? [];

                  if (activities.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.history,
                            size: 48,
                            color: AppTheme.greyColor,
                          ),
                          SizedBox(height: AppTheme.spacing16),
                          Text(
                            tr('no_recent_activities'),
                            style: AppTheme.bodyMedium(context).copyWith(
                              color: AppTheme.greyColor,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }

                  return Column(
                    children: activities.map((activity) {
                      final statusColor = _getActivityStatusColor(activity.status);
                      final iconData = _getActivityIcon(activity.iconData);

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
                              iconData,
                              color: AppTheme.primaryColor,
                              size: screenWidth * 0.06,
                            ),
                            SizedBox(width: horizontalPadding * 0.5),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    activity.title,
                                    style: AppTheme.bodyMedium(context).copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.blackColor,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    _formatActivityDate(context, activity.date),
                                    style: AppTheme.bodySmall(context).copyWith(
                                      color: AppTheme.greyColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (activity.status != null)
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
                                  activity.status!.toUpperCase(),
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
            );
          },
        ),
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
    final screenWidth = MediaQuery.of(context).size.width;
    final cardPadding = screenWidth * 0.05;
    final iconSize = screenWidth * 0.08;
    final titleFontSize = AppTheme.responsiveFontSize(context, mobile: AppTheme.fontSizeH6, tablet: AppTheme.fontSizeH5, desktop: AppTheme.fontSizeH4);
    final subtitleFontSize = AppTheme.responsiveFontSize(context, mobile: AppTheme.fontSizeBody2, tablet: AppTheme.fontSizeBody1, desktop: AppTheme.fontSizeBody1);

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
                      color: isPrimary ? Colors.white : color,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: screenWidth * 0.01),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: subtitleFontSize,
                      color: isPrimary ? AppTheme.whiteColor70 : AppTheme.greyColor,
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

  Color _getActivityStatusColor(String? status) {
    if (status == null) return AppTheme.greyColor;
    switch (status.toLowerCase()) {
      case 'approved':
        return AppTheme.successColor;
      case 'declined':
      case 'rejected':
        return AppTheme.errorColor;
      case 'revision':
        return AppTheme.warningColor;
      case 'waiting':
        return AppTheme.primaryColor;
      case 'completed':
        return AppTheme.successColor;
      default:
        return AppTheme.greyColor;
    }
  }

  IconData _getActivityIcon(String? iconData) {
    if (iconData == null) return Icons.history;
    switch (iconData) {
      case 'anchor':
        return Icons.anchor;
      case 'directions_boat':
        return Icons.directions_boat;
      case 'person_search':
        return Icons.person_search;
      case 'description':
        return Icons.description;
      default:
        return Icons.history;
    }
  }

  String _formatActivityDate(BuildContext context, DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    String tr(String key) {
      return AppLocalizations.of(context).get('adminHome.$key');
    }

    if (difference.inDays == 0) {
      return tr('today');
    } else if (difference.inDays == 1) {
      return tr('yesterday');
    } else if (difference.inDays < 7) {
      return '${difference.inDays} ${tr('days_ago')}';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

