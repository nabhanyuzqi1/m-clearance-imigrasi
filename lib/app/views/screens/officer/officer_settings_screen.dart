import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../../models/user_model.dart';
import '../../../services/logging_service.dart';
import '../../../repositories/user_repository.dart';
import '../../../config/theme.dart';
import '../../../services/auth_service.dart';
import '../../../config/routes.dart';
import '../../../providers/language_provider.dart';
import '../../../localization/app_strings.dart';
import '../../../localization/app_localizations.dart';
import '../auth/change_password_screen.dart';
import '../../widgets/custom_app_bar.dart';

class OfficerSettingsScreen extends StatelessWidget {
  const OfficerSettingsScreen({super.key});

  String _tr(BuildContext context, String key) {
    return AppLocalizations.of(context).get('officerSettings.$key');
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = screenWidth * 0.05;
    final verticalSpacing = screenWidth * 0.025;

    return Scaffold(
      backgroundColor: AppTheme.whiteColor,
      appBar: CustomAppBar(
        titleText: _tr(context, 'title'),
        centerTitle: true,
        toolbarHeight: 60,
      ),
      body: StreamBuilder<User?>(
        stream: authService.authStateChanges,
        builder: (context, authSnapshot) {
          if (authSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (authSnapshot.hasError) {
            return Center(child: Text(_tr(context, 'error_loading_user')));
          }
          if (!authSnapshot.hasData || authSnapshot.data == null) {
            return Center(child: Text(_tr(context, 'no_user_found')));
          }

          final user = authSnapshot.data!;

          return FutureBuilder<UserModel?>(
            future: UserRepository().getUser(user.uid),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (userSnapshot.hasError) {
                return Center(
                    child: Text(_tr(context, 'error_loading_user_data')));
              }
              if (!userSnapshot.hasData || userSnapshot.data == null) {
                return Center(
                    child: Text(_tr(context, 'user_data_not_found')));
              }

              final userAccount = userSnapshot.data!;
              final photoURL = userAccount.photoURL;
              LoggingService().info('Officer Settings Screen: photoURL = $photoURL');
              return SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: Column(
                  children: [
                    SizedBox(height: verticalSpacing),
                    // Profile Picture Section
                    Center(
                      child: CircleAvatar(
                        radius: screenWidth * 0.12,
                        backgroundColor: AppTheme.greyShade200,
                        backgroundImage:
                            (photoURL != null && photoURL.isNotEmpty)
                                ? NetworkImage(photoURL)
                                : null,
                        child: (photoURL == null || photoURL.isEmpty)
                            ? Icon(Icons.person,
                                size: screenWidth * 0.12,
                                color: AppTheme.greyColor)
                            : null,
                      ),
                    ),
                    SizedBox(height: verticalSpacing),

                    // User Info
                    Text(
                      userAccount.fullName,
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
            SizedBox(height: verticalSpacing * 2),

            // Menu Items
            _buildMenuItem(
              context,
              icon: Icons.edit,
              title: _tr(context, 'editProfile'),
              onTap: () {
                Navigator.pushNamed(context, AppRoutes.editOfficerProfile);
              },
            ),
            _buildMenuItem(
              context,
              icon: Icons.language,
              title: _tr(context, 'language'),
              onTap: () {
                Navigator.pushNamed(context, AppRoutes.languageSelection);
              },
            ),
            _buildMenuItem(
              context,
              icon: Icons.notifications_none_outlined,
              title: _tr(context, 'notifications'),
              onTap: () {
                Navigator.pushNamed(context, AppRoutes.notificationSettings);
              },
            ),
            _buildMenuItem(
              context,
              icon: Icons.lock_outline,
              title: _tr(context, 'privacy_security'),
              onTap: () {
                Navigator.pushNamed(context, AppRoutes.privacySecurity);
              },
            ),
            _buildMenuItem(
              context,
              icon: Icons.password_outlined,
              title: _tr(context, 'change_password'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChangePasswordScreen(
                      initialLanguage: Provider.of<LanguageProvider>(context,
                              listen: false)
                          .locale
                          .languageCode,
                    ),
                  ),
                );
              },
            ),
            _buildMenuItem(
              context,
              icon: Icons.logout,
              title: _tr(context, 'logout'),
              textColor: AppTheme.errorColor,
              onTap: () async {
                final bool? shouldLogout = await showDialog<bool>(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.0),
                      ),
                      title: Text(
                        _tr(context, 'logout_confirm_title'),
                        style: AppTheme.headingSmall(context),
                        textAlign: TextAlign.center,
                      ),
                      content: Text(
                        _tr(context, 'logout_confirm_body'),
                        style: AppTheme.bodyMedium(context),
                        textAlign: TextAlign.center,
                      ),
                      actions: <Widget>[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            TextButton(
                              child: Text(
                                _tr(context, 'no'),
                                style: AppTheme.bodyMedium(context).copyWith(
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              onPressed: () {
                                Navigator.of(context).pop(false);
                              },
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                              ),
                              child: Text(
                                _tr(context, 'yes'),
                                style: AppTheme.bodyMedium(context).copyWith(
                                  color: AppTheme.whiteColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              onPressed: () {
                                Navigator.of(context).pop(true);
                              },
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                );

                if (shouldLogout == true) {
                  await authService.signOut();
                  Navigator.of(context).pushNamedAndRemoveUntil(
                      AppRoutes.login, (route) => false);
                }
              },
            ),
              ],
            ),
          );
        },
      );
    },
  ),
);
}

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    Color? textColor,
    required VoidCallback onTap,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final iconSize = screenWidth * 0.05;
    final fontSize = AppTheme.responsiveFontSize(
      context,
      mobile: AppTheme.fontSizeBody1,
      tablet: AppTheme.fontSizeBody1,
      desktop: AppTheme.fontSizeBody1,
    );
    final verticalPadding = screenWidth * 0.01;

    return ListTile(
      leading:
          Icon(icon, color: textColor ?? AppTheme.blackColor, size: iconSize),
      title: Text(
        title,
        style: TextStyle(
          color: textColor ?? AppTheme.blackColor,
          fontSize: fontSize,
          fontWeight: FontWeight.w500,
        ),
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Icon(Icons.arrow_forward_ios, size: iconSize * 0.5),
      onTap: onTap,
      contentPadding:
          EdgeInsets.symmetric(horizontal: 0, vertical: verticalPadding * 1.5),
      dense: true,
    );
  }
}