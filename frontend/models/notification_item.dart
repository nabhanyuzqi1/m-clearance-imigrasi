enum NotificationType { update, approved, revision }

class NotificationItem {
  final String title;
  final String body;
  final DateTime date;
  final NotificationType type;
  bool isRead;

  NotificationItem({
    required this.title,
    required this.body,
    required this.date,
    required this.type,
    this.isRead = false,
  });
}