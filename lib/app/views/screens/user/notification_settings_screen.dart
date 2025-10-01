import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../../config/theme.dart';
import '../../../localization/app_localizations.dart';
import '../../../services/logging_service.dart';
import '../../../services/notification_service.dart';
import '../../widgets/custom_app_bar.dart';

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
  NotificationSettings? _permissionStatus;
  bool _isLoadingPermissions = false;

  final NotificationService _notificationService = NotificationService();

  String _tr(String screenKey, String stringKey) =>
      AppLocalizations.of(context).get('$screenKey.$stringKey');

  @override
  void initState() {
    super.initState();
    _checkPermissionStatus();
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

  Future<void> _requestPermissions() async {
    setState(() => _isLoadingPermissions = true);
    try {
      final status = await _notificationService.requestPermissions();
      setState(() {
        _permissionStatus = status;
        _pushNotificationsEnabled =
            status?.authorizationStatus == AuthorizationStatus.authorized;
      });
    } catch (e) {
      LoggingService().error('Error requesting permissions', e);
    } finally {
      setState(() => _isLoadingPermissions = false);
    }
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
                    'Push Notifications',
                    style: theme.textTheme.bodyLarge,
                  ),
                  subtitle: _isLoadingPermissions
                      ? const Text('Checking permissions...')
                      : Text(
                          _permissionStatus?.authorizationStatus ==
                                  AuthorizationStatus.authorized
                              ? 'Enabled'
                              : 'Disabled',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color:
                                _permissionStatus?.authorizationStatus ==
                                    AuthorizationStatus.authorized
                                ? colorScheme.primary
                                : colorScheme.error,
                          ),
                        ),
                  trailing:
                      _permissionStatus?.authorizationStatus !=
                          AuthorizationStatus.authorized
                      ? ElevatedButton(
                          onPressed: _isLoadingPermissions
                              ? null
                              : _requestPermissions,
                          child: const Text('Enable'),
                        )
                      : null,
                ),
                if (_permissionStatus?.authorizationStatus ==
                    AuthorizationStatus.authorized)
                  Column(
                    children: [
                      const Divider(height: 1),
                      _buildSwitchTile(
                        context,
                        title: 'Receive Push Notifications',
                        value: _pushNotificationsEnabled,
                        onChanged: (value) =>
                            setState(() => _pushNotificationsEnabled = value),
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
                  onChanged: (value) =>
                      setState(() => _muteNotifications = value),
                ),
                const Divider(height: 1),
                _buildSwitchTile(
                  context,
                  title: _tr('notificationSettings', 'toggle_sound'),
                  value: _toggleSound,
                  onChanged: (value) => setState(() => _toggleSound = value),
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
                // TODO: implement navigation to in-app notifications if required
              },
            ),
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
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return SwitchListTile(
      title: Text(title, style: theme.textTheme.bodyLarge),
      activeThumbColor: colorScheme.primary,
      value: value,
      onChanged: onChanged,
    );
  }
}
