import 'dart:async';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:m_clearance_imigrasi/app/models/user_model.dart';
import 'package:m_clearance_imigrasi/app/services/functions_service.dart';
import 'package:m_clearance_imigrasi/app/services/cache_manager.dart';
import 'package:m_clearance_imigrasi/app/services/network_utils.dart';
import 'package:m_clearance_imigrasi/app/services/logging_service.dart';

class AuthService {
  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  late final CacheManager _cacheManager;

  AuthService({
    FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance {
    _initializeCacheManager();
  }

  Future<void> _initializeCacheManager() async {
    _cacheManager = await CacheManager.getInstance();
  }

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  Future<UserModel?> signInWithEmailAndPassword(
      String email, String password) async {
    final startTime = DateTime.now();
    try {
      final UserCredential userCredential =
          await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final authTime = DateTime.now().difference(startTime);
      LoggingService().debug('Auth sign-in took ${authTime.inMilliseconds}ms');
      if (userCredential.user != null) {
        final userModel = await getUserData(userCredential.user!.uid);
        final totalTime = DateTime.now().difference(startTime);
        LoggingService().debug('Total sign-in process took ${totalTime.inMilliseconds}ms');
        return userModel;
      }
      return null;
    } on FirebaseAuthException catch (e) {
      LoggingService().error('Firebase Auth Exception: ${e.message}', e);
      return null;
    } catch (e) {
      LoggingService().error('An unexpected error occurred during sign-in', e);
      return null;
    }
  }

  Future<UserModel?> registerWithEmailAndPassword(String email, String password,
      String corporateName, String username, String nationality) async {
    try {
      final UserCredential userCredential =
          await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final User? user = userCredential.user;
      if (user != null) {
        final newUser = UserModel(
          uid: user.uid,
          email: email,
          corporateName: corporateName,
          username: username,
          nationality: nationality,
          role: 'user',
          status: 'pending_email_verification',
          isEmailVerified: false,
          hasUploadedDocuments: false,
          createdAt: Timestamp.now(),
          updatedAt: Timestamp.now(),
          documents: [],
        );

        await _firestore
            .collection('users')
            .doc(user.uid)
            .set(newUser.toFirestore());
        // Fire-and-forget email verification code issuance to avoid blocking registration
        FunctionsService().issueEmailVerificationCode().catchError((e) {
          LoggingService().warning('Failed issuing verification code', e);
          // Non-critical error, don't fail registration
        });

        return newUser;
      }
      return null;
    } on FirebaseAuthException catch (e) {
      LoggingService().error('Firebase Auth Exception during registration: ${e.message}', e);
      return null;
    } catch (e) {
      LoggingService().error('An unexpected error occurred during registration', e);
      return null;
    }
  }

  Future<UserModel?> getUserData(String uid) async {
    final startTime = DateTime.now();

    // Try to get from cache first
    final cachedData = _cacheManager.getCachedUserData();
    if (cachedData != null && cachedData['uid'] == uid) {
      try {
        final userModel = UserModel.fromJson(cachedData);
        final cacheTime = DateTime.now().difference(startTime);
        LoggingService().debug('Cache hit - getUserData took ${cacheTime.inMilliseconds}ms');
        return userModel;
      } catch (e) {
        LoggingService().warning('Cache data corrupted, fetching from server', e);
        await _cacheManager.clearUserDataCache();
      }
    }

    // Fetch from server with retry logic
    try {
      final userModel = await NetworkUtils.executeWithRetry(
        () async {
          final serverStart = DateTime.now();
          final DocumentSnapshot doc = await NetworkUtils.withTimeout(
            _firestore.collection('users').doc(uid).get(),
            const Duration(seconds: 10),
          );
          final serverTime = DateTime.now().difference(serverStart);
          LoggingService().debug('Server fetch took ${serverTime.inMilliseconds}ms');

          if (!doc.exists || doc.data() == null) {
            throw NetworkException('User document not found', isRetryable: false);
          }

          return UserModel.fromFirestore(doc);
        },
        shouldRetry: NetworkUtils.isRetryableError,
      );

      // Cache the result
      await _cacheManager.cacheUserData(userModel.toJson());

      final totalTime = DateTime.now().difference(startTime);
      LoggingService().debug('getUserData took ${totalTime.inMilliseconds}ms (with caching)');
      return userModel;
    } catch (e) {
      if (e is NetworkException) {
        LoggingService().error('Network error in getUserData: ${e.message}', e);
      } else {
        LoggingService().error('An unexpected error occurred in getUserData', e);
      }
      return null;
    }
  }
  Future<UserModel?> getUserByEmail(String email) async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      if (snapshot.docs.isNotEmpty) {
        return UserModel.fromFirestore(snapshot.docs.first);
      }
      return null;
    } catch (e) {
      LoggingService().error('An unexpected error occurred in getUserByEmail', e);
      return null;
    }
  }

