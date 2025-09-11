import 'package:flutter/material.dart';
import '../../../localization/app_strings.dart';
import '../../widgets/custom_app_bar.dart';

class NotificationSettingsScreen extends StatefulWidget {
  final String initialLanguage;

  const NotificationSettingsScreen({super.key, this.initialLanguage = 'EN'});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  late String _selectedLanguage;
  bool _muteNotifications = false;
  bool _toggleSound = true;

  @override
  void initState() {
    super.initState();
    _selectedLanguage = widget.initialLanguage;
  }

  String _tr(String screenKey, String stringKey) => AppStrings.tr(
        context: context,
        screenKey: screenKey,
        stringKey: stringKey,
        langCode: _selectedLanguage,
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        titleText: _tr('notificationSettings', 'title'),
      ),
      body: ListView(
        children: [
          SwitchListTile(
            title: Text(_tr('notificationSettings', 'mute_notifications')),
            value: _muteNotifications,
            onChanged: (bool value) {
              setState(() {
                _muteNotifications = value;
              });
            },
          ),
          SwitchListTile(
            title: Text(_tr('notificationSettings', 'toggle_sound')),
            value: _toggleSound,
            onChanged: (bool value) {
              setState(() {
                _toggleSound = value;
              });
            },
          ),
          ListTile(
            title: Text(_tr('notificationSettings', 'view_notifications')),
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