import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import '../models/account_session.dart';
import '../models/security_settings.dart';
import 'logging_service.dart';
import 'network_utils.dart';

class SecurityService {
  SecurityService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    FirebaseDatabase? database,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ??
            FirebaseFunctions.instanceFor(region: 'asia-southeast1'),
        _database = database ?? FirebaseDatabase.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  final FirebaseDatabase _database;

  CollectionReference<Map<String, dynamic>> _settingsCollection(String uid) {
    return _firestore.collection('users').doc(uid).collection('security');
  }

  DocumentReference<Map<String, dynamic>> _settingsDoc(String uid) {
    return _settingsCollection(uid).doc('settings');
  }

  CollectionReference<Map<String, dynamic>> _sessionsCollection(String uid) {
    return _firestore.collection('users').doc(uid).collection('sessions');
  }

  Future<SecuritySettings> fetchSettings() async {
    final user = _auth.currentUser;
    if (user == null) return SecuritySettings.defaults();

    try {
      final doc = await NetworkUtils.withTimeout(
        _settingsDoc(user.uid).get(),
        const Duration(seconds: 10),
      );
      final data = doc.data();
      return SecuritySettings.fromMap(data);
    } catch (error, stackTrace) {
      LoggingService().warning(
        '[SecurityService] Failed to fetch settings',
        error,
        stackTrace,
      );
      return SecuritySettings.defaults();
    }
  }

  Future<void> updateSettings(SecuritySettings settings) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await NetworkUtils.withTimeout(
        _settingsDoc(user.uid).set(settings.toMap(), SetOptions(merge: true)),
        const Duration(seconds: 10),
      );
    } catch (error, stackTrace) {
      LoggingService().error(
        '[SecurityService] Failed updating settings',
        error,
        stackTrace,
      );
      rethrow;
    }
  }

  Future<bool> isDeviceTrusted(String deviceId) async {
    final user = _auth.currentUser;
    if (user == null) return false;
    try {
      final doc = await NetworkUtils.withTimeout(
        _sessionsCollection(user.uid).doc(deviceId).get(),
        const Duration(seconds: 5),
      );
      if (!doc.exists) return false;
      final data = doc.data() ?? {};
      if (data['isRevoked'] == true) return false;
      final expiresAt = data['trustedUntil'];
      if (expiresAt is Timestamp) {
        return expiresAt.toDate().isAfter(DateTime.now());
      }
      if (expiresAt is int) {
        return DateTime.fromMillisecondsSinceEpoch(expiresAt)
            .isAfter(DateTime.now());
      }
      return true;
    } catch (error, stackTrace) {
      LoggingService().warning(
        '[SecurityService] Failed to resolve trusted device state',
        error,
        stackTrace,
      );
      return false;
    }
  }

  Stream<List<AccountSession>> streamSessions({bool includeRevoked = false}) {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();

    final query = _sessionsCollection(user.uid)
        .orderBy('isCurrent', descending: true)
        .orderBy('lastActive', descending: true)
        .limit(50);

    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map(AccountSession.fromDoc)
          .where((session) => includeRevoked ? true : session.isActive)
          .toList(growable: false);
    });
  }

  Future<void> revokeSession(String sessionId) async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      final docRef = _sessionsCollection(user.uid).doc(sessionId);
      await NetworkUtils.withTimeout(
        docRef.update({
          'isRevoked': true,
          'revokedAt': FieldValue.serverTimestamp(),
        }),
        const Duration(seconds: 10),
      );
    } catch (error, stackTrace) {
      LoggingService().error(
        '[SecurityService] Failed to revoke session $sessionId',
        error,
        stackTrace,
      );
      rethrow;
    }
  }

  Future<void> revokeAllOtherSessions() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      final query = await NetworkUtils.withTimeout(
        _sessionsCollection(user.uid)
            .where('isCurrent', isEqualTo: false)
            .where('isRevoked', isEqualTo: false)
            .get(),
        const Duration(seconds: 10),
      );

      final batch = _firestore.batch();
      for (final doc in query.docs) {
        batch.update(doc.reference, {
          'isRevoked': true,
          'revokedAt': FieldValue.serverTimestamp(),
        });
      }
      await NetworkUtils.withTimeout(
        batch.commit(),
        const Duration(seconds: 10),
      );
    } catch (error, stackTrace) {
      LoggingService().error(
        '[SecurityService] Failed to revoke other sessions',
        error,
        stackTrace,
      );
      rethrow;
    }
  }

  Future<TwoFactorChallenge?> initiateTwoFactorChallenge({
    required Map<String, dynamic> deviceMeta,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final callable = _functions.httpsCallable('security-initiateTwoFactor');
      final result = await callable.call<Map<String, dynamic>>({
        'device': deviceMeta,
      });
      final data = result.data;
      if (data.isEmpty) return null;
      return TwoFactorChallenge.fromMap(data);
    } catch (error, stackTrace) {
      LoggingService().error(
        '[SecurityService] Failed to initiate two-factor challenge',
        error,
        stackTrace,
      );
      rethrow;
    }
  }

  Future<TwoFactorVerificationResult> verifyTwoFactorCode({
    required String challengeId,
    required String code,
    required Map<String, dynamic> deviceMeta,
    required bool trustDevice,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('No authenticated user for 2FA verification');
    }
    try {
      final callable = _functions.httpsCallable('security-verifyTwoFactor');
      final result = await callable.call<Map<String, dynamic>>({
        'challengeId': challengeId,
        'code': code,
        'trustDevice': trustDevice,
        'device': deviceMeta,
      });
      return TwoFactorVerificationResult.fromMap(result.data);
    } catch (error, stackTrace) {
      LoggingService().warning(
        '[SecurityService] Two-factor verification failed',
        error,
        stackTrace,
      );
      rethrow;
    }
  }

  Future<void> logSuccessfulLogin({
    required Map<String, dynamic> deviceMeta,
    required bool trusted,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      final callable = _functions.httpsCallable('security-logLoginEvent');
      await callable.call<Map<String, dynamic>>({
        'device': deviceMeta,
        'trusted': trusted,
      });
    } catch (error, stackTrace) {
      LoggingService().warning(
        '[SecurityService] Failed to emit login alert',
        error,
        stackTrace,
      );
    }
  }

  Stream<String> supportEmailStream() {
    final ref = _database.ref('support/contactEmail');
    return ref.onValue.map((event) {
      final value = event.snapshot.value;
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
      return 'mclearanceisam@gmail.com';
    });
  }
}

