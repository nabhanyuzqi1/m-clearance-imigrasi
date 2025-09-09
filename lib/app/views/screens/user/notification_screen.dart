import 'package:flutter/material.dart';
import '../../../models/notification_item.dart';
import '../../../services/notification_service.dart';

class NotificationScreen extends StatefulWidget {
  final String initialLanguage;

  const NotificationScreen({
    super.key,
    required this.initialLanguage,
  });

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final NotificationService _notificationService = NotificationService();
  String _selectedLanguage = 'EN';

  final Map<String, Map<String, String>> _translations = {
    'EN': {
      'notifications': 'Notifications',
      'no_notifications': 'No notifications yet',
      'no_notifications_desc': 'You will receive notifications about your applications here',
      'mark_all_read': 'Mark All as Read',
      'unread': 'Unread',
      'read': 'Read',
      'update': 'Update',
      'approved': 'Approved',
      'revision': 'Revision',
      'today': 'Today',
      'yesterday': 'Yesterday',
      'days_ago': 'days ago',
    },
    'ID': {
      'notifications': 'Notifikasi',
      'no_notifications': 'Belum ada notifikasi',
      'no_notifications_desc': 'Anda akan menerima notifikasi tentang permohonan Anda di sini',
      'mark_all_read': 'Tandai Semua Dibaca',
      'unread': 'Belum Dibaca',
      'read': 'Dibaca',
      'update': 'Update',
      'approved': 'Disetujui',
      'revision': 'Revisi',
      'today': 'Hari ini',
      'yesterday': 'Kemarin',
      'days_ago': 'hari yang lalu',
    }
  };

  String _tr(String key) => _translations[_selectedLanguage]![key] ?? key;

  @override
  void initState() {
    super.initState();
    _selectedLanguage = widget.initialLanguage;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return _tr('today');
    } else if (difference.inDays == 1) {
      return _tr('yesterday');
    } else {
      return '${difference.inDays} ${_tr('days_ago')}';
    }
  }

  String _getNotificationTypeText(NotificationType type) {
    switch (type) {
      case NotificationType.update:
        return _tr('update');
      case NotificationType.approved:
        return _tr('approved');
      case NotificationType.revision:
        return _tr('revision');
    }
  }

  Color _getNotificationTypeColor(NotificationType type) {
    switch (type) {
      case NotificationType.update:
        return Colors.blue;
      case NotificationType.approved:
        return Colors.green;
      case NotificationType.revision:
        return Colors.orange;
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      final success = await _notificationService.markAllAsRead();
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('All notifications marked as read')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to mark notifications as read')),
        );
      }
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      final success = await _notificationService.markAsRead(notificationId);
      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to mark notification as read')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to mark notification as read')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(_tr('notifications')),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _markAllAsRead,
            child: Text(
              _tr('mark_all_read'),
              style: const TextStyle(color: Colors.blue),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<NotificationItem>>(
        stream: _notificationService.getUserNotifications(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error loading notifications'),
                  Text(snapshot.error.toString()),
                ],
              ),
            );
          }

          final notifications = snapshot.data ?? [];

          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.notifications_none,
                      size: 64,
                      color: Colors.blue.shade200,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _tr('no_notifications'),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _tr('no_notifications_desc'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return Dismissible(
                key: Key(notification.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  color: Colors.red,
                  child: const Icon(
                    Icons.delete,
                    color: Colors.white,
                  ),
                ),
                onDismissed: (direction) async {
                  await _notificationService.deleteNotification(notification.id);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Notification deleted')),
                    );
                  }
                },
                child: Card(
                  elevation: notification.isRead ? 1 : 3,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: InkWell(
                    onTap: () {
                      if (!notification.isRead) {
                        _markAsRead(notification.id);
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Notification Type Icon
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _getNotificationTypeColor(notification.type).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              _getNotificationIcon(notification.type),
                              color: _getNotificationTypeColor(notification.type),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),

                          // Notification Content
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Title and Status
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        notification.title,
                                        style: TextStyle(
                                          fontWeight: notification.isRead
                                              ? FontWeight.normal
                                              : FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                    if (!notification.isRead)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.blue,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          _tr('unread'),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),

                                // Body
                                Text(
                                  notification.body,
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 8),

                                // Date and Type
                                Row(
                                  children: [
                                    Text(
                                      _formatDate(notification.date),
                                      style: TextStyle(
                                        color: Colors.grey.shade500,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _getNotificationTypeColor(notification.type).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        _getNotificationTypeText(notification.type),
                                        style: TextStyle(
                                          color: _getNotificationTypeColor(notification.type),
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  IconData _getNotificationIcon(NotificationType type) {
    switch (type) {
      case NotificationType.update:
        return Icons.info;
      case NotificationType.approved:
        return Icons.check_circle;
      case NotificationType.revision:
        return Icons.edit;
    }
  }
}