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
  final Map<String, dynamic> metadata;

  NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.date,
    required this.type,
    required this.userId,
    this.isRead = false,
    Map<String, dynamic>? metadata,
  }) : metadata = metadata != null ? Map<String, dynamic>.unmodifiable(metadata) : const {};

  factory NotificationItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    NotificationType type;
    final rawType = data['type'];
    if (rawType is int && rawType >= 0 && rawType < NotificationType.values.length) {
      type = NotificationType.values[rawType];
    } else if (rawType is String) {
      switch (rawType.toLowerCase()) {
        case 'approved':
          type = NotificationType.approved;
          break;
        case 'revision':
          type = NotificationType.revision;
          break;
        default:
          type = NotificationType.update;
      }
    } else {
      type = NotificationType.update;
    }

    final timestamp =
        (data['date'] as Timestamp?) ?? (data['createdAt'] as Timestamp?) ?? Timestamp.now();
    final title = data['title'] ?? data['message'] ?? '';
    final body = data['body'] ?? data['message'] ?? '';
    final userId = data['userId'] ?? '';
    final isRead = data['isRead'] ?? false;
    const knownKeys = {
      'title',
      'body',
      'date',
      'createdAt',
      'timestamp',
      'type',
      'userId',
      'isRead',
    };
    final extra = <String, dynamic>{};
    data.forEach((key, value) {
      if (!knownKeys.contains(key)) {
        extra[key] = value is Timestamp ? value.toDate() : value;
      }
    });

    return NotificationItem(
      id: doc.id,
      title: title,
      body: body,
      date: timestamp.toDate(),
      type: type,
      userId: userId,
      isRead: isRead,
      metadata: extra,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'body': body,
      'date': Timestamp.fromDate(date),
      'createdAt': Timestamp.fromDate(date),
      'type': type.index,
      'userId': userId,
      'isRead': isRead,
      ...metadata,
    };
  }

  NotificationItem copyWith({
    bool? isRead,
    Map<String, dynamic>? metadata,
  }) {
    return NotificationItem(
      id: id,
      title: title,
      body: body,
      date: date,
      type: type,
      userId: userId,
      isRead: isRead ?? this.isRead,
      metadata: metadata ?? this.metadata,
    );
  }
}