class TwoFactorChallenge {
  const TwoFactorChallenge({
    required this.id,
    required this.deliveryTarget,
    required this.expiresAt,
  });

  final String id;
  final String deliveryTarget;
  final DateTime expiresAt;

  factory TwoFactorChallenge.fromMap(Map<String, dynamic> map) {
    DateTime parse(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is int) {
        return DateTime.fromMillisecondsSinceEpoch(value);
      }
      if (value is String) {
        return DateTime.tryParse(value) ?? DateTime.now().add(
            const Duration(minutes: 5));
      }
      return DateTime.now().add(const Duration(minutes: 5));
    }

    return TwoFactorChallenge(
      id: map['challengeId'] as String? ?? '',
      deliveryTarget: map['delivery']?['target'] as String? ?? '',
      expiresAt: parse(map['expiresAt']),
    );
  }
}

class TwoFactorVerificationResult {
  const TwoFactorVerificationResult({
    required this.success,
    required this.trustedUntil,
    required this.sessionId,
  });

  final bool success;
  final DateTime? trustedUntil;
  final String? sessionId;

  factory TwoFactorVerificationResult.fromMap(Map<String, dynamic> map) {
    DateTime? parse(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is int) {
        return DateTime.fromMillisecondsSinceEpoch(value);
      }
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    return TwoFactorVerificationResult(
      success: map['success'] as bool? ?? false,
      trustedUntil: parse(map['trustedUntil']),
      sessionId: map['sessionId'] as String?,
    );
  }
}
