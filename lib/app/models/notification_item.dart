import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationType { update, approved, revision }

class NotificationItem {
  final String id;
  final String title;
  final String body;
  final DateTime date;
  final NotificationType type;
  final String userId;
  bool isRead;

  NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.date,
    required this.type,
    required this.userId,
    this.isRead = false,
  });

  factory NotificationItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return NotificationItem(
      id: doc.id,
      title: data['title'] ?? '',
      body: data['body'] ?? '',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      type: NotificationType.values[data['type'] ?? 0],
      userId: data['userId'] ?? '',
      isRead: data['isRead'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'body': body,
      'date': Timestamp.fromDate(date),
      'type': type.index,
      'userId': userId,
      'isRead': isRead,
    };
  }

  NotificationItem copyWith({
    bool? isRead,
  }) {
    return NotificationItem(
      id: id,
      title: title,
      body: body,
      date: date,
      type: type,
      userId: userId,
      isRead: isRead ?? this.isRead,
    );
  }
}
