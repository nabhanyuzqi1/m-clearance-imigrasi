import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import 'firestore_provider.dart';

class UserRepository {
  final FirebaseFirestore _db;
  UserRepository({FirebaseFirestore? db}) : _db = db ?? FirestoreProvider.db;

  /// Streams users with status == 'pending_approval'.
  Stream<List<UserModel>> streamPendingApprovals({int? limit}) {
    Query query = _db.collection('users').where('status', isEqualTo: 'pending_approval');
    if (limit != null) query = query.limit(limit);
    return query.snapshots().map((snap) => snap.docs.map((d) => UserModel.fromFirestore(d)).toList());
  }
}

