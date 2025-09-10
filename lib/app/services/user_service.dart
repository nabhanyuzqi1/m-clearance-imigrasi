import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/clearance_application.dart';
import '../models/user_account.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Static profile image paths (for local storage)
  static String? currentProfileImagePath;
  static String? officerProfileImagePath;

  // Get current user account
  Future<UserAccount?> getCurrentUserAccount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        try {
          final userAccount = UserAccount.fromFirestore(doc);
          return userAccount;
        } catch (e) {
          print('Error creating UserAccount from Firestore: $e');
          return null;
        }
      }
      return null;
    } catch (e) {
      print('Error getting current user account: $e');
      return null;
    }
  }

  // Update user profile
  Future<bool> updateUserProfile(String name, String email) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('DEBUG: No authenticated user found');
        return false;
      }

      final updateData = {
        'name': name,
        'email': email,
        'updatedAt': Timestamp.now(),
      };

      print('DEBUG: Attempting to update user profile with data: $updateData');
      print('DEBUG: User UID: ${user.uid}');

      await _firestore.collection('users').doc(user.uid).update(updateData);

      print('DEBUG: User profile updated successfully');
      return true;
    } catch (e) {
      print('DEBUG: Error updating user profile: $e');
      print('DEBUG: Error type: ${e.runtimeType}');
      if (e is FirebaseException) {
        final firebaseError = e as FirebaseException;
        print('DEBUG: Firebase error code: ${firebaseError.code}');
        print('DEBUG: Firebase error message: ${firebaseError.message}');
      }
      return false;
    }
  }

  // Submit clearance application
  Future<String?> submitClearanceApplication(ClearanceApplication application) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('DEBUG: No authenticated user found for application submission');
        return null;
      }

      final firestoreData = application.toFirestore();
      final dataToSend = {
        ...firestoreData,
        'agentUid': user.uid,
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      };

      print('DEBUG: Submitting application with data: $dataToSend');
      print('DEBUG: User UID: ${user.uid}');
      print('DEBUG: Application status: ${application.status} (index: ${application.status.index})');
      print('DEBUG: Application type: ${application.type} (index: ${application.type.index})');
      print('DEBUG: Firestore data from toFirestore(): $firestoreData');

      final docRef = await _firestore.collection('applications').add(dataToSend);

      print('DEBUG: Application submitted successfully with ID: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      print('DEBUG: Error submitting clearance application: $e');
      print('DEBUG: Error type: ${e.runtimeType}');
      if (e is FirebaseException) {
        final firebaseError = e as FirebaseException;
        print('DEBUG: Firebase error code: ${firebaseError.code}');
        print('DEBUG: Firebase error message: ${firebaseError.message}');
      }
      return null;
    }
  }

  // Get user's applications
  Stream<List<ClearanceApplication>> getUserApplications() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _firestore
        .collection('applications')
        .where('agentUid', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => ClearanceApplication.fromFirestore(doc)).toList());
  }

  // Get application by ID
  Future<ClearanceApplication?> getApplicationById(String applicationId) async {
    try {
      final doc = await _firestore.collection('applications').doc(applicationId).get();
      if (doc.exists) {
        return ClearanceApplication.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error getting application: $e');
      return null;
    }
  }

  // Update application
  Future<bool> updateApplication(String applicationId, ClearanceApplication application) async {
    try {
      await _firestore.collection('applications').doc(applicationId).update({
        ...application.toFirestore(),
        'updatedAt': Timestamp.now(),
      });
      return true;
    } catch (e) {
      print('Error updating application: $e');
      return false;
    }
  }

  // Delete application
  Future<bool> deleteApplication(String applicationId) async {
    try {
      await _firestore.collection('applications').doc(applicationId).delete();
      return true;
    } catch (e) {
      print('Error deleting application: $e');
      return false;
    }
  }

  // Get application statistics
  Future<Map<String, int>> getApplicationStats() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return {};

      final snapshot = await _firestore
          .collection('applications')
          .where('agentUid', isEqualTo: user.uid)
          .get();

      final stats = <String, int>{
        'total': 0,
        'waiting': 0,
        'approved': 0,
        'revision': 0,
        'declined': 0,
      };

      for (final doc in snapshot.docs) {
        final app = ClearanceApplication.fromFirestore(doc);
        stats['total'] = (stats['total'] ?? 0) + 1;

        switch (app.status) {
          case ApplicationStatus.waiting:
            stats['waiting'] = (stats['waiting'] ?? 0) + 1;
            break;
          case ApplicationStatus.approved:
            stats['approved'] = (stats['approved'] ?? 0) + 1;
            break;
          case ApplicationStatus.revision:
            stats['revision'] = (stats['revision'] ?? 0) + 1;
            break;
          case ApplicationStatus.declined:
            stats['declined'] = (stats['declined'] ?? 0) + 1;
            break;
        }
      }

      return stats;
    } catch (e) {
      print('Error getting application stats: $e');
      return {};
    }
  }
}