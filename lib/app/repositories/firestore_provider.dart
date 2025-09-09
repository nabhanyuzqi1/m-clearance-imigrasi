import 'package:cloud_firestore/cloud_firestore.dart';

/// Centralized access to the default Firestore instance.
class FirestoreProvider {
  static FirebaseFirestore get db => FirebaseFirestore.instance;
}
