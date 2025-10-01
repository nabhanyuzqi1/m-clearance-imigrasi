import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../config/routes.dart';
import '../../../config/theme.dart';
import '../../../localization/app_localizations.dart';
import '../../../models/user_account.dart';
import '../../../providers/theme_provider.dart';
import '../../../services/logging_service.dart';
import '../auth/change_password_screen.dart';
import 'language_selection_screen.dart';
import '../../widgets/custom_app_bar.dart';

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

  String _themeLabel(BuildContext context, ThemeMode mode) {
    final localization = AppLocalizations.of(context);
    switch (mode) {
      case ThemeMode.light:
        return localization.get('userProfile.theme_light');
      case ThemeMode.dark:
        return localization.get('userProfile.theme_dark');
      case ThemeMode.system:
        return localization.get('userProfile.theme_system');
    }
  }

  Future<void> _showThemeSelector(BuildContext context) async {
    final localization = AppLocalizations.of(context);
    final themeProvider = context.read<ThemeProvider>();
    final options = [
      _ThemeOption(
        mode: ThemeMode.system,
        icon: Icons.brightness_auto_outlined,
        label: localization.get('userProfile.theme_system'),
      ),
      _ThemeOption(
        mode: ThemeMode.light,
        icon: Icons.light_mode_outlined,
        label: localization.get('userProfile.theme_light'),
      ),
      _ThemeOption(
        mode: ThemeMode.dark,
        icon: Icons.dark_mode_outlined,
        label: localization.get('userProfile.theme_dark'),
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
                localization.get('userProfile.theme'),
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

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = screenWidth * 0.04;
    final verticalSpacing = screenWidth * 0.02;

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final themeProvider = context.watch<ThemeProvider>();
    final themeLabel = _themeLabel(context, themeProvider.themeMode);

    final trimmedCorporateName = userAccount.corporateName.trim();
    final trimmedFullName = userAccount.fullName.trim();
    final trimmedEmail = userAccount.email.trim();
    final notAvailable = AppLocalizations.of(
      context,
    ).get('officerSettings.N/A');

    final identityValues = <String>[
      if (trimmedCorporateName.isNotEmpty) trimmedCorporateName,
      if (trimmedFullName.isNotEmpty) trimmedFullName,
    ];

    final primaryName = identityValues.isNotEmpty
        ? identityValues.first
        : (userAccount.name.isNotEmpty ? userAccount.name : trimmedEmail);

    final secondaryLines = identityValues
        .where((value) => value != primaryName)
        .toList(growable: false);

    return Scaffold(
      appBar: CustomAppBar(
        titleText: _tr(context, 'userProfile', 'settings_title'),
        centerTitle: true,
        toolbarHeight: 60,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: verticalSpacing,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: CircleAvatar(
                radius: screenWidth * 0.12,
                backgroundColor: colorScheme.surfaceContainerHighest,
                child: userAccount.profileImageUrl != null
                    ? ClipOval(
                        child: Image.network(
                          userAccount.profileImageUrl!,
                          fit: BoxFit.cover,
                          width: screenWidth * 0.24,
                          height: screenWidth * 0.24,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.person,
                              size: screenWidth * 0.12,
                              color: colorScheme.onSurfaceVariant,
                            );
                          },
                        ),
                      )
                    : Icon(
                        Icons.person,
                        size: screenWidth * 0.12,
                        color: colorScheme.onSurfaceVariant,
                      ),
              ),
            ),
            SizedBox(height: verticalSpacing),
            Text(
              primaryName,
              style: AppTheme.headingSmall(context),
              textAlign: TextAlign.center,
            ),
            for (final value in secondaryLines) ...[
              SizedBox(height: screenWidth * 0.01),
              Text(
                value,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            SizedBox(height: screenWidth * 0.01),
            Text(
              trimmedEmail.isNotEmpty ? trimmedEmail : notAvailable,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: verticalSpacing * 2),

            _buildMenuItem(
              context,
              icon: Icons.edit,
              title: _tr(context, 'userProfile', 'edit_profile'),
              onTap: () {
                LoggingService().info(
                  'Navigating to editAgentProfile with language: $initialLanguage',
                );
                Navigator.pushNamed(
                  context,
                  AppRoutes.editAgentProfile,
                  arguments: {
                    'username': userAccount.username,
                    'currentCorporateName': userAccount.corporateName,
                    'currentFullName': userAccount.fullName,
                    'currentEmail': userAccount.email,
                    'currentProfileImageUrl': userAccount.profileImageUrl,
                    'initialLanguage': initialLanguage,
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
              onTap: () =>
                  Navigator.pushNamed(context, AppRoutes.userNotification),
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
              icon: Icons.brightness_6_outlined,
              title: _tr(context, 'userProfile', 'theme'),
              trailingWidget: Text(
                themeLabel,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              onTap: () => _showThemeSelector(context),
            ),
            _buildMenuItem(
              context,
              icon: Icons.lock_outline,
              title: _tr(context, 'userProfile', 'privacy_security'),
              onTap: () =>
                  Navigator.pushNamed(context, AppRoutes.privacySecurity),
            ),
            _buildMenuItem(
              context,
              icon: Icons.password_outlined,
              title: _tr(context, 'userProfile', 'change_password'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        ChangePasswordScreen(initialLanguage: initialLanguage),
                  ),
                );
              },
            ),
            _buildMenuItem(
              context,
              icon: Icons.article_outlined,
              title: _tr(context, 'userProfile', 'terms'),
              onTap: () => Navigator.pushNamed(context, AppRoutes.terms),
            ),
            _buildMenuItem(
              context,
              icon: Icons.privacy_tip_outlined,
              title: _tr(context, 'userProfile', 'privacy'),
              onTap: () => Navigator.pushNamed(context, AppRoutes.privacy),
            ),
            _buildMenuItem(
              context,
              icon: Icons.logout,
              title: _tr(context, 'userProfile', 'logout'),
              textColor: colorScheme.error,
              trailingWidget: const SizedBox.shrink(),
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
    Color? textColor,
    VoidCallback? onTap,
    Widget? trailingWidget,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final iconSize = screenWidth * 0.052;
    final verticalPadding = screenWidth * 0.01;
    final titleStyle = textTheme.bodyLarge?.copyWith(
      color: textColor ?? colorScheme.onSurface,
      fontWeight: FontWeight.w500,
    );

    final trailing =
        trailingWidget ??
        Icon(
          Icons.chevron_right,
          size: iconSize * 0.8,
          color: colorScheme.onSurfaceVariant,
        );

    return ListTile(
      leading: Icon(
        icon,
        color: textColor ?? colorScheme.onSurface,
        size: iconSize,
      ),
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
