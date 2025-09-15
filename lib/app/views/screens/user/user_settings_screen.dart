import 'package:flutter/material.dart';
import '../../../config/routes.dart';
import '../../../config/theme.dart';
import '../../../localization/app_strings.dart';
import '../../../localization/app_localizations.dart';
import '../../../models/user_account.dart';
import '../../../services/logging_service.dart';
import '../auth/change_password_screen.dart';
import 'language_selection_screen.dart';
import '../../widgets/custom_app_bar.dart';

ImageProvider<Object> _buildProfileImage(String imageUrl, double screenWidth) {
  try {
    return NetworkImage(imageUrl);
  } catch (e) {
    LoggingService().error('Error loading profile image: $e');
    return const AssetImage('assets/images/logo.png'); // Fallback image
  }
}

class UserSettingsScreen extends StatelessWidget {
  final UserAccount userAccount;
  final VoidCallback onRefresh;
  final VoidCallback onLogout;
  final String initialLanguage;

  const UserSettingsScreen({
    super.key,
    required this.userAccount,
    required this.onRefresh,
    required this.onLogout,
    required this.initialLanguage,
  });

  String _tr(BuildContext context, String screenKey, String stringKey) =>
      AppLocalizations.of(context).get('$screenKey.$stringKey');

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = screenWidth * 0.04;
    final verticalSpacing = screenWidth * 0.02;

    return Scaffold(
      backgroundColor: AppTheme.whiteColor,
      appBar: CustomAppBar(
        titleText: _tr(context, 'userProfile', 'settings_title'),
        centerTitle: true,
        toolbarHeight: 60,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: verticalSpacing),
        child: Column(
          children: [
            // Profile Picture Section
            Center(
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: screenWidth * 0.12,
                    backgroundColor: AppTheme.greyShade200,
                    backgroundImage: userAccount.profileImageUrl != null
                        ? _buildProfileImage(userAccount.profileImageUrl!, screenWidth)
                        : null,
                    child: userAccount.profileImageUrl == null
                        ? Icon(Icons.person, size: screenWidth * 0.12, color: AppTheme.greyColor)
                        : null,
                  ),
                ],
              ),
            ),
            SizedBox(height: verticalSpacing),

            // User Info
            Text(
              userAccount.name,
              style: AppTheme.headingSmall(context),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: screenWidth * 0.01),
            Text(
              userAccount.email,
              style: AppTheme.bodySmall(context).copyWith(
                color: AppTheme.greyShade600,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: verticalSpacing),

            // Menu Items
            _buildMenuItem(
              context,
              icon: Icons.edit,
              title: _tr(context, 'userProfile', 'edit_profile'),
              onTap: () {
                LoggingService().info('Navigating to editAgentProfile with language: $initialLanguage');
                Navigator.pushNamed(
                  context,
                  AppRoutes.editAgentProfile,
                  arguments: {
                    'username': userAccount.username,
                    'currentName': userAccount.name,
                    'currentEmail': userAccount.email,
                    'currentProfileImageUrl': userAccount.profileImageUrl,
                    'initialLanguage': initialLanguage, // Add this!
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

            _buildMenuItem(
              context,
              icon: Icons.logout,
              title: _tr(context, 'userProfile', 'logout'),
              textColor: AppTheme.errorColor,
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
    final iconSize = screenWidth * 0.05;
    final fontSize = AppTheme.responsiveFontSize(context, mobile: AppTheme.fontSizeBody1, tablet: AppTheme.fontSizeBody1, desktop: AppTheme.fontSizeBody1);
    final verticalPadding = screenWidth * 0.01;

    return ListTile(
      leading: Icon(icon, color: textColor ?? AppTheme.blackColor, size: iconSize),
      title: Text(
        title,
        style: TextStyle(
          color: textColor ?? AppTheme.blackColor,
          fontSize: fontSize,
        ),
        overflow: TextOverflow.ellipsis,
      ),
      trailing: trailing != null
          ? Text(trailing, style: TextStyle(color: AppTheme.greyShade600, fontSize: fontSize))
          : Icon(Icons.arrow_forward_ios, size: iconSize * 0.5),
      onTap: onTap,
      contentPadding: EdgeInsets.symmetric(horizontal: 0, vertical: verticalPadding * 1.5),
    );
  }
}