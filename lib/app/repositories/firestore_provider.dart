import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

/// Centralized access to the Firestore instance used across the app.
class FirestoreProvider {
  static FirebaseFirestore get db =>
      FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'm-clearance-imigrasi-db');
}

