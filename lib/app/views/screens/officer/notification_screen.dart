import 'package:flutter/material.dart';
import '../../../localization/app_localizations.dart';
import '../../../services/logging_service.dart';
import '../../../config/theme.dart';
import '../../../models/notification_item.dart';
import '../../../services/notification_service.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/bouncing_dots_loader.dart';

class OfficerNotificationScreen extends StatefulWidget {
  final String initialLanguage;

  const OfficerNotificationScreen({super.key, this.initialLanguage = 'EN'});

  @override
  State<OfficerNotificationScreen> createState() =>
      _OfficerNotificationScreenState();
}

class _OfficerNotificationScreenState extends State<OfficerNotificationScreen> {
  final NotificationService _notificationService = NotificationService();

  String _tr(String key) =>
      AppLocalizations.of(context).get('officerNotifications.$key');

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

  Future<void> _markAllAsRead() async {
    try {
      final success = await _notificationService.markAllAsRead();
      if (success && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_tr('mark_all_read_message'))));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_tr('mark_read_failed'))));
      }
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      final success = await _notificationService.markAsRead(notificationId);
      if (!success && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_tr('mark_single_read_failed'))));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_tr('mark_single_read_failed'))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    LoggingService().debug(
      'Building OfficerNotificationScreen with language: ${widget.initialLanguage}',
    );
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: CustomAppBar(
        titleText: _tr('title'),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _markAllAsRead,
            icon: Icon(Icons.done_all, color: colorScheme.primary),
            tooltip: _tr('mark_all_read_tooltip'),
          ),
        ],
      ),
      body: StreamBuilder<List<NotificationItem>>(
        stream: _notificationService.getUserNotifications(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: BouncingDotsLoader());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error, size: 64, color: colorScheme.error),
                  SizedBox(height: AppTheme.spacing16),
                  Text(
                    _tr('load_error'),
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    snapshot.error.toString(),
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: colorScheme.onSurface,
                    ),
                  ),
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
                      color: colorScheme.primary.withAlpha(25),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.notifications_none,
                      size: 64,
                      color: colorScheme.primary.withAlpha(51),
                    ),
                  ),
                  SizedBox(height: AppTheme.spacing24),
                  Text(
                    _tr('empty_title'),
                    style: TextStyle(
                      fontSize: AppTheme.fontSizeH5,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Poppins',
                      color: colorScheme.onSurface,
                    ),
                  ),
                  SizedBox(height: AppTheme.spacing8),
                  Text(
                    _tr('empty_subtitle'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
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
                  color: colorScheme.error,
                  child: Icon(Icons.delete, color: colorScheme.onError),
                ),
                onDismissed: (direction) async {
                  await _notificationService.deleteNotification(
                    notification.id,
                  );
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
                              color: _getNotificationTypeColor(
                                colorScheme,
                                notification.type,
                              ).withAlpha(25),
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusSmall,
                              ),
                            ),
                            child: Icon(
                              _getNotificationIcon(notification.type),
                              color: _getNotificationTypeColor(
                                colorScheme,
                                notification.type,
                              ),
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
                                          color: colorScheme.onSurface,
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
                                          color: colorScheme.primary,
                                          borderRadius: BorderRadius.circular(
                                            AppTheme.radiusMedium,
                                          ),
                                        ),
                                        child: Text(
                                          _tr('unread'),
                                          style: TextStyle(
                                            color: colorScheme.onPrimary,
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
                                    color: colorScheme.onSurfaceVariant,
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
                                        color: colorScheme.onSurfaceVariant,
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
                                        color: _getNotificationTypeColor(
                                          colorScheme,
                                          notification.type,
                                        ).withAlpha(25),
                                        borderRadius: BorderRadius.circular(
                                          AppTheme.radiusSmall,
                                        ),
                                      ),
                                      child: Text(
                                        _getNotificationTypeText(
                                          notification.type,
                                        ),
                                        style: TextStyle(
                                          color: _getNotificationTypeColor(
                                            colorScheme,
                                            notification.type,
                                          ),
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

  Color _getNotificationTypeColor(
    ColorScheme colorScheme,
    NotificationType type,
  ) {
    switch (type) {
      case NotificationType.update:
        return colorScheme.primary;
      case NotificationType.approved:
        return colorScheme.tertiary;
      case NotificationType.revision:
        return colorScheme.secondary;
    }
  }

  String _getNotificationTypeText(NotificationType type) {
    switch (type) {
      case NotificationType.update:
        return _tr('system_notice_title');
      case NotificationType.approved:
        return _tr('new_agent_reg_title');
      case NotificationType.revision:
        return _tr('submission_needs_review_title');
    }
  }
}
