import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:m_clearance_imigrasi/app/models/user_model.dart';

class AuthService {
  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  AuthService({
    FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

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
        return await getUserData(userCredential.user!.uid);
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
        await user.sendEmailVerification();
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
      final DocumentSnapshot doc =
          await _firestore.collection('users').doc(uid).get();
      return UserModel.fromFirestore(doc);
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
  }
}