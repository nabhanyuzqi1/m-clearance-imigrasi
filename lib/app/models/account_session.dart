import 'package:cloud_firestore/cloud_firestore.dart';

class AccountSession {
  const AccountSession({
    required this.id,
    required this.deviceName,
    required this.platform,
    required this.appVersion,
    required this.ipAddress,
    required this.location,
    required this.lastActive,
    required this.isCurrent,
    required this.isRevoked,
    required this.trustedUntil,
    required this.trusted,
    this.createdAt,
  });

  final String id;
  final String deviceName;
  final String platform;
  final String appVersion;
  final String ipAddress;
  final String location;
  final DateTime lastActive;
  final bool isCurrent;
  final bool isRevoked;
  final DateTime? trustedUntil;
  final bool trusted;
  final DateTime? createdAt;

  factory AccountSession.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    DateTime parseTimestamp(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is int) {
        return DateTime.fromMillisecondsSinceEpoch(value);
      }
      if (value is String) {
        return DateTime.tryParse(value) ??
            DateTime.fromMillisecondsSinceEpoch(0);
      }
      return DateTime.fromMillisecondsSinceEpoch(0);
    }

    return AccountSession(
      id: doc.id,
      deviceName: (data['deviceName'] as String?)?.trim().isNotEmpty == true
          ? data['deviceName'] as String
          : 'Unknown Device',
      platform: (data['platform'] as String?) ?? 'Unknown',
      appVersion: (data['appVersion'] as String?) ?? '—',
      ipAddress: (data['ipAddress'] as String?) ?? '—',
      location: (data['location'] as String?) ?? '—',
      lastActive: parseTimestamp(data['lastActive']),
      isCurrent: data['isCurrent'] as bool? ?? false,
      isRevoked: data['isRevoked'] as bool? ?? false,
      trustedUntil: data['trustedUntil'] != null
          ? parseTimestamp(data['trustedUntil'])
          : null,
      trusted: data['trusted'] as bool? ?? false,
      createdAt: data['createdAt'] != null
          ? parseTimestamp(data['createdAt'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'deviceName': deviceName,
      'platform': platform,
      'appVersion': appVersion,
      'ipAddress': ipAddress,
      'location': location,
      'lastActive': Timestamp.fromDate(lastActive),
      'isCurrent': isCurrent,
      'isRevoked': isRevoked,
      'trustedUntil': trustedUntil != null
          ? Timestamp.fromDate(trustedUntil!)
          : null,
      'trusted': trusted,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
    };
  }

  bool get isActive {
    if (isRevoked) return false;
    if (trustedUntil != null) {
      return trustedUntil!.isAfter(DateTime.now());
    }
    return true;
  }
}