  /// Uploads a document to Firebase Storage.
  ///
  /// Uses file bytes for upload, handled uniformly across platforms by file_picker.
  /// Generates unique filename using timestamp and UUID to prevent overwrites.
  Future<String?> uploadDocument(String uid, Uint8List fileBytes, String docName) async {
    try {
      // Generate unique filename to prevent overwrites
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileExtension = docName.split('.').last;
      final baseName = docName.split('.').first;
      final uniqueFileName = '${baseName}_${timestamp}_${uid.substring(0, 8)}.$fileExtension';

      final ref = _storage.ref().child('users/$uid/documents/$uniqueFileName');
      await ref.putData(fileBytes);

      final String downloadUrl = await ref.getDownloadURL();
      await _firestore.collection('users').doc(uid).update({
        'documents': FieldValue.arrayUnion([
          {
            'documentName': docName, // Keep original name for display
            'storagePath': downloadUrl,
            'uploadedAt': Timestamp.now(),
          }
        ]),
        'status': 'pending_approval',
        'hasUploadedDocuments': true,
        'updatedAt': Timestamp.now(),
      });
      return downloadUrl;
    } on FirebaseException catch (e) {
      LoggingService().error('Firebase Storage error during upload: ${e.message}', e);
      return null;
    } catch (e) {
      LoggingService().error('An unexpected error occurred during upload', e);
      return null;
    }
  }

  Future<void> sendVerificationEmail() async {
    final user = _firebaseAuth.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  Future<bool> isEmailVerified() async {
    final user = _firebaseAuth.currentUser;
    await user?.reload();
    return user?.emailVerified ?? false;
  }

  Future<void> reloadUser() async {
    await _firebaseAuth.currentUser?.reload();
  }

  /// Refresh FirebaseAuth user and reflect email verification into Firestore.
  /// If verified, sets isEmailVerified=true and transitions status from
  /// 'pending_email_verification' -> 'pending_documents' once. Idempotent.
  Future<UserModel?> updateEmailVerified() async {
    LoggingService().debug('updateEmailVerified called');
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      LoggingService().debug('updateEmailVerified: user is null');
      return null;
    }

    await user.reload();
    final refreshed = _firebaseAuth.currentUser;
    final verified = refreshed?.emailVerified ?? false;
    LoggingService().debug('updateEmailVerified: verified = $verified');
    if (!verified) {
      // No Firestore writes when not verified
      LoggingService().debug('updateEmailVerified: not verified, returning getUserData');
      return await getUserData(user.uid);
    }

    const int maxRetries = 3;
    int retryCount = 0;

    while (retryCount < maxRetries) {
      try {
        final docRef = _firestore.collection('users').doc(user.uid);
        final doc = await docRef.get();
        if (!doc.exists) {
          LoggingService().debug('updateEmailVerified: doc does not exist');
          return null;
        }

        final data = doc.data() as Map<String, dynamic>;
        final Map<String, dynamic> updates = {
          'isEmailVerified': true,
          'updatedAt': FieldValue.serverTimestamp(),
        };

        final currentStatus =
            (data['status'] as String?) ?? 'pending_email_verification';
        LoggingService().debug('updateEmailVerified: currentStatus = $currentStatus');
        if (currentStatus == 'pending_email_verification') {
          updates['status'] = 'pending_documents';
          LoggingService().debug('updateEmailVerified: updating status to pending_documents');
        }

        await docRef.update(updates);
        final result = await getUserData(user.uid);
        LoggingService().debug('updateEmailVerified: returning userModel with status ${result?.status}');
        return result;
      } catch (e) {
        retryCount++;
        if (retryCount >= maxRetries) {
          LoggingService().error('Failed to update email verification after $maxRetries attempts', e);
          return null;
        }
        // Wait before retrying (exponential backoff)
        await Future.delayed(Duration(seconds: retryCount));
      }
    }

    return null;
  }

