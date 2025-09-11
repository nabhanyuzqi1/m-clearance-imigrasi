import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/clearance_application.dart';
import 'firestore_provider.dart';
import '../services/logging_service.dart';

class ApplicationRepository {
  final FirebaseFirestore _db;
  ApplicationRepository({FirebaseFirestore? db}) : _db = db ?? FirestoreProvider.db;

  /// Streams applications filtered by type and status.
  /// type: 'arrival' | 'departure' (accepts legacy 'kedatangan' | 'keberangkatan')
  /// status: e.g., 'waiting'
  /// If [agentUid] provided, filter by agentUid for user-specific lists.
  Stream<List<ClearanceApplication>> streamApplications({
    required String type,
    required String status,
    String? agentUid,
    int? limit,
  }) {
    // Normalize legacy values to backend values
    final normalizedType = type == 'kedatangan'
        ? 'arrival'
        : type == 'keberangkatan'
            ? 'departure'
            : type;

    Query query = _db.collection('applications')
        .where('type', isEqualTo: normalizedType)
        .where('status', isEqualTo: status)
        .orderBy('updatedAt', descending: true);
    if (agentUid != null) {
      query = query.where('agentUid', isEqualTo: agentUid);
    }
    if (limit != null) query = query.limit(limit);

    return query.snapshots().map((snap) => snap.docs.map((d) {
          return ClearanceApplication.fromFirestore(d);
        }).toList());
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
      LoggingService().info('Creating new application for ship: $shipName, type: $type');
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
      LoggingService().info('Application created successfully with ID: ${doc.id}');
      return doc.id;
    } catch (e) {
      LoggingService().error('Error creating application for ship: $shipName', e);
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
  }) async {
    try {
      LoggingService().info('Officer decision on application $appId: $decision');
      final updates = <String, dynamic>{
        'status': decision,
        if (note != null) 'notes': note,
        if (officerName != null) 'officerName': officerName,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      await _db.collection('applications').doc(appId).update(updates);
      LoggingService().info('Application $appId status updated to $decision');
    } catch (e) {
      LoggingService().error('Error updating application $appId status', e);
      rethrow;
    }
  }
}
