import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:m_clearance_imigrasi/app/models/user_model.dart';
import 'package:m_clearance_imigrasi/app/services/local_storage_service.dart';
import 'package:m_clearance_imigrasi/app/services/functions_service.dart';

class AuthService {
  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  AuthService({
    FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'm-clearance-imigrasi-db'),
        _storage = storage ?? FirebaseStorage.instanceFor(bucket: 'm-clearance-imigrasi.firebasestorage.app') {
    // Enable offline persistence for Firestore
    _firestore.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  }

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  Future<UserModel?> signInWithEmailAndPassword(
      String email, String password) async {
    try {
      final UserCredential userCredential =
          await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (userCredential.user != null) {
        final userModel = await getUserData(userCredential.user!.uid);
        if (userModel != null) {
          // Cache user data for offline access
          await LocalStorageService.cacheUserData(userModel);
          await LocalStorageService.cacheAuthState(true, userId: userModel.uid);
        }
        return userModel;
      }
      return null;
    } on FirebaseAuthException catch (e) {
      print('Firebase Auth Exception: ${e.message}');
      return null;
    } catch (e) {
      print('An unexpected error occurred: $e');
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
        // Switch to code-based verification: issue a 4-digit code via Functions
        try {
          await FunctionsService().issueEmailVerificationCode();
        } catch (e) {
          print('Failed issuing verification code: $e');
        }

        // Cache the new user data
        await LocalStorageService.cacheUserData(newUser);
        await LocalStorageService.cacheAuthState(true, userId: newUser.uid);

        return newUser;
      }
      return null;
    } on FirebaseAuthException catch (e) {
      print('Firebase Auth Exception: ${e.message}');
      return null;
    } catch (e) {
      print('An unexpected error occurred during registration: $e');
      return null;
    }
  }

  Future<UserModel?> getUserData(String uid) async {
    try {
      final DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(uid)
          .get()
          .timeout(const Duration(seconds: 10));

      if (!doc.exists || doc.data() == null) {
        return null;
      }

      return UserModel.fromFirestore(doc);
    } on TimeoutException catch (e) {
      print('Timeout getting user data: $e');
      return null;
    } catch (e) {
      print('An unexpected error occurred: $e');
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
      print('An unexpected error occurred: $e');
      return null;
    }
  }

  Future<String?> uploadDocument(String uid, File file, String docName) async {
    try {
      final ref = _storage.ref().child('users/$uid/documents/$docName');
      await ref.putFile(file);
      final String downloadUrl = await ref.getDownloadURL();
      await _firestore.collection('users').doc(uid).update({
        'documents': FieldValue.arrayUnion([
          {
            'documentName': docName,
            'storagePath': downloadUrl,
            'uploadedAt': Timestamp.now(),
          }
        ]),
        'status': 'pending_approval',
        'hasUploadedDocuments': true,
        'updatedAt': Timestamp.now(),
      });
      return downloadUrl;
    } catch (e) {
      print('An unexpected error occurred: $e');
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
    final user = _firebaseAuth.currentUser;
    if (user == null) return null;

    await user.reload();
    final refreshed = _firebaseAuth.currentUser;
    final verified = refreshed?.emailVerified ?? false;
    if (!verified) {
      // No Firestore writes when not verified
      return await getUserData(user.uid);
    }

    const int maxRetries = 3;
    int retryCount = 0;

    while (retryCount < maxRetries) {
      try {
        final docRef = _firestore.collection('users').doc(user.uid);
        final doc = await docRef.get();
        if (!doc.exists) {
          return null;
        }

        final data = doc.data() as Map<String, dynamic>;
        final Map<String, dynamic> updates = {
          'isEmailVerified': true,
          'updatedAt': FieldValue.serverTimestamp(),
        };

        final currentStatus =
            (data['status'] as String?) ?? 'pending_email_verification';
        if (currentStatus == 'pending_email_verification') {
          updates['status'] = 'pending_documents';
        }

        await docRef.update(updates);
        return await getUserData(user.uid);
      } catch (e) {
        retryCount++;
        if (retryCount >= maxRetries) {
          print('Failed to update email verification after $maxRetries attempts: $e');
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
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw StateError('No authenticated user.');
    }

    await user.reload();
    if (!(user.emailVerified)) {
      throw StateError('Email is not verified.');
    }

    final userModel = await getUserData(user.uid);
    if (userModel == null) {
      throw StateError('User data not found.');
    }
    if (userModel.status != 'pending_documents') {
      throw StateError(
          'User is not eligible to upload documents. Current status: ${userModel.status}.');
    }
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
      print('An unexpected error occurred: $e');
      return null;
    }
  }
 
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      print('Firebase Auth Exception: ${e.message}');
      rethrow;
    } catch (e) {
      print('An unexpected error occurred: $e');
      rethrow;
    }
  }
 
  Future<void> signOut() async {
    await _firebaseAuth.signOut();
    // Clear all cached data on sign out
    await LocalStorageService.clearAll();
  }
}
