import 'package:flutter/material.dart';
import '../../models/notification_item.dart';
import '../../services/notification_service.dart';

class NotificationScreen extends StatefulWidget {
  final String initialLanguage;
  const NotificationScreen({super.key, this.initialLanguage = 'EN'});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final List<NotificationItem> _notifications = NotificationService.notifications;
  late String _selectedLanguage;

  final Map<String, Map<String, String>> _translations = {
    'EN': {
      'title': 'Notification',
      'empty_title': 'Nothing here. For now.',
      'empty_subtitle': "This is where you'll find what is\ngoing on",
    },
    'ID': {
      'title': 'Notifikasi',
      'empty_title': 'Tidak ada apa-apa. Untuk saat ini.',
      'empty_subtitle': 'Di sinilah Anda akan menemukan apa\nyang sedang terjadi',
    }
  };

  String _tr(String key) => _translations[_selectedLanguage]![key] ?? key;
  
  @override
  void initState() {
    super.initState();
    _selectedLanguage = widget.initialLanguage;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          NotificationService.markAllAsRead();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(_tr('title')),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
      ),
      body: _notifications.isEmpty
          ? _buildEmptyState()
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
              itemCount: _notifications.length,
              separatorBuilder: (context, index) => const Divider(height: 1, color: Colors.transparent),
              itemBuilder: (context, index) {
                final notification = _notifications[index];
                return _buildNotificationItem(notification);
              },
            ),
    );
  }

  Widget _buildNotificationItem(NotificationItem notification) {
    IconData iconData;
    Color iconColor;

    switch (notification.type) {
      case NotificationType.approved:
        iconData = Icons.check_circle_outline;
        iconColor = Colors.green;
        break;
      case NotificationType.revision:
        iconData = Icons.error_outline;
        iconColor = Colors.orange;
        break;
      case NotificationType.update:
        iconData = Icons.info_outline;
        iconColor = Colors.blue;
        break;
        // ignore: dead_code
        iconData = Icons.notifications_none;
        iconColor = Colors.grey;
    }

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: iconColor.withAlpha(25),
        child: Icon(iconData, color: iconColor),
      ),
      title: Text(
        notification.title,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        notification.body,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: () {},
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.shade200.withAlpha(128),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.notifications_off_outlined, size: 60, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 24),
          Text(
            _tr('empty_title'),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 8),
          Text(
            _tr('empty_subtitle'),
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
          ),
        ],
      ),
    );
  }
}
