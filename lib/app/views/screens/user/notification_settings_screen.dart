import 'package:flutter/material.dart';
import '../../../config/theme.dart';
import '../../../localization/app_strings.dart';
import '../../../services/logging_service.dart';
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

  String _tr(String screenKey, String stringKey) => AppStrings.tr(
        context: context,
        screenKey: screenKey,
        stringKey: stringKey,
        langCode: widget.initialLanguage,
      );

  @override
  Widget build(BuildContext context) {
    LoggingService().debug('Building NotificationSettingsScreen with language: ${widget.initialLanguage}');
    return Scaffold(
      appBar: CustomAppBar(
        titleText: _tr('notificationSettings', 'title'),
      ),
      body: ListView(
        children: [
          SwitchListTile(
            title: Text(_tr('notificationSettings', 'mute_notifications'), style: TextStyle(fontFamily: 'Poppins', color: AppTheme.onSurface)),
            value: _muteNotifications,
            onChanged: (bool value) {
              setState(() {
                _muteNotifications = value;
              });
            },
          ),
          SwitchListTile(
            title: Text(_tr('notificationSettings', 'toggle_sound'), style: TextStyle(fontFamily: 'Poppins', color: AppTheme.onSurface)),
            value: _toggleSound,
            onChanged: (bool value) {
              setState(() {
                _toggleSound = value;
              });
            },
          ),
          ListTile(
            title: Text(_tr('notificationSettings', 'view_notifications'), style: TextStyle(fontFamily: 'Poppins', color: AppTheme.onSurface)),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              // Navigate to notification screen
            },
          ),
        ],
      ),
    );
  }
}