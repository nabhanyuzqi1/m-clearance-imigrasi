import 'package:flutter/material.dart';
import '../../../config/theme.dart';
import '../../../localization/app_strings.dart';
import '../../../models/notification_item.dart';
import '../../../services/notification_service.dart';

class NotificationScreen extends StatefulWidget {
  final String initialLanguage;
  const NotificationScreen({super.key, required this.initialLanguage});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final NotificationService _notificationService = NotificationService();
  String _tr(String key) => AppStrings.tr(
        context: context,
        screenKey: 'notifications',
        stringKey: key,
        langCode: widget.initialLanguage,
      );

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
        return AppTheme.primaryColor;
      case NotificationType.approved:
        return AppTheme.successColor;
      case NotificationType.revision:
        return AppTheme.warningColor;
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      final success = await _notificationService.markAllAsRead();
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_tr('mark_all_read_success'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_tr('mark_read_failed'))),
        );
      }
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      final success = await _notificationService.markAsRead(notificationId);
      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_tr('mark_single_read_failed'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_tr('mark_single_read_failed'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(_tr('notifications'), style: TextStyle(fontFamily: 'Poppins')),
        backgroundColor: AppTheme.surfaceColor,
        foregroundColor: AppTheme.onSurface,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _markAllAsRead,
            icon: Icon(Icons.done_all, color: AppTheme.primaryColor),
            tooltip: _tr('mark_all_read'),
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
                  Icon(Icons.error, size: 64, color: AppTheme.errorColor),
                  SizedBox(height: AppTheme.spacing16),
                  Text(_tr('load_error'), style: TextStyle(fontFamily: 'Poppins', color: AppTheme.onSurface)),
                  Text(snapshot.error.toString(), style: TextStyle(fontFamily: 'Poppins', color: AppTheme.onSurface)),
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
                    padding: EdgeInsets.all(AppTheme.spacing24),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withAlpha(25),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.notifications_none,
                      size: 64,
                      color: AppTheme.primaryColor.withAlpha(51),
                    ),
                  ),
                  SizedBox(height: AppTheme.spacing24),
                  Text(
                    _tr('no_notifications'),
                    style: TextStyle(
                      fontSize: AppTheme.fontSizeH5,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Poppins',
                      color: AppTheme.onSurface,
                    ),
                  ),
                  SizedBox(height: AppTheme.spacing8),
                  Text(
                    _tr('no_notifications_desc'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.subtitleColor,
                      fontSize: AppTheme.fontSizeBody1,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: EdgeInsets.all(AppTheme.spacing16),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return Dismissible(
                key: Key(notification.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: EdgeInsets.only(right: AppTheme.spacing20),
                  color: AppTheme.errorColor,
                  child: Icon(
                    Icons.delete,
                    color: AppTheme.whiteColor,
                  ),
                ),
                onDismissed: (direction) async {
                  await _notificationService.deleteNotification(notification.id);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(_tr('delete_success'))),
                    );
                  }
                },
                child: Card(
                  elevation: notification.isRead ? 1 : 3,
                  margin: EdgeInsets.only(bottom: AppTheme.spacing12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                  child: InkWell(
                    onTap: () {
                      if (!notification.isRead) {
                        _markAsRead(notification.id);
                      }
                    },
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    child: Padding(
                      padding: EdgeInsets.all(AppTheme.spacing16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Notification Type Icon
                          Container(
                            padding: EdgeInsets.all(AppTheme.spacing8),
                            decoration: BoxDecoration(
                              color: _getNotificationTypeColor(notification.type).withAlpha(25),
                              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                            ),
                            child: Icon(
                              _getNotificationIcon(notification.type),
                              color: _getNotificationTypeColor(notification.type),
                              size: 24,
                            ),
                          ),
                          SizedBox(width: AppTheme.spacing16),

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
                                          fontSize: AppTheme.fontSizeBody1,
                                          fontFamily: 'Poppins',
                                          color: AppTheme.onSurface,
                                        ),
                                      ),
                                    ),
                                    if (!notification.isRead)
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: AppTheme.spacing8,
                                          vertical: AppTheme.spacing4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primaryColor,
                                          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                                        ),
                                        child: Text(
                                          _tr('unread'),
                                          style: TextStyle(
                                            color: AppTheme.whiteColor,
                                            fontSize: AppTheme.fontSizeCaption,
                                            fontWeight: FontWeight.bold,
                                            fontFamily: 'Poppins',
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                SizedBox(height: AppTheme.spacing4),

                                // Body
                                Text(
                                  notification.body,
                                  style: TextStyle(
                                    color: AppTheme.subtitleColor,
                                    fontSize: AppTheme.fontSizeBody2,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                                SizedBox(height: AppTheme.spacing8),

                                // Date and Type
                                Row(
                                  children: [
                                    Text(
                                      _formatDate(notification.date),
                                      style: TextStyle(
                                        color: AppTheme.greyShade500,
                                        fontSize: AppTheme.fontSizeCaption,
                                        fontFamily: 'Poppins',
                                      ),
                                    ),
                                    SizedBox(width: AppTheme.spacing12),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: AppTheme.spacing8,
                                        vertical: AppTheme.spacing4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _getNotificationTypeColor(notification.type).withAlpha(25),
                                        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                                      ),
                                      child: Text(
                                        _getNotificationTypeText(notification.type),
                                        style: TextStyle(
                                          color: _getNotificationTypeColor(notification.type),
                                          fontSize: AppTheme.fontSizeCaption,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'Poppins',
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