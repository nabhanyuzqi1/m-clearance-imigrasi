import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../config/theme.dart';
import '../../../localization/app_localizations.dart';
import '../../../models/officer_activity.dart';
import '../../../services/auth_service.dart';
import '../../../services/functions_service.dart';
import '../../../services/logging_service.dart';
import '../../../services/notification_service.dart';
import '../../../services/officer_service.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/custom_bottom_navbar.dart';
import '../../widgets/skeleton_loader.dart';
import '../../widgets/bouncing_dots_loader.dart';
import 'package:intl/intl.dart';
import 'account_verification_list_screen.dart';
import 'arrival_verification_screen.dart';
import 'departure_verification_screen.dart';
import 'email_config_screen.dart';
import 'notification_screen.dart';
import 'officer_report_screen.dart';
import 'officer_settings_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  final String adminName;
  final String adminUsername;
  final String adminCorporateName;
  final String? photoURL;

  const AdminHomeScreen({
    super.key,
    required this.adminName,
    required this.adminUsername,
    this.adminCorporateName = '',
    this.photoURL,
  });

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    LoggingService().info(
      'ProfileScreen initialized for admin: ${widget.adminName}',
    );
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
    final pages = <Widget>[
      AdminMenuScreen(
        adminName: widget.adminName,
        adminCorporateName: widget.adminCorporateName,
        photoURL: widget.photoURL,
      ),
      const OfficerReportScreen(),
      const OfficerSettingsScreen(),
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: pages.elementAt(_selectedIndex),
      bottomNavigationBar: CustomBottomNavbar(
        items: NavigationItems.officerItems,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Theme.of(context).colorScheme.onSurfaceVariant,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 8,
      ),
    );
  }
}

class AdminMenuScreen extends StatefulWidget {
  final String adminName;
  final String adminCorporateName;
  final String? photoURL;

  const AdminMenuScreen({
    super.key,
    required this.adminName,
    required this.adminCorporateName,
    this.photoURL,
  });

  @override
  State<AdminMenuScreen> createState() => _AdminMenuScreenState();
}

enum _PendingAction { arrival, departure, account }

class _AdminMenuScreenState extends State<AdminMenuScreen> {
  final FunctionsService _functionsService = FunctionsService();
  final AuthService _authService = AuthService();
  final NotificationService _notificationService = NotificationService();

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _dashboardSubscription;
  Map<String, dynamic>? _stats;
  bool _isLoadingStats = true;
  _PendingAction? _pendingAction;

  bool get _showSkeleton =>
      _isLoadingStats && (_stats == null || _stats!.isEmpty);

  @override
  void initState() {
    super.initState();
    _fetchInitialStats();
    _listenToRealtimeCounters();
  }

  @override
  void dispose() {
    _dashboardSubscription?.cancel();
    super.dispose();
  }

  Future<void> _fetchInitialStats() async {
    try {
      final data = await _functionsService.getOfficerDashboardStats();
      if (!mounted) return;
      setState(() {
        _stats = data;
        _isLoadingStats = false;
      });
    } catch (e) {
      LoggingService().error('Failed to load officer dashboard stats', e);
      if (!mounted) return;
      setState(() {
        _isLoadingStats = false;
      });
    }
  }

  void _listenToRealtimeCounters() {
    _dashboardSubscription = FirebaseFirestore.instance
        .collection('counters')
        .doc('dashboard')
        .snapshots()
        .listen(
          (snapshot) {
            final data = snapshot.data();
            if (!mounted || data == null) return;
            setState(() {
              _stats = {
                ...?_stats,
                if (data.containsKey('pendingAccounts'))
                  'pendingAccounts':
                      (data['pendingAccounts'] as num?)?.toInt() ?? 0,
                if (data.containsKey('pendingArrival'))
                  'pendingArrival':
                      (data['pendingArrival'] as num?)?.toInt() ?? 0,
                if (data.containsKey('pendingDeparture'))
                  'pendingDeparture':
                      (data['pendingDeparture'] as num?)?.toInt() ?? 0,
              };
            });
          },
          onError: (error) {
            LoggingService().error(
              'Error listening to dashboard counters',
              error,
            );
          },
        );
  }

