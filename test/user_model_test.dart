import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:m_clearance_imigrasi/app/models/user_model.dart';

// Reuse the generated Mockito mocks (for DocumentSnapshot)
import 'auth_service_test.mocks.dart';

void main() {
  group('UserModel', () {
    MockDocumentSnapshot<Map<String, dynamic>> snapshotWith(
      String id,
      Map<String, dynamic> data,
    ) {
      final snap = MockDocumentSnapshot<Map<String, dynamic>>();
      when(snap.exists).thenReturn(true);
      when(snap.id).thenReturn(id);
      when(snap.data()).thenReturn(data);
      return snap;
    }

    test('fromFirestore/toFirestore round-trip retains fields', () {
      final createdAt = Timestamp.fromMillisecondsSinceEpoch(1000);
      final updatedAt = Timestamp.fromMillisecondsSinceEpoch(2000);
      final uploadedAt = Timestamp.fromMillisecondsSinceEpoch(1500);

      final original = UserModel(
        uid: 'uid-1',
        email: 'user@example.com',
        corporateName: 'Corp Inc',
        username: 'alice',
        nationality: 'ID',
        role: 'user',
        status: 'pending_approval',
        isEmailVerified: true,
        hasUploadedDocuments: true,
        createdAt: createdAt,
        updatedAt: updatedAt,
        documents: <Map<String, dynamic>>[
          {
            'documentName': 'passport.pdf',
            'storagePath': 'gs://bucket/uid-1/passport.pdf',
            'uploadedAt': uploadedAt,
          }
        ],
      );

      // Serialize
      final map = original.toFirestore();

      // Simulate Firestore document
      final snap = snapshotWith('uid-1', map);

      // Deserialize
      final roundTripped = UserModel.fromFirestore(snap);

      expect(roundTripped.uid, original.uid);
      expect(roundTripped.email, original.email);
      expect(roundTripped.corporateName, original.corporateName);
      expect(roundTripped.username, original.username);
      expect(roundTripped.nationality, original.nationality);
      expect(roundTripped.role, original.role);
      expect(roundTripped.status, original.status);
      expect(roundTripped.isEmailVerified, original.isEmailVerified);
      expect(roundTripped.hasUploadedDocuments, original.hasUploadedDocuments);
      expect(roundTripped.createdAt, createdAt);
      expect(roundTripped.updatedAt, updatedAt);
      expect(roundTripped.documents.length, 1);
      expect(roundTripped.documents.first['documentName'], 'passport.pdf');
      expect(roundTripped.documents.first['storagePath'],
          'gs://bucket/uid-1/passport.pdf');
      expect(roundTripped.documents.first['uploadedAt'], uploadedAt);
    });

    test('Backward-compatible defaults when fields are missing', () {
      final minimalData = <String, dynamic>{
        'email': 'legacy@example.com',
        'corporateName': 'Legacy Co',
        'username': 'legacyUser',
        'nationality': 'ID',
        // Intentionally omit: role, status, isEmailVerified,
        // hasUploadedDocuments, createdAt, updatedAt, documents
      };

      final snap = snapshotWith('legacy-uid', minimalData);

      final model = UserModel.fromFirestore(snap);

      expect(model.uid, 'legacy-uid');
      expect(model.email, 'legacy@example.com');
      expect(model.corporateName, 'Legacy Co');
      expect(model.username, 'legacyUser');
      expect(model.nationality, 'ID');

      // Defaults per model code
      expect(model.role, 'user');
      expect(model.status, 'pending_email_verification');
      expect(model.isEmailVerified, isFalse);
      expect(model.hasUploadedDocuments, isFalse);
      expect(model.documents, isEmpty);

      // createdAt/updatedAt fallback to Timestamp.now(); just assert non-null type
      expect(model.createdAt, isA<Timestamp>());
      expect(model.updatedAt, isA<Timestamp>());
    });
  });
}