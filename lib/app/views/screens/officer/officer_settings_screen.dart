import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import '../../../config/routes.dart';
import '../../../config/theme.dart';
import '../../../localization/app_localizations.dart';
import '../../../models/user_model.dart';
import '../../../providers/language_provider.dart';
import '../../../repositories/user_repository.dart';
import '../../../services/auth_service.dart';
import '../../../services/logging_service.dart';
import '../auth/change_password_screen.dart';
import '../../widgets/custom_app_bar.dart';

class OfficerSettingsScreen extends StatefulWidget {
  const OfficerSettingsScreen({super.key});

  @override
  State<OfficerSettingsScreen> createState() => _OfficerSettingsScreenState();
}

class _OfficerSettingsScreenState extends State<OfficerSettingsScreen> {
  String _tr(String key) =>
      AppLocalizations.of(context).get('officerSettings.$key');

  Future<void> _handleLogout(AuthService authService) async {
    final bool? shouldLogout = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          title: Text(
            _tr('logout_confirm_title'),
            style: AppTheme.headingSmall(context),
            textAlign: TextAlign.center,
          ),
          content: Text(
            _tr('logout_confirm_body'),
            style: AppTheme.bodyMedium(context),
            textAlign: TextAlign.center,
          ),
          actions: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(
                    _tr('no'),
                    style: AppTheme.bodyMedium(context).copyWith(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: Text(
                    _tr('yes'),
                    style: AppTheme.bodyMedium(context).copyWith(
                      color: AppTheme.whiteColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );

    if (shouldLogout == true) {
      await authService.signOut();
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
    }
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
        titleText: _tr('title'),
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
            return Center(child: Text(_tr('error_loading_user')));
          }
          if (!authSnapshot.hasData || authSnapshot.data == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              Navigator.of(
                context,
              ).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
            });
            return const SizedBox.shrink();
          }

          final user = authSnapshot.data!;

          return FutureBuilder<UserModel?>(
            future: UserRepository().getUser(user.uid),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (userSnapshot.hasError) {
                LoggingService().error(
                  'Error loading officer data',
                  userSnapshot.error,
                );
              }

              final userAccount = userSnapshot.data;
              final photoURL = userAccount?.photoURL ?? user.photoURL;
              final corporateName =
                  userAccount?.corporateName.trim() ?? user.displayName ?? '';
              final fullName =
                  userAccount?.fullName.trim() ?? user.displayName ?? '';
              final fallbackEmail = user.email ?? userAccount?.email ?? '';
              final primaryName = corporateName.isNotEmpty
                  ? corporateName
                  : fullName.isNotEmpty
                  ? fullName
                  : fallbackEmail;
              final secondaryName =
                  corporateName.isNotEmpty && fullName.isNotEmpty
                  ? fullName
                  : null;
              LoggingService().info(
                'Officer Settings Screen: photoURL = ${photoURL ?? 'N/A'}',
              );

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
                        child: (photoURL != null && photoURL.isNotEmpty)
                            ? ClipOval(
                                child: Image.network(
                                  photoURL,
                                  fit: BoxFit.cover,
                                  width: screenWidth * 0.24,
                                  height: screenWidth * 0.24,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Icon(
                                      Icons.person,
                                      size: screenWidth * 0.12,
                                      color: AppTheme.greyColor,
                                    );
                                  },
                                ),
                              )
                            : Icon(
                                Icons.person,
                                size: screenWidth * 0.12,
                                color: AppTheme.greyColor,
                              ),
                      ),
                    ),
                    SizedBox(height: verticalSpacing),

                    // User Info
                    Text(
                      primaryName,
                      style: AppTheme.headingSmall(context),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (secondaryName != null) ...[
                      SizedBox(height: screenWidth * 0.01),
                      Text(
                        secondaryName,
                        style: AppTheme.bodyMedium(
                          context,
                        ).copyWith(color: AppTheme.greyShade600),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    SizedBox(height: screenWidth * 0.01),
                    Text(
                      fallbackEmail,
                      style: AppTheme.bodySmall(
                        context,
                      ).copyWith(color: AppTheme.greyShade600),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: verticalSpacing * 2),

                    // Menu Items
                    _buildMenuItem(
                      context,
                      icon: Icons.edit,
                      title: _tr('editProfile'),
                      onTap: () async {
                        final result = await Navigator.pushNamed(
                          context,
                          AppRoutes.editOfficerProfile,
                        );
                        if (!mounted || result != true) return;
                        setState(() {});
                      },
                    ),
                    _buildMenuItem(
                      context,
                      icon: Icons.language,
                      title: _tr('language'),
                      onTap: () {
                        Navigator.pushNamed(
                          context,
                          AppRoutes.languageSelection,
                        );
                      },
                    ),
                    _buildMenuItem(
                      context,
                      icon: Icons.notifications_none_outlined,
                      title: _tr('notifications'),
                      onTap: () {
                        Navigator.pushNamed(
                          context,
                          AppRoutes.notificationSettings,
                        );
                      },
                    ),
                    _buildMenuItem(
                      context,
                      icon: Icons.lock_outline,
                      title: _tr('privacy_security'),
                      onTap: () {
                        Navigator.pushNamed(context, AppRoutes.privacySecurity);
                      },
                    ),
                    _buildMenuItem(
                      context,
                      icon: Icons.password_outlined,
                      title: _tr('change_password'),
                      onTap: () {
                        final languageCode = Provider.of<LanguageProvider>(
                          context,
                          listen: false,
                        ).locale.languageCode;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChangePasswordScreen(
                              initialLanguage: languageCode,
                            ),
                          ),
                        );
                      },
                    ),
                    _buildMenuItem(
                      context,
                      icon: Icons.logout,
                      title: _tr('logout'),
                      textColor: AppTheme.errorColor,
                      onTap: () => _handleLogout(authService),
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
      leading: Icon(
        icon,
        color: textColor ?? AppTheme.blackColor,
        size: iconSize,
      ),
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
      contentPadding: EdgeInsets.symmetric(
        horizontal: 0,
        vertical: verticalPadding * 1.5,
      ),
      dense: true,
    );
  }
}
