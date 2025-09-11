import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/clearance_application.dart';
import '../models/user_account.dart';
import 'cache_manager.dart';
import 'network_utils.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  CacheManager? _cacheManager;

  // Static profile image paths (for local storage)
  static String? currentProfileImagePath;
  static String? officerProfileImagePath;

  UserService();

  Future<CacheManager> _getCacheManager() async {
    _cacheManager ??= await CacheManager.getInstance();
    return _cacheManager!;
  }

  // Get current user account
  Future<UserAccount?> getCurrentUserAccount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final cacheManager = await _getCacheManager();

      // Try to get from cache first
      final cachedData = cacheManager.getCachedUserData();
      if (cachedData != null && cachedData['uid'] == user.uid) {
        try {
          final userAccount = UserAccount.fromJson(cachedData);
          print('DEBUG: Cache hit for user account');
          return userAccount;
        } catch (e) {
          print('DEBUG: Cache data corrupted for user account, fetching from server');
          await cacheManager.clearUserDataCache();
        }
      }

      // Fetch from server with retry logic
      try {
        final userAccount = await NetworkUtils.executeWithRetry(
          () async {
            final doc = await NetworkUtils.withTimeout(
              _firestore.collection('users').doc(user.uid).get(),
              const Duration(seconds: 10),
            );

            if (!doc.exists) {
              throw NetworkException('User account not found', isRetryable: false);
            }

            return UserAccount.fromFirestore(doc);
          },
          shouldRetry: NetworkUtils.isRetryableError,
        );

        // Cache the result
        await cacheManager.cacheUserData(userAccount.toJson());

        print('DEBUG: User account fetched from server and cached');
        return userAccount;
      } catch (e) {
        if (e is NetworkException) {
          print('Network error in getCurrentUserAccount: ${e.message}');
        } else {
          print('Error creating UserAccount from Firestore: $e');
        }
        return null;
      }
    } catch (e) {
      print('Error getting current user account: $e');
      return null;
    }
  }

  // Update user profile
  Future<bool> updateUserProfile(String name, String email, {String? imagePath}) async {
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

      if (email != user.email) {
        updateData['isEmailVerified'] = false;
      }

      // Handle image upload if provided
      if (imagePath != null && imagePath.isNotEmpty) {
        try {
          final imageUrl = await _uploadProfileImage(user.uid, imagePath);
          if (imageUrl != null) {
            updateData['profileImageUrl'] = imageUrl;
            print('DEBUG: Profile image uploaded successfully: $imageUrl');
          }
        } catch (uploadError) {
          print('DEBUG: Error uploading profile image: $uploadError');
          // Continue with profile update even if image upload fails
        }
      }

      print('DEBUG: Attempting to update user profile with data: $updateData');
      print('DEBUG: User UID: ${user.uid}');

      await _firestore.collection('users').doc(user.uid).update(updateData);

      if (email != user.email) {
        await user.verifyBeforeUpdateEmail(email);
      }

      // Clear cache since user data has been updated
      final cacheManager = await _getCacheManager();
      await cacheManager.clearUserDataCache();

      print('DEBUG: User profile updated successfully');
      return true;
    } catch (e) {
      print('DEBUG: Error updating user profile: $e');
      print('DEBUG: Error type: ${e.runtimeType}');
      if (e is FirebaseException) {
        print('DEBUG: Firebase error code: ${e.code}');
        print('DEBUG: Firebase error message: ${e.message}');
      }
      return false;
    }
  }

  // Upload profile image to Firebase Storage
  Future<String?> _uploadProfileImage(String userId, String imagePath) async {
    try {
      final file = File(imagePath);
      if (!await file.exists()) {
        print('DEBUG: Image file does not exist: $imagePath');
        return null;
      }

      final storageRef = FirebaseStorage.instance.ref();
      final profileImageRef = storageRef.child('users/$userId/profile_image.jpg');

      print('DEBUG: Uploading image to Firebase Storage: users/$userId/profile_image.jpg');

      final uploadTask = profileImageRef.putFile(file);
      final snapshot = await uploadTask.whenComplete(() => null);

      if (snapshot.state == TaskState.success) {
        final downloadUrl = await profileImageRef.getDownloadURL();
        print('DEBUG: Image uploaded successfully, download URL: $downloadUrl');
        return downloadUrl;
      } else {
        print('DEBUG: Image upload failed with state: ${snapshot.state}');
        return null;
      }
    } catch (e) {
      print('DEBUG: Error uploading profile image: $e');
      return null;
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
      print('DEBUG: Application status: ${application.status} (name: ${application.status.name})');
      print('DEBUG: Application type: ${application.type} (string: ${application.type == ApplicationType.kedatangan ? 'arrival' : 'departure'})');
      print('DEBUG: Firestore data from toFirestore(): $firestoreData');

      final docRef = await _firestore.collection('applications').add(dataToSend);

      print('DEBUG: Application submitted successfully with ID: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      print('DEBUG: Error submitting clearance application: $e');
      print('DEBUG: Error type: ${e.runtimeType}');
      if (e is FirebaseException) {
        print('DEBUG: Firebase error code: ${e.code}');
        print('DEBUG: Firebase error message: ${e.message}');
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