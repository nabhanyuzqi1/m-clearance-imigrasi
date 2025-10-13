import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/clearance_application.dart';
import 'firestore_provider.dart';
import '../services/logging_service.dart';
import '../services/officer_service.dart';
import '../services/functions_service.dart';
import '../services/notification_service.dart';

class ApplicationRepository {
  final FirebaseFirestore _db;
  final FunctionsService _functionsService = FunctionsService();
  ApplicationRepository({FirebaseFirestore? db})
    : _db = db ?? FirestoreProvider.db;

  /// Streams applications filtered by type and status.
  /// type: 'arrival' | 'departure' (accepts legacy 'kedatangan' | 'keberangkatan')
  /// status: e.g., 'waiting'
  /// If [agentUid] provided, filter by agentUid for user-specific lists.
  Stream<List<ClearanceApplication>> streamApplications({
    required String type,
    String? agentUid,
    int? limit,
  }) {
    // Normalize legacy values to backend values
    final normalizedType = type == 'kedatangan'
        ? 'arrival'
        : type == 'keberangkatan'
        ? 'departure'
        : type;

    Query query = _db
        .collection('applications')
        .where('type', isEqualTo: normalizedType)
        .orderBy('updatedAt', descending: true);
    if (agentUid != null) {
      query = query.where('agentUid', isEqualTo: agentUid);
    }
    if (limit != null) query = query.limit(limit);

    return query.snapshots().map(
      (snap) => snap.docs.map((d) {
        return ClearanceApplication.fromFirestore(d);
      }).toList(),
    );
  }

  /// Create a new application (agent side). Returns created doc id.
  Future<String> createApplication({
    required String agentUid,
    required String agentName,
    required String type, // 'arrival' | 'departure'
    required String shipName,
    required String flag,
    String? location,
    String? lastPort,
    String? nextPort,
    String? eta,
    String? etd,
    int? wniCrew,
    int? wnaCrew,
  }) async {
    try {
      LoggingService().info(
        'Creating new application for ship: $shipName, type: $type',
      );
      final doc = await _db.collection('applications').add({
        'agentUid': agentUid,
        'agentName': agentName,
        'type': type,
        'status': 'waiting',
        'shipName': shipName,
        'flag': flag,
        if (location != null) 'location': location,
        if (lastPort != null) 'lastPort': lastPort,
        if (nextPort != null) 'nextPort': nextPort,
        if (eta != null) 'arrivalDate': eta,
        if (etd != null) 'departureDate': etd,
        if (wniCrew != null) 'wniCrew': wniCrew,
        if (wnaCrew != null) 'wnaCrew': wnaCrew,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      LoggingService().info(
        'Application created successfully with ID: ${doc.id}',
      );
      return doc.id;
    } catch (e) {
      LoggingService().error(
        'Error creating application for ship: $shipName',
        e,
      );
      rethrow;
    }
  }

  /// Agent update for non-final fields while status is waiting/revision.
  Future<void> updateApplicationByAgent({
    required String appId,
    String? shipName,
    String? flag,
    String? location,
    String? lastPort,
    String? nextPort,
    String? eta,
    String? etd,
  }) async {
    try {
      LoggingService().info('Updating application $appId by agent');
      final updates = <String, dynamic>{
        if (shipName != null) 'shipName': shipName,
        if (flag != null) 'flag': flag,
        if (location != null) 'location': location,
        if (lastPort != null) 'lastPort': lastPort,
        if (nextPort != null) 'nextPort': nextPort,
        if (eta != null) 'arrivalDate': eta,
        if (etd != null) 'departureDate': etd,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      await _db.collection('applications').doc(appId).update(updates);
      LoggingService().info('Application $appId updated successfully');
    } catch (e) {
      LoggingService().error('Error updating application $appId', e);
      rethrow;
    }
  }

  /// Officer/Admin decision on an application.
  Future<void> officerDecide({
    required String appId,
    required String decision, // 'approved' | 'declined' | 'revision'
    String? note,
    String? officerName,
    String? officerCorporateName,
  }) async {
    final notificationService = NotificationService();
    final officerService = OfficerService();

    try {
      LoggingService().info(
        'Officer decision on application $appId: $decision',
      );
      final docRef = _db.collection('applications').doc(appId);
      ClearanceApplication? applicationModel;
      String shipName = '';

      try {
        final snapshot = await docRef.get();
        if (snapshot.exists) {
          applicationModel = ClearanceApplication.fromFirestore(snapshot);
          shipName = applicationModel.shipName;
        } else {
          LoggingService().warning(
            'Attempted to decide on missing application document: $appId',
          );
        }
      } catch (e, stackTrace) {
        LoggingService().error(
          'Failed to fetch application $appId before updating decision',
          e,
          stackTrace,
        );
      }

      final updates = <String, dynamic>{
        'status': decision,
        if (note != null) 'notes': note,
        if (officerName != null) 'officerName': officerName,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (decision != 'approved') {
        updates.addAll({
          'clearanceResultFile': FieldValue.delete(),
          'clearanceResultGeneratedAt': FieldValue.delete(),
          'clearanceResultSignedBy': FieldValue.delete(),
          'clearanceResultSignedByCorporate': FieldValue.delete(),
          'clearanceResultSentAt': FieldValue.delete(),
          'clearanceCode': FieldValue.delete(),
        });
      }

      await docRef.update(updates);
      LoggingService().info('Application $appId status updated to $decision');

      final statusEnum = decision == 'approved'
          ? ApplicationStatus.approved
          : decision == 'revision'
          ? ApplicationStatus.revision
          : ApplicationStatus.declined;

      await notificationService.createApplicationNotification(
        appId,
        shipName,
        statusEnum,
      );

      final description = shipName.isNotEmpty
          ? 'Application for $shipName marked as ${decision.toUpperCase()}.'
          : 'Application status updated to ${decision.toUpperCase()}.';
      await officerService.logActivity(
        title: shipName.isNotEmpty ? shipName : 'Application Update',
        description: description,
        type: 'applicationReview',
        status: decision,
        iconData: 'document',
      );
    } catch (e) {
      LoggingService().error('Error updating application $appId status', e);
      rethrow;
    }
  }

  Future<ClearanceApplication> sendClearanceCertificate({
    required String appId,
    required String officerName,
    required String officerCorporateName,
  }) async {
    final officerService = OfficerService();

    try {
      LoggingService().info('Initiating sendClearanceCertificate for $appId');
      final callableResult = await _functionsService.sendClearanceCertificate(
        applicationId: appId,
        officerName: officerName,
        officerCorporateName: officerCorporateName,
      );

      final docRef = _db.collection('applications').doc(appId);

      // Add retry logic with small delay to handle Firestore eventual consistency
      ClearanceApplication? updatedApplication;
      for (int attempt = 0; attempt < 3; attempt++) {
        await Future.delayed(
          Duration(milliseconds: attempt * 500),
        ); // Progressive delay
        final snapshot = await docRef.get();
        if (snapshot.exists) {
          updatedApplication = ClearanceApplication.fromFirestore(snapshot);
          break;
        }
        LoggingService().info(
          'Application $appId not found on attempt ${attempt + 1}, retrying...',
        );
      }

      if (updatedApplication == null) {
        LoggingService().warning(
          'Application $appId missing after sendClearanceCertificate callable after retries.',
        );
        throw StateError('Application not found after certificate generation');
      }

      // If a short link was generated, update the application document with it
      if (callableResult['shortLink'] != null) {
        try {
          await docRef.update({
            'shortLink': callableResult['shortLink'],
            'updatedAt': FieldValue.serverTimestamp(),
          });
          LoggingService().info('Short link saved to application $appId');

          // Refresh the application data to include the short link
          final refreshedSnapshot = await docRef.get();
          if (refreshedSnapshot.exists) {
            updatedApplication = ClearanceApplication.fromFirestore(
              refreshedSnapshot,
            );
          }
        } catch (shortLinkError) {
          LoggingService().warning(
            'Failed to save short link to application',
            shortLinkError,
          );
          // Don't fail the whole operation if short link saving fails
        }
      }

      final shipName = updatedApplication?.shipName ?? '';
      final activityDescription = shipName.isNotEmpty
          ? 'eClearance sent for $shipName ($appId)'
          : 'eClearance sent for application $appId';

      await officerService.logActivity(
        title: shipName.isNotEmpty ? shipName : 'eClearance',
        description: activityDescription,
        type: 'applicationReview',
        status: 'clearanceSent',
        iconData: 'qr_code',
      );

      LoggingService().info(
        'sendClearanceCertificate callable completed for $appId',
        callableResult,
      );

      return updatedApplication!;
    } catch (e, stackTrace) {
      LoggingService().error(
        'Failed to send eClearance for $appId via callable',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  Future<void> updateApplication(
    String appId,
    ClearanceApplication application,
  ) async {
    try {
      LoggingService().info('Updating application $appId');
      await _db
          .collection('applications')
          .doc(appId)
          .update(application.toFirestore());
      LoggingService().info('Application $appId updated successfully');
    } catch (e) {
      LoggingService().error('Error updating application $appId', e);
      rethrow;
    }
  }
}
