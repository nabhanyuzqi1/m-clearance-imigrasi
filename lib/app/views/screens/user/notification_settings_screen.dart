import 'package:flutter/material.dart';
import '../../../config/theme.dart';
import '../../../localization/app_localizations.dart';
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

  String _tr(String screenKey, String stringKey) => AppLocalizations.of(context).get('$screenKey.$stringKey');

  @override
  Widget build(BuildContext context) {
    LoggingService().debug('Building NotificationSettingsScreen with language: ${widget.initialLanguage}');
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = screenWidth * 0.06; // 6% of screen width
    final maxWidth = screenWidth > 600 ? 600.0 : double.infinity; // Constrain width on tablets

    return Scaffold(
      appBar: CustomAppBar(
        titleText: _tr('notificationSettings', 'title'),
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: ListView(
              children: [
                SwitchListTile(
                  title: Text(
                    _tr('notificationSettings', 'mute_notifications'),
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: AppTheme.onSurface,
                      fontSize: AppTheme.responsiveFontSize(context, mobile: AppTheme.fontSizeBody1, tablet: AppTheme.fontSizeH6, desktop: AppTheme.fontSizeH6),
                    ),
                  ),
                  value: _muteNotifications,
                  onChanged: (bool value) {
                    setState(() {
                      _muteNotifications = value;
                    });
                  },
                ),
                SwitchListTile(
                  title: Text(
                    _tr('notificationSettings', 'toggle_sound'),
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: AppTheme.onSurface,
                      fontSize: AppTheme.responsiveFontSize(context, mobile: AppTheme.fontSizeBody1, tablet: AppTheme.fontSizeH6, desktop: AppTheme.fontSizeH6),
                    ),
                  ),
                  value: _toggleSound,
                  onChanged: (bool value) {
                    setState(() {
                      _toggleSound = value;
                    });
                  },
                ),
                ListTile(
                  title: Text(
                    _tr('notificationSettings', 'view_notifications'),
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: AppTheme.onSurface,
                      fontSize: AppTheme.responsiveFontSize(context, mobile: AppTheme.fontSizeBody1, tablet: AppTheme.fontSizeH6, desktop: AppTheme.fontSizeH6),
                    ),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    // Navigate to notification screen
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}