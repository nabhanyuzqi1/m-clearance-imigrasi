import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../../config/routes.dart';
import '../../../config/theme.dart';
import '../../../localization/app_localizations.dart';
import '../../../models/notification_preferences.dart';
import '../../../services/logging_service.dart';
import '../../../services/notification_service.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/bouncing_dots_loader.dart';

class NotificationSettingsScreen extends StatefulWidget {
  final String initialLanguage;

  const NotificationSettingsScreen({super.key, required this.initialLanguage});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool _muteNotifications = false;
  bool _toggleSound = true;
  bool _pushNotificationsEnabled = false;
  bool _badgeEnabled = true;
  NotificationSettings? _permissionStatus;
  bool _isLoadingPermissions = false;
  bool _isSavingPrefs = false;
  NotificationPreferences? _preferences;

  final NotificationService _notificationService = NotificationService();

  String _tr(String screenKey, String stringKey) =>
      AppLocalizations.of(context).get('$screenKey.$stringKey');

  @override
  void initState() {
    super.initState();
    _initialise();
  }

  Future<void> _initialise() async {
    await _notificationService.ensureInitialised();
    await _checkPermissionStatus();
    await _loadPreferences();
  }

  Future<void> _checkPermissionStatus() async {
    setState(() => _isLoadingPermissions = true);
    try {
      final status = await _notificationService.checkPermissionStatus();
      setState(() {
        _permissionStatus = status;
        _pushNotificationsEnabled =
            status?.authorizationStatus == AuthorizationStatus.authorized;
      });
    } catch (e) {
      LoggingService().error('Error checking permission status', e);
    } finally {
      setState(() => _isLoadingPermissions = false);
    }
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await _notificationService.getPreferences();
      setState(() {
        _preferences = prefs;
        _muteNotifications = prefs.muteAll;
        _toggleSound = prefs.playSound;
        _badgeEnabled = prefs.badgeEnabled;
        if (!prefs.pushEnabled) {
          _pushNotificationsEnabled = false;
        }
      });
    } catch (e) {
      LoggingService().error('Failed to load notification preferences', e);
    }
  }

  Future<void> _persistPreferences(NotificationPreferences preferences) async {
    setState(() => _isSavingPrefs = true);
    try {
      await _notificationService.updatePreferences(preferences);
      setState(() {
        _preferences = preferences;
      });
    } catch (e) {
      LoggingService().error('Failed to update notification preferences', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_tr('notificationSettings', 'update_failed'))),
        );
        await _loadPreferences();
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingPrefs = false);
      }
    }
  }

  Future<void> _requestPermissions() async {
    setState(() => _isLoadingPermissions = true);
    try {
      final status = await _notificationService.requestPermissions();
      setState(() {
        _permissionStatus = status;
        _pushNotificationsEnabled =
            status?.authorizationStatus == AuthorizationStatus.authorized;
      });
      if (_pushNotificationsEnabled) {
        final updatedPrefs =
            (_preferences ??
                    const NotificationPreferences(
                      pushEnabled: true,
                      muteAll: false,
                      playSound: true,
                      badgeEnabled: true,
                    ))
                .copyWith(pushEnabled: true);
        await _persistPreferences(updatedPrefs);
      }
    } catch (e) {
      LoggingService().error('Error requesting permissions', e);
    } finally {
      setState(() => _isLoadingPermissions = false);
    }
  }

  Future<void> _handlePushToggle(bool value) async {
    if (value) {
      final status = await _notificationService.requestPermissions();
      if (status?.authorizationStatus != AuthorizationStatus.authorized) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_tr('notificationSettings', 'permission_required')),
            ),
          );
        }
        setState(() => _pushNotificationsEnabled = false);
        return;
      }
    } else {
      await _notificationService.deleteFcmToken();
    }

    setState(() => _pushNotificationsEnabled = value);
    final current =
        _preferences ??
        NotificationPreferences(
          pushEnabled: value,
          muteAll: _muteNotifications,
          playSound: _toggleSound,
          badgeEnabled: _badgeEnabled,
        );
    await _persistPreferences(current.copyWith(pushEnabled: value));
  }

  Future<void> _handleMuteToggle(bool value) async {
    setState(() => _muteNotifications = value);
    final prefs =
        (_preferences ??
                NotificationPreferences(
                  pushEnabled: _pushNotificationsEnabled,
                  muteAll: value,
                  playSound: _toggleSound,
                  badgeEnabled: _badgeEnabled,
                ))
            .copyWith(muteAll: value);
    await _persistPreferences(prefs);
  }

  Future<void> _handleSoundToggle(bool value) async {
    setState(() => _toggleSound = value);
    final prefs =
        (_preferences ??
                NotificationPreferences(
                  pushEnabled: _pushNotificationsEnabled,
                  muteAll: _muteNotifications,
                  playSound: value,
                  badgeEnabled: _badgeEnabled,
                ))
            .copyWith(playSound: value);
    await _persistPreferences(prefs);
  }

  Future<void> _handleBadgeToggle(bool value) async {
    setState(() => _badgeEnabled = value);
    final prefs =
        (_preferences ??
                NotificationPreferences(
                  pushEnabled: _pushNotificationsEnabled,
                  muteAll: _muteNotifications,
                  playSound: _toggleSound,
                  badgeEnabled: value,
                ))
            .copyWith(badgeEnabled: value);
    await _persistPreferences(prefs);
  }

  @override
  Widget build(BuildContext context) {
    LoggingService().debug(
      'Building NotificationSettingsScreen with language: ${widget.initialLanguage}',
    );
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = screenWidth > 600
        ? AppTheme.spacing32
        : AppTheme.spacing16;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    void pushHandler(bool value) {
      if (_isSavingPrefs) return;
      unawaited(_handlePushToggle(value));
    }

    void muteHandler(bool value) {
      if (_isSavingPrefs) return;
      unawaited(_handleMuteToggle(value));
    }

    void soundHandler(bool value) {
      if (_isSavingPrefs) return;
      unawaited(_handleSoundToggle(value));
    }

    void badgeHandler(bool value) {
      if (_isSavingPrefs) return;
      unawaited(_handleBadgeToggle(value));
    }

    return Scaffold(
      appBar: CustomAppBar(
        titleText: _tr('notificationSettings', 'title'),
        centerTitle: true,
      ),
      body: ListView(
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: AppTheme.spacing24,
        ),
        children: [
          // Push Notifications Section
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              side: BorderSide(color: colorScheme.outlineVariant),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    Icons.notifications_outlined,
                    color: colorScheme.primary,
                  ),
                  title: Text(
                    _tr('notificationSettings', 'push_notifications'),
                    style: theme.textTheme.bodyLarge,
                  ),
                  subtitle: _isLoadingPermissions
                      ? Text(
                          _tr('notificationSettings', 'checking_permissions'),
                        )
                      : Text(
                          _pushNotificationsEnabled
                              ? _tr('notificationSettings', 'status_enabled')
                              : _tr('notificationSettings', 'status_disabled'),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: _pushNotificationsEnabled
                                ? colorScheme.primary
                                : colorScheme.error,
                          ),
                        ),
                  trailing: !_pushNotificationsEnabled
                      ? ElevatedButton(
                          onPressed: (_isLoadingPermissions || _isSavingPrefs)
                              ? null
                              : _requestPermissions,
                          child: Text(_tr('notificationSettings', 'enable')),
                        )
                      : null,
                ),
                if ((_permissionStatus?.authorizationStatus ==
                        AuthorizationStatus.authorized) ||
                    _pushNotificationsEnabled)
                  Column(
                    children: [
                      const Divider(height: 1),
                      _buildSwitchTile(
                        context,
                        title: _tr(
                          'notificationSettings',
                          'receive_push_notifications',
                        ),
                        value: _pushNotificationsEnabled,
                        enabled: !_isSavingPrefs,
                        onChanged: pushHandler,
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.spacing16),
          // In-App Notifications Section
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              side: BorderSide(color: colorScheme.outlineVariant),
            ),
            child: Column(
              children: [
                _buildSwitchTile(
                  context,
                  title: _tr('notificationSettings', 'mute_notifications'),
                  value: _muteNotifications,
                  enabled: !_isSavingPrefs,
                  onChanged: muteHandler,
                ),
                const Divider(height: 1),
                _buildSwitchTile(
                  context,
                  title: _tr('notificationSettings', 'toggle_sound'),
                  value: _toggleSound,
                  enabled: !_isSavingPrefs,
                  onChanged: soundHandler,
                ),
                const Divider(height: 1),
                _buildSwitchTile(
                  context,
                  title: _tr('notificationSettings', 'enable_app_icon_badge'),
                  value: _badgeEnabled,
                  enabled: !_isSavingPrefs,
                  onChanged: badgeHandler,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.spacing16),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              side: BorderSide(color: colorScheme.outlineVariant),
            ),
            child: ListTile(
              leading: Icon(
                Icons.notifications_active_outlined,
                color: colorScheme.primary,
              ),
              title: Text(
                _tr('notificationSettings', 'view_notifications'),
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).pushNamed(
                  AppRoutes.userNotification,
                  arguments: {'initialLanguage': widget.initialLanguage},
                );
              },
            ),
          ),
          if (_isSavingPrefs)
            const Padding(
              padding: EdgeInsets.only(top: AppTheme.spacing16),
              child: Center(child: BouncingDotsLoader()),
            ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile(
    BuildContext context, {
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool enabled = true,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return IgnorePointer(
      ignoring: !enabled,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.5,
        child: SwitchListTile(
          title: Text(title, style: theme.textTheme.bodyLarge),
          activeThumbColor: colorScheme.primary,
          value: value,
          onChanged: onChanged,
        ),
      ),
    );
  }
}