  /// Guard to ensure the current user can upload documents.
  /// Requires FirebaseAuth.currentUser.emailVerified == true and
  /// Firestore user status == 'pending_documents'.
  Future<void> ensureCanUploadDocuments() async {
    LoggingService().debug('ensureCanUploadDocuments called');
    final user = _firebaseAuth.currentUser;
    LoggingService().debug('currentUser = $user');
    if (user == null) {
      LoggingService().error('ensureCanUploadDocuments: No authenticated user');
      throw StateError('No authenticated user.');
    }

    await user.reload();
    LoggingService().debug('after reload, emailVerified = ${user.emailVerified}');
    if (!(user.emailVerified)) {
      LoggingService().error('ensureCanUploadDocuments: Email is not verified');
      throw StateError('Email is not verified.');
    }

    final userModel = await getUserData(user.uid);
    LoggingService().debug('userModel = $userModel');
    if (userModel == null) {
      LoggingService().error('ensureCanUploadDocuments: User data not found');
      throw StateError('User data not found.');
    }
    LoggingService().debug('userModel.status = ${userModel.status}');
    if (userModel.status != 'pending_documents') {
      LoggingService().error('ensureCanUploadDocuments: Status not pending_documents, throwing');
      throw StateError(
          'User is not eligible to upload documents. Current status: ${userModel.status}.');
    }
    LoggingService().debug('ensureCanUploadDocuments: All checks passed');
  }

  /// Mark documents as uploaded and move user to 'pending_approval' if in
  /// 'pending_documents'. Accepts a list of storage paths or references.
  /// Idempotent: only adds document entries whose storagePath is not already present.
  Future<UserModel?> markDocumentsUploaded(
      {required List<String> storagePathsOrRefs}) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return null;

    try {
      final docRef = _firestore.collection('users').doc(user.uid);
      final snapshot = await docRef.get();
      if (!snapshot.exists) {
        return null;
      }

      final data = snapshot.data() as Map<String, dynamic>;

      // Collect existing storagePath values to avoid duplicates across calls
      final List existingDocs = (data['documents'] as List?) ?? const [];
      final Set<String> existingPaths = existingDocs
          .whereType<Map>()
          .map((m) => (m['storagePath'] as String?) ?? '')
          .where((s) => s.isNotEmpty)
          .toSet();

      // Build only new entries not already present by storagePath
      final List<Map<String, dynamic>> toAdd = [];
      for (final p in storagePathsOrRefs) {
        if (!existingPaths.contains(p)) {
          final parts = p.split('/');
          final name = parts.isNotEmpty ? parts.last : 'document';
          toAdd.add({
            'documentName': name,
            'storagePath': p,
            'uploadedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      final Map<String, dynamic> updates = {
        'hasUploadedDocuments': true,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (toAdd.isNotEmpty) {
        updates['documents'] = FieldValue.arrayUnion(toAdd);
      }

      // Transition status only from pending_documents -> pending_approval
      final currentStatus =
          (data['status'] as String?) ?? 'pending_email_verification';
      if (currentStatus == 'pending_documents') {
        updates['status'] = 'pending_approval';
      }

      await docRef.update(updates);
      return await getUserData(user.uid);
    } catch (e) {
      LoggingService().error('An unexpected error occurred in markDocumentsUploaded', e);
      return null;
    }
  }
 
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      LoggingService().error('Firebase Auth Exception during password reset: ${e.message}', e);
      rethrow;
    } catch (e) {
      LoggingService().error('An unexpected error occurred during password reset', e);
      rethrow;
    }
  }

 Future<void> updateUserEmail(String newEmail) async {
   final user = _firebaseAuth.currentUser;
   if (user != null && user.email != newEmail) {
     await user.verifyBeforeUpdateEmail(newEmail);
   }
 }
 
  Future<void> signOut() async {
    await _firebaseAuth.signOut();
    // Clear cache on sign out
    await _cacheManager.clearUserDataCache();
  }

  /// Clear user data cache (useful when user data is updated)
  Future<void> clearUserDataCache() async {
    await _cacheManager.clearUserDataCache();
  }

  /// Download file data from Firebase Storage using download URL or storage path
  Future<Uint8List?> downloadFileData(String filePathOrUrl) async {
    try {
      // Validate the input
      if (filePathOrUrl.isEmpty) {
        LoggingService().error('File path or URL is empty');
        return null;
      }

      final ref = filePathOrUrl.startsWith('https') ? _storage.refFromURL(filePathOrUrl) : _storage.ref().child(filePathOrUrl);
      final data = await ref.getData();

      if (data == null || data.isEmpty) {
        LoggingService().error('Downloaded file data is null or empty');
        return null;
      }

      return data;
    } catch (e) {
      LoggingService().error('Error downloading file data from $filePathOrUrl: $e');

      // Handle specific Firebase exceptions
      if (e.toString().contains('ClientException') || e.toString().contains('JavaScriptObject')) {
        LoggingService().error('ClientException detected - this may be a web-specific error with Firebase Storage');
      }

      return null;
    }
  }
}
