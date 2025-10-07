import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationPreferences {
  const NotificationPreferences({
    required this.pushEnabled,
    required this.muteAll,
    required this.playSound,
    required this.badgeEnabled,
    this.updatedAt,
  });

  final bool pushEnabled;
  final bool muteAll;
  final bool playSound;
  final bool badgeEnabled;
  final DateTime? updatedAt;

  NotificationPreferences copyWith({
    bool? pushEnabled,
    bool? muteAll,
    bool? playSound,
    bool? badgeEnabled,
    DateTime? updatedAt,
  }) {
    return NotificationPreferences(
      pushEnabled: pushEnabled ?? this.pushEnabled,
      muteAll: muteAll ?? this.muteAll,
      playSound: playSound ?? this.playSound,
      badgeEnabled: badgeEnabled ?? this.badgeEnabled,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'pushEnabled': pushEnabled,
      'muteAll': muteAll,
      'playSound': playSound,
      'badgeEnabled': badgeEnabled,
      'updatedAt': updatedAt != null
          ? Timestamp.fromDate(updatedAt!)
          : FieldValue.serverTimestamp(),
    };
  }

  factory NotificationPreferences.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return const NotificationPreferences(
        pushEnabled: true,
        muteAll: false,
        playSound: true,
        badgeEnabled: true,
      );
    }

    Timestamp? updatedTs;
    final updated = map['updatedAt'];
    if (updated is Timestamp) {
      updatedTs = updated;
    }

    return NotificationPreferences(
      pushEnabled: map['pushEnabled'] is bool ? map['pushEnabled'] as bool : true,
      muteAll: map['muteAll'] is bool ? map['muteAll'] as bool : false,
      playSound: map['playSound'] is bool ? map['playSound'] as bool : true,
      badgeEnabled: map['badgeEnabled'] is bool ? map['badgeEnabled'] as bool : true,
      updatedAt: updatedTs?.toDate(),
    );
  }
}
