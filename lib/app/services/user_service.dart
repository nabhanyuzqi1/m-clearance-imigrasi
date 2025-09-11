import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/clearance_application.dart';
import '../models/user_account.dart';
import 'cache_manager.dart';
import 'network_utils.dart';
import 'logging_service.dart';

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
          LoggingService().debug('Cache hit for user account');
          return userAccount;
        } catch (e) {
          LoggingService().warning('Cache data corrupted for user account, fetching from server', e);
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

        LoggingService().debug('User account fetched from server and cached');
        return userAccount;
      } catch (e) {
        if (e is NetworkException) {
          LoggingService().error('Network error in getCurrentUserAccount: ${e.message}', e);
        } else {
          LoggingService().error('Error creating UserAccount from Firestore', e);
        }
        return null;
      }
    } catch (e) {
      LoggingService().error('Error getting current user account', e);
      return null;
    }
  }

  // Update user profile
  Future<bool> updateUserProfile(String name, String email, {String? imagePath}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        LoggingService().error('No authenticated user found');
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
            LoggingService().info('Profile image uploaded successfully: $imageUrl');
          }
        } catch (uploadError) {
          LoggingService().warning('Error uploading profile image', uploadError);
          // Continue with profile update even if image upload fails
        }
      }

      LoggingService().debug('Attempting to update user profile with data: $updateData');
      LoggingService().debug('User UID: ${user.uid}');

      await _firestore.collection('users').doc(user.uid).update(updateData);

      if (email != user.email) {
        await user.verifyBeforeUpdateEmail(email);
      }

      // Clear cache since user data has been updated
      final cacheManager = await _getCacheManager();
      await cacheManager.clearUserDataCache();

      LoggingService().info('User profile updated successfully');
      return true;
    } catch (e) {
      LoggingService().error('Error updating user profile', e);
      LoggingService().debug('Error type: ${e.runtimeType}');
      if (e is FirebaseException) {
        LoggingService().debug('Firebase error code: ${e.code}');
        LoggingService().debug('Firebase error message: ${e.message}');
      }
      return false;
    }
  }

  // Upload profile image to Firebase Storage
  Future<String?> _uploadProfileImage(String userId, String imagePath) async {
    try {
      final file = File(imagePath);
      if (!await file.exists()) {
        LoggingService().error('Image file does not exist: $imagePath');
        return null;
      }

      final storageRef = FirebaseStorage.instance.ref();
      final profileImageRef = storageRef.child('users/$userId/profile_image.jpg');

      LoggingService().debug('Uploading image to Firebase Storage: users/$userId/profile_image.jpg');

      final uploadTask = profileImageRef.putFile(file);
      final snapshot = await uploadTask.whenComplete(() => null);

      if (snapshot.state == TaskState.success) {
        final downloadUrl = await profileImageRef.getDownloadURL();
        LoggingService().info('Image uploaded successfully, download URL: $downloadUrl');
        return downloadUrl;
      } else {
        LoggingService().error('Image upload failed with state: ${snapshot.state}');
        return null;
      }
    } catch (e) {
      LoggingService().error('Error uploading profile image', e);
      return null;
    }
  }

  // Submit clearance application
  Future<String?> submitClearanceApplication(ClearanceApplication application) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        LoggingService().error('No authenticated user found for application submission');
        return null;
      }

      final firestoreData = application.toFirestore();
      final dataToSend = {
        ...firestoreData,
        'agentUid': user.uid,
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      };

      LoggingService().debug('Submitting application with data: $dataToSend');
      LoggingService().debug('User UID: ${user.uid}');
      LoggingService().debug('Application status: ${application.status} (name: ${application.status.name})');
      LoggingService().debug('Application type: ${application.type} (string: ${application.type == ApplicationType.kedatangan ? 'arrival' : 'departure'})');
      LoggingService().debug('Firestore data from toFirestore(): $firestoreData');

      final docRef = await _firestore.collection('applications').add(dataToSend);

      LoggingService().info('Application submitted successfully with ID: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      LoggingService().error('Error submitting clearance application', e);
      LoggingService().debug('Error type: ${e.runtimeType}');
      if (e is FirebaseException) {
        LoggingService().debug('Firebase error code: ${e.code}');
        LoggingService().debug('Firebase error message: ${e.message}');
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
      LoggingService().error('Error getting application', e);
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
      LoggingService().error('Error updating application', e);
      return false;
    }
  }

  // Delete application
  Future<bool> deleteApplication(String applicationId) async {
    try {
      await _firestore.collection('applications').doc(applicationId).delete();
      return true;
    } catch (e) {
      LoggingService().error('Error deleting application', e);
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
      LoggingService().error('Error getting application stats', e);
      return {};
    }
  }
}