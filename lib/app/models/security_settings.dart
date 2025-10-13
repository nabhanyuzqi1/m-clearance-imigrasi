import 'package:cloud_firestore/cloud_firestore.dart';

class SecuritySettings {
  const SecuritySettings({
    required this.twoFactorEnabled,
    required this.deviceApprovalRequired,
    required this.loginAlertsEnabled,
    required this.biometricLockEnabled,
    required this.rememberDeviceDays,
    this.recoveryEmail,
    this.lastUpdated,
  });

  final bool twoFactorEnabled;
  final bool deviceApprovalRequired;
  final bool loginAlertsEnabled;
  final bool biometricLockEnabled;
  final int rememberDeviceDays;
  final String? recoveryEmail;
  final DateTime? lastUpdated;

  factory SecuritySettings.defaults() {
    return const SecuritySettings(
      twoFactorEnabled: false,
      deviceApprovalRequired: false,
      loginAlertsEnabled: true,
      biometricLockEnabled: false,
      rememberDeviceDays: 30,
      recoveryEmail: null,
      lastUpdated: null,
    );
  }

  SecuritySettings copyWith({
    bool? twoFactorEnabled,
    bool? deviceApprovalRequired,
    bool? loginAlertsEnabled,
    bool? biometricLockEnabled,
    int? rememberDeviceDays,
    String? recoveryEmail,
    DateTime? lastUpdated,
  }) {
    return SecuritySettings(
      twoFactorEnabled: twoFactorEnabled ?? this.twoFactorEnabled,
      deviceApprovalRequired:
          deviceApprovalRequired ?? this.deviceApprovalRequired,
      loginAlertsEnabled: loginAlertsEnabled ?? this.loginAlertsEnabled,
      biometricLockEnabled: biometricLockEnabled ?? this.biometricLockEnabled,
      rememberDeviceDays: rememberDeviceDays ?? this.rememberDeviceDays,
      recoveryEmail: recoveryEmail ?? this.recoveryEmail,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  factory SecuritySettings.fromMap(Map<String, dynamic>? data) {
    if (data == null) return SecuritySettings.defaults();
    DateTime? parseTimestamp(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is int) {
        return DateTime.fromMillisecondsSinceEpoch(value);
      }
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    return SecuritySettings(
      twoFactorEnabled: data['twoFactorEnabled'] as bool? ?? false,
      deviceApprovalRequired: data['deviceApprovalRequired'] as bool? ?? false,
      loginAlertsEnabled: data['loginAlertsEnabled'] as bool? ?? true,
      biometricLockEnabled: data['biometricLockEnabled'] as bool? ?? false,
      rememberDeviceDays: data['rememberDeviceDays'] as int? ?? 30,
      recoveryEmail: data['recoveryEmail'] as String?,
      lastUpdated: parseTimestamp(data['lastUpdated']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'twoFactorEnabled': twoFactorEnabled,
      'deviceApprovalRequired': deviceApprovalRequired,
      'loginAlertsEnabled': loginAlertsEnabled,
      'biometricLockEnabled': biometricLockEnabled,
      'rememberDeviceDays': rememberDeviceDays,
      'recoveryEmail': recoveryEmail,
      'lastUpdated': FieldValue.serverTimestamp(),
    };
  }
}
