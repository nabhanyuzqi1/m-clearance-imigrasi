import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import '../../../config/routes.dart';
import '../../../config/theme.dart';
import '../../../localization/app_localizations.dart';
import '../../../models/user_model.dart';
import '../../../providers/language_provider.dart';
import '../../../providers/theme_provider.dart';
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

  String _themeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return _tr('theme_light');
      case ThemeMode.dark:
        return _tr('theme_dark');
      case ThemeMode.system:
        return _tr('theme_system');
    }
  }

  Future<void> _showThemeSelector(BuildContext context) async {
    final themeProvider = context.read<ThemeProvider>();
    final options = [
      _ThemeOption(
        mode: ThemeMode.system,
        icon: Icons.brightness_auto_outlined,
        label: _tr('theme_system'),
      ),
      _ThemeOption(
        mode: ThemeMode.light,
        icon: Icons.light_mode_outlined,
        label: _tr('theme_light'),
      ),
      _ThemeOption(
        mode: ThemeMode.dark,
        icon: Icons.dark_mode_outlined,
        label: _tr('theme_dark'),
      ),
    ];

    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (bottomContext) {
        final scheme = Theme.of(bottomContext).colorScheme;
        final textTheme = Theme.of(bottomContext).textTheme;
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.spacing24,
            AppTheme.spacing16,
            AppTheme.spacing24,
            AppTheme.spacing24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _tr('theme'),
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: AppTheme.spacing16),
              RadioGroup<ThemeMode>(
                onChanged: (value) {
                  if (value == null) return;
                  themeProvider.setThemeMode(value);
                  Navigator.of(bottomContext).pop();
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: options
                      .map(
                        (option) => ListTile(
                          leading: Radio<ThemeMode>(value: option.mode),
                          title: Row(
                            children: [
                              Icon(option.icon, color: scheme.primary),
                              const SizedBox(width: AppTheme.spacing12),
                              Text(option.label, style: textTheme.bodyLarge),
                            ],
                          ),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

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
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: Text(
                    _tr('yes'),
                    style: AppTheme.bodyMedium(context).copyWith(
                      color: Theme.of(context).colorScheme.onPrimary,
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final themeProvider = context.watch<ThemeProvider>();

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: CustomAppBar(
        titleText: _tr('title'),
        centerTitle: true,
        toolbarHeight: 60,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
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

              final scheme = Theme.of(context).colorScheme;
              final textTheme = Theme.of(context).textTheme;
              final themeLabel = _themeLabel(themeProvider.themeMode);
              final isAdmin =
                  (userAccount?.role ?? '').toLowerCase() == 'admin';

              return SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: verticalSpacing),
                    Center(
                      child: CircleAvatar(
                        radius: screenWidth * 0.12,
                        backgroundColor: scheme.surfaceContainerHighest,
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
                                      color: scheme.onSurfaceVariant,
                                    );
                                  },
                                ),
                              )
                            : Icon(
                                Icons.person,
                                size: screenWidth * 0.12,
                                color: scheme.onSurfaceVariant,
                              ),
                      ),
                    ),
                    SizedBox(height: verticalSpacing),
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
                        style: textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    SizedBox(height: screenWidth * 0.01),
                    Text(
                      fallbackEmail,
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: verticalSpacing * 2),

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
                      icon: Icons.brightness_6_outlined,
                      title: _tr('theme'),
                      trailingWidget: Text(
                        themeLabel,
                        style: textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      onTap: () => _showThemeSelector(context),
                    ),
                    _buildMenuItem(
                      context,
                      icon: Icons.lock_outline,
                      title: _tr('privacy_security'),
                      onTap: () => Navigator.pushNamed(
                        context,
                        AppRoutes.privacySecurity,
                      ),
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
                      icon: Icons.article_outlined,
                      title: _tr('terms'),
                      onTap: () =>
                          Navigator.pushNamed(context, AppRoutes.terms),
                    ),
                    _buildMenuItem(
                      context,
                      icon: Icons.privacy_tip_outlined,
                      title: _tr('privacy'),
                      onTap: () =>
                          Navigator.pushNamed(context, AppRoutes.privacy),
                    ),
                    if (isAdmin)
                      _buildMenuItem(
                        context,
                        icon: Icons.manage_accounts_outlined,
                        title: _tr('manage_legal_content'),
                        onTap: () =>
                            Navigator.pushNamed(context, AppRoutes.legalEditor),
                      ),
                    _buildMenuItem(
                      context,
                      icon: Icons.logout,
                      title: _tr('logout'),
                      textColor: scheme.error,
                      trailingWidget: const SizedBox.shrink(),
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
    VoidCallback? onTap,
    Widget? trailingWidget,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final iconSize = screenWidth * 0.052;
    final verticalPadding = screenWidth * 0.01;
    final titleStyle = textTheme.bodyLarge?.copyWith(
      color: textColor ?? scheme.onSurface,
      fontWeight: FontWeight.w500,
    );

    final trailing =
        trailingWidget ??
        Icon(
          Icons.chevron_right,
          size: iconSize * 0.8,
          color: scheme.onSurfaceVariant,
        );

    return ListTile(
      leading: Icon(icon, color: textColor ?? scheme.onSurface, size: iconSize),
      title: Text(title, style: titleStyle, overflow: TextOverflow.ellipsis),
      trailing: trailing,
      onTap: onTap,
      enabled: onTap != null,
      minLeadingWidth: 0,
      dense: false,
      contentPadding: EdgeInsets.symmetric(
        horizontal: 0,
        vertical: verticalPadding * 1.5,
      ),
    );
  }
}

class _ThemeOption {
  const _ThemeOption({
    required this.mode,
    required this.icon,
    required this.label,
  });

  final ThemeMode mode;
  final IconData icon;
  final String label;
}
