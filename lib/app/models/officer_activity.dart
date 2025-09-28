import 'package:cloud_firestore/cloud_firestore.dart';

enum OfficerActivityType {
  applicationReview,
  accountVerification,
  reportGenerated,
}

class OfficerActivity {
  final String id;
  final OfficerActivityType type;
  final String title;
  final String description;
  final DateTime date;
  final String? status;
  final String? iconData;

  OfficerActivity({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.date,
    this.status,
    this.iconData,
  });

  factory OfficerActivity.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return OfficerActivity(
      id: doc.id,
      type: _parseActivityType(data['type']),
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: data['status'],
      iconData: data['iconData'],
    );
  }

  factory OfficerActivity.fromMap(String id, Map<String, dynamic> data) {
    DateTime resolveDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is num) {
        return DateTime.fromMillisecondsSinceEpoch(value.toInt());
      }
      if (value is String) {
        return DateTime.tryParse(value) ?? DateTime.now();
      }
      return DateTime.now();
    }

    return OfficerActivity(
      id: id,
      type: _parseActivityType(data['type'] as String?),
      title: (data['title'] as String?) ?? '',
      description: (data['description'] as String?) ?? '',
      date: resolveDate(data['date']),
      status: data['status'] as String?,
      iconData: data['iconData'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type.toString().split('.').last,
      'title': title,
      'description': description,
      'date': Timestamp.fromDate(date),
      'status': status,
      'iconData': iconData,
    };
  }

  static OfficerActivityType _parseActivityType(String? type) {
    switch (type) {
      case 'applicationReview':
        return OfficerActivityType.applicationReview;
      case 'accountVerification':
        return OfficerActivityType.accountVerification;
      case 'reportGenerated':
        return OfficerActivityType.reportGenerated;
      default:
        // Handle unknown type, maybe return a default or throw an error
        return OfficerActivityType.applicationReview;
    }
  }

  OfficerActivity copyWith({
    String? id,
    OfficerActivityType? type,
    String? title,
    String? description,
    DateTime? date,
    String? status,
    String? iconData,
  }) {
    return OfficerActivity(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      description: description ?? this.description,
      date: date ?? this.date,
      status: status ?? this.status,
      iconData: iconData ?? this.iconData,
    );
  }

  @override
  String toString() {
    return 'OfficerActivity(id: $id, type: $type, title: $title, date: $date, status: $status)';
  }
}
