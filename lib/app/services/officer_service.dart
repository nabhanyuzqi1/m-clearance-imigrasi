import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/officer_activity.dart';
import 'functions_service.dart';
import 'logging_service.dart';

class OfficerService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FunctionsService _functionsService = FunctionsService();

  // Get recent officer activities
  Stream<List<OfficerActivity>> getOfficerActivities({int limit = 10}) {
    final user = _auth.currentUser;
    if (user == null) {
      LoggingService().warning('No user is currently signed in.');
      return Stream.value([]);
    }

    final controller = StreamController<List<OfficerActivity>>.broadcast();
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? primarySub;
    Timer? fallbackRefresh;
    var lastEmitted = <OfficerActivity>[];
    var callableInFlight = false;

    Future<void> emit(List<OfficerActivity> activities) async {
      lastEmitted = activities;
      if (!controller.isClosed) {
        controller.add(activities.take(limit).toList());
      }
    }

    Future<void> emitFromCallable() async {
      if (callableInFlight) return;
      callableInFlight = true;
      try {
        final raw = await _functionsService.fetchOfficerActivities(
          limit: limit,
        );
        final activities = raw
            .map(
              (data) =>
                  OfficerActivity.fromMap((data['id'] as String?) ?? '', data),
            )
            .where((activity) => activity.id.isNotEmpty)
            .toList();
        await emit(activities);
      } catch (e) {
        LoggingService().warning('Callable fetchOfficerActivities failed', e);
        if (lastEmitted.isEmpty && !controller.isClosed) {
          controller.add(const []);
        }
      } finally {
        callableInFlight = false;
      }
    }

    controller.onListen = () {
      primarySub = _firestore
          .collection('officer_activities')
          .where('userId', isEqualTo: user.uid)
          .orderBy('date', descending: true)
          .limit(limit)
          .snapshots()
          .listen(
            (snapshot) async {
              final activities = snapshot.docs
                  .map(OfficerActivity.fromFirestore)
                  .toList();
              await emit(activities);
            },
            onError: (error, stack) async {
              await primarySub?.cancel();
              primarySub = null;
              if (error is FirebaseException &&
                  error.code == 'permission-denied') {
                LoggingService().warning(
                  'Primary officer activities stream denied. Falling back to callable.',
                  error,
                );
              } else {
                LoggingService().error(
                  'Error fetching officer activities (primary)',
                  error,
                );
              }
              await emitFromCallable();
              fallbackRefresh ??= Timer.periodic(
                const Duration(minutes: 2),
                (_) => emitFromCallable(),
              );
            },
          );

      // Kick off an initial callable fetch so the UI has data while waiting.
      emitFromCallable();
    };

    controller.onCancel = () async {
      await primarySub?.cancel();
      fallbackRefresh?.cancel();
      if (!controller.hasListener) {
        await controller.close();
      }
    };

    return controller.stream;
  }

  Future<void> logActivity({
    required String title,
    required String description,
    required String type,
    String? status,
    String? iconData,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      LoggingService().warning(
        'Attempted to log officer activity without an authenticated user.',
      );
      return;
    }

    try {
      await _functionsService.logOfficerActivity(
        title: title,
        description: description,
        type: type,
        status: status,
        iconData: iconData,
      );
      LoggingService().info(
        'Logged officer activity via callable: $title ($type)',
      );
      return;
    } on FirebaseFunctionsException catch (e) {
      LoggingService().warning(
        'Callable logOfficerActivity failed with ${e.code}. Falling back to direct write.',
        e,
      );
    } catch (e) {
      LoggingService().warning('Callable logOfficerActivity failed', e);
    }

    final fallbackData = {
      'userId': user.uid,
      'title': title,
      'description': description,
      'type': type,
      if (status != null) 'status': status,
      if (iconData != null) 'iconData': iconData,
      'date': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    };

    try {
      // Attempt to use a dedicated per-user activity log collection as a fallback.
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('activity_logs')
          .add(fallbackData);
      LoggingService().info(
        'Logged officer activity to fallback collection: $title ($type)',
      );
    } catch (firestoreError) {
      LoggingService().error(
        'Failed to log officer activity to fallback collection',
        firestoreError,
      );
    }
  }

  // Get officer statistics
  Future<Map<String, int>> getOfficerStats() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return {};

      final officerDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();
      final officerName = officerDoc.data()?['name'] as String?;
      final officerEmail = officerDoc.data()?['email'] as String? ?? user.email;

      if (officerName == null) return {};

      final stats = <String, int>{
        'applicationsReviewed': 0,
        'accountsVerified': 0,
        'reportsGenerated': 0,
      };

      // Count applications reviewed
      final applicationsQuery = await _firestore
          .collection('applications')
          .where('officerName', isEqualTo: officerName)
          .get();
      stats['applicationsReviewed'] = applicationsQuery.docs.length;

      // Count accounts verified
      final accountsQuery = await _firestore
          .collection('users')
          .where('decidedBy', isEqualTo: officerEmail)
          .get();
      stats['accountsVerified'] = accountsQuery.docs.length;

      // Count reports generated
      final reportsQuery = await _firestore
          .collection('reports')
          .where('createdBy', isEqualTo: user.uid)
          .get();
      stats['reportsGenerated'] = reportsQuery.docs.length;

      return stats;
    } catch (e) {
      LoggingService().error('Error getting officer stats', e);
      return {};
    }
  }
}

// Extension to capitalize strings
extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