  Future<void> _navigateWithGuard(
    _PendingAction action,
    Widget Function() builder,
  ) async {
    if (_pendingAction != null) return;
    setState(() => _pendingAction = action);
    try {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => builder()),
      );
    } finally {
      if (!mounted) {
        // Do nothing if not mounted
      }
      setState(() => _pendingAction = null);
    }
  }

  int _statValue(String key) {
    final value = _stats?[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    String tr(String key) => AppLocalizations.of(context).get('adminHome.$key');
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = screenWidth * 0.06;
    final verticalSpacing = screenWidth * 0.04;

    final currentUser = FirebaseAuth.instance.currentUser;

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: CustomAppBar(
        title: const LogoTitle(text: 'M-Clearance ISam'),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          NotificationIconWithBadge(
            badgeCountStream: _notificationService.getUnreadCount(),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const OfficerNotificationScreen(),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(horizontalPadding),
        child: FutureBuilder(
          future: currentUser != null
              ? _authService.getUserData(currentUser.uid, forceRefresh: true)
              : null,
          builder: (context, userSnapshot) {
            final userRole = userSnapshot.data?.role ?? 'officer';
            final userAccount = userSnapshot.data;
            final fetchedCorporateName =
                userAccount?.corporateName.trim() ?? '';
            final fetchedFullName = userAccount?.fullName.trim() ?? '';
            final fallbackCorporateName = widget.adminCorporateName.trim();
            final fallbackFullName = widget.adminName.trim();

            final primaryName = fetchedCorporateName.isNotEmpty
                ? fetchedCorporateName
                : fetchedFullName.isNotEmpty
                ? fetchedFullName
                : fallbackCorporateName.isNotEmpty
                ? fallbackCorporateName
                : fallbackFullName;

            final secondaryName =
                fetchedCorporateName.isNotEmpty && fetchedFullName.isNotEmpty
                ? fetchedFullName
                : '';

            final officerFullName = fetchedFullName.isNotEmpty
                ? fetchedFullName
                : fallbackFullName;

            final displayPhotoUrl = userAccount?.photoURL ?? widget.photoURL;

            LoggingService().info(
              'Admin Home Screen: photoURL = $displayPhotoUrl',
            );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: verticalSpacing),
                Row(
                  children: [
                    (displayPhotoUrl != null && displayPhotoUrl.isNotEmpty)
                        ? ClipOval(
                            child: Image.network(
                              displayPhotoUrl,
                              width: screenWidth * 0.16,
                              height: screenWidth * 0.16,
                              fit: BoxFit.cover,
                              errorBuilder:
                                  (
                                    BuildContext context,
                                    Object error,
                                    StackTrace? stackTrace,
                                  ) {
                                    LoggingService().error(
                                      'Profile image load failed: $error',
                                      error,
                                      stackTrace,
                                    );
                                    return Image.asset(
                                      'assets/images/logo.png',
                                      width: screenWidth * 0.16,
                                      height: screenWidth * 0.16,
                                      fit: BoxFit.cover,
                                    );
                                  },
                            ),
                          )
                        : CircleAvatar(
                            radius: screenWidth * 0.08,
                            backgroundColor:
                                colorScheme.surfaceContainerHighest,
                            child: Icon(
                              Icons.person,
                              size: screenWidth * 0.08,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                    SizedBox(width: screenWidth * 0.04),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr('welcome'),
                            style: textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            primaryName,
                            style: textTheme.titleLarge,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (secondaryName.isNotEmpty)
                            Padding(
                              padding: EdgeInsets.only(top: screenWidth * 0.01),
                              child: Text(
                                secondaryName,
                                style: textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: verticalSpacing * 1.5),
                Text(tr('services'), style: textTheme.titleLarge),
                SizedBox(height: verticalSpacing),
                _buildStatsAwareCard(
                  context,
                  isPrimary: true,
                  title: tr('arrival_verification'),
                  baseSubtitle: tr('agent_submissions'),
                  iconData: Icons.anchor,
                  color: colorScheme.primary,
                  badgeCount: _statValue('pendingArrival'),
                  isBusy: _pendingAction == _PendingAction.arrival,
                  onTap: () => _navigateWithGuard(
                    _PendingAction.arrival,
                    () => ArrivalVerificationScreen(adminName: officerFullName),
                  ),
                ),
                SizedBox(height: verticalSpacing),
                _buildStatsAwareCard(
                  context,
                  isPrimary: false,
                  title: tr('departure_verification'),
                  baseSubtitle: tr('agent_submissions'),
                  iconData: Icons.directions_boat,
                  color: colorScheme.secondary,
                  badgeCount: _statValue('pendingDeparture'),
                  isBusy: _pendingAction == _PendingAction.departure,
                  onTap: () => _navigateWithGuard(
                    _PendingAction.departure,
                    () =>
                        DepartureVerificationScreen(adminName: officerFullName),
                  ),
                ),
                SizedBox(height: verticalSpacing),
                _buildStatsAwareCard(
                  context,
                  isPrimary: false,
                  title: tr('account_verification'),
                  baseSubtitle: tr('agent_registrations'),
                  iconData: Icons.person_search,
                  color: colorScheme.tertiary,
                  badgeCount: _statValue('pendingAccounts'),
                  isBusy: _pendingAction == _PendingAction.account,
                  onTap: () => _navigateWithGuard(
                    _PendingAction.account,
                    () => const AccountVerificationListScreen(),
                  ),
                ),
                if (userRole == 'admin') ...[
                  SizedBox(height: verticalSpacing),
                  _buildServiceCard(
                    context,
                    title: tr('email_configuration'),
                    subtitle: tr('manage_email_settings'),
                    iconData: Icons.email_outlined,
                    color: colorScheme.tertiary,
                    isPrimary: false,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const EmailConfigScreen(),
                        ),
                      );
                    },
                  ),
                ],
                SizedBox(height: verticalSpacing * 2),
                Text(tr('recent_activities'), style: textTheme.titleLarge),
                SizedBox(height: verticalSpacing),
                StreamBuilder<List<OfficerActivity>>(
                  stream: OfficerService().getOfficerActivities(limit: 3),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const SkeletonListLoader(itemCount: 3);
                    }

                    if (snapshot.hasError) {
                      LoggingService().error(
                        'Error loading officer activities',
                        snapshot.error,
                      );
                      return Center(
                        child: Text(
                          tr('error_loading_activities'),
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.error,
                          ),
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
                              color: colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(height: AppTheme.spacing16),
                            Text(
                              tr('no_recent_activities'),
                              style: textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    }

                    return Column(
                      children: activities.map((activity) {
                        final statusColor = _getActivityStatusColor(
                          context,
                          activity.status,
                        );
                        final iconData = _getActivityIcon(activity.iconData);

                        return Container(
                          margin: EdgeInsets.only(
                            bottom: verticalSpacing * 0.5,
                          ),
                          padding: EdgeInsets.all(verticalSpacing),
                          decoration: BoxDecoration(
                            color: colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: colorScheme.outlineVariant,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: theme.shadowColor.withValues(
                                  alpha: 0.08,
                                ),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Icon(
                                iconData,
                                color: statusColor,
                                size: screenWidth * 0.06,
                              ),
                              SizedBox(width: horizontalPadding * 0.5),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      activity.title,
                                      style: textTheme.bodyLarge?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: colorScheme.onSurface,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: AppTheme.spacing4),
                                    Text(
                                      activity.description,
                                      style: textTheme.bodySmall?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: AppTheme.spacing8),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.access_time,
                                          size: 16,
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                        const SizedBox(
                                          width: AppTheme.spacing4,
                                        ),
                                        Text(
                                          _formatActivityDate(
                                            context,
                                            activity.date,
                                          ),
                                          style: textTheme.bodySmall?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
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
                                    color: statusColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    activity.status!.toUpperCase(),
                                    style: textTheme.labelSmall?.copyWith(
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

  Widget _buildStatsAwareCard(
    BuildContext context, {
    required String title,
    required String baseSubtitle,
    required IconData iconData,
    required Color color,
    required bool isPrimary,
    required int badgeCount,
    required VoidCallback onTap,
    bool isBusy = false,
  }) {
    if (_showSkeleton) {
      final screenWidth = MediaQuery.of(context).size.width;
      final cardHeight = screenWidth * 0.32;
      return SkeletonLoader(
        width: double.infinity,
        height: cardHeight,
        borderRadius: BorderRadius.circular(16),
      );
    }

    return _buildServiceCard(
      context,
      title: title,
      subtitle: baseSubtitle,
      iconData: iconData,
      color: color,
      isPrimary: isPrimary,
      badgeCount: badgeCount,
      onTap: onTap,
      isBusy: isBusy,
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
    int badgeCount = 0,
    bool isBusy = false,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
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

    final trailingWidget = isBusy
        ? SizedBox(
            width: iconSize,
            height: iconSize,
            child: Center(child: BouncingDotsLoader()),
          )
        : Icon(
            iconData,
            size: iconSize,
            color: isPrimary ? colorScheme.onPrimary : colorScheme.primary,
          );

    final cardContent = Container(
      padding: EdgeInsets.all(cardPadding),
      decoration: BoxDecoration(
        color: isPrimary ? color : colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: isPrimary
            ? null
            : Border.all(color: colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.1),
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
                  style:
                      textTheme.titleLarge?.copyWith(
                        fontSize: titleFontSize,
                        fontWeight: FontWeight.bold,
                        color: isPrimary
                            ? colorScheme.onPrimary
                            : colorScheme.onSurface,
                      ) ??
                      TextStyle(
                        fontSize: titleFontSize,
                        fontWeight: FontWeight.bold,
                        color: isPrimary
                            ? colorScheme.onPrimary
                            : colorScheme.onSurface,
                      ),
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: screenWidth * 0.01),
                Text(
                  subtitle,
                  style:
                      textTheme.bodyMedium?.copyWith(
                        fontSize: subtitleFontSize,
                        color: isPrimary
                            ? colorScheme.onPrimary.withValues(alpha: 0.7)
                            : colorScheme.onSurfaceVariant,
                      ) ??
                      TextStyle(
                        fontSize: subtitleFontSize,
                        color: isPrimary
                            ? colorScheme.onPrimary.withValues(alpha: 0.7)
                            : colorScheme.onSurfaceVariant,
                      ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          SizedBox(width: screenWidth * 0.02),
          trailingWidget,
        ],
      ),
    );

    final card = InkWell(
      onTap: isBusy ? null : onTap,
      borderRadius: BorderRadius.circular(16),
      child: cardContent,
    );

    final animatedCard = AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: isBusy ? 0.7 : 1.0,
      child: card,
    );

    if (badgeCount <= 0) {
      return animatedCard;
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        animatedCard,
        Positioned(
          top: -8,
          right: -8,
          child: _buildBadge(context, badgeCount, isPrimary),
        ),
      ],
    );
  }

  Widget _buildBadge(BuildContext context, int count, bool isPrimary) {
    final colorScheme = Theme.of(context).colorScheme;
    final displayCount = count > 99 ? '99+' : count.toString();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.error,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPrimary ? colorScheme.onPrimary : colorScheme.surface,
          width: 2,
        ),
      ),
      child: Text(
        displayCount,
        style: TextStyle(
          color: colorScheme.onError,
          fontSize: AppTheme.fontSizeBody2,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Color _getActivityStatusColor(BuildContext context, String? status) {
    final colorScheme = Theme.of(context).colorScheme;
    if (status == null) return colorScheme.onSurfaceVariant;
    switch (status.toLowerCase()) {
      case 'approved':
        return colorScheme.primary;
      case 'declined':
      case 'rejected':
        return colorScheme.error;
      case 'revision':
        return colorScheme.tertiary;
      case 'waiting':
        return colorScheme.secondary;
      case 'completed':
        return colorScheme.primary;
      default:
        return colorScheme.onSurfaceVariant;
    }
  }

  IconData _getActivityIcon(String? iconData) {
    switch (iconData) {
      case 'document':
        return Icons.description_outlined;
      case 'analytics':
        return Icons.analytics_outlined;
      case 'person':
        return Icons.person_outline;
      default:
        return Icons.task_alt_outlined;
    }
  }

  String _formatActivityDate(BuildContext context, DateTime date) {
    final now = DateTime.now();
    final localDate = date.toLocal();
    if (localDate.year == now.year &&
        localDate.month == now.month &&
        localDate.day == now.day) {
      return DateFormat.Hm().format(localDate);
    }
    return DateFormat('dd MMM yyyy • HH:mm').format(localDate);
  }
}
