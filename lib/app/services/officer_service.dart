import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/officer_activity.dart';
import 'logging_service.dart';

class OfficerService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get recent officer activities
  Stream<List<OfficerActivity>> getOfficerActivities({int limit = 10}) {
    final user = _auth.currentUser;
    if (user == null) {
      LoggingService().warning('No user is currently signed in.');
      return Stream.value([]);
    }

    return _firestore
        .collection('officer_activities')
        .where('userId', isEqualTo: user.uid)
        .orderBy('date', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) {
            LoggingService().info('No activities found for officer ${user.uid}');
            return <OfficerActivity>[];
          }
          return snapshot.docs.map((doc) => OfficerActivity.fromFirestore(doc)).toList();
        })
        .handleError((error) {
          LoggingService().error('Error fetching officer activities', error);
          return <OfficerActivity>[];
        });
  }

  // Get officer statistics
  Future<Map<String, int>> getOfficerStats() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return {};

      final officerDoc = await _firestore.collection('users').doc(user.uid).get();
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