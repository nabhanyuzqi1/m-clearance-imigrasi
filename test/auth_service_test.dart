import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:m_clearance_imigrasi/app/services/auth_service.dart';
import 'package:m_clearance_imigrasi/app/models/user_model.dart';

// Generate mocks
@GenerateMocks([
  FirebaseAuth,
  FirebaseFirestore,
  FirebaseStorage,
  CollectionReference,
  DocumentReference,
  DocumentSnapshot,
  User,
])
import 'auth_service_test.mocks.dart';

void main() {
  group('AuthService', () {
    late MockFirebaseAuth mockAuth;
    late MockFirebaseFirestore mockFirestore;
    late MockFirebaseStorage mockStorage;
    late MockCollectionReference<Map<String, dynamic>> mockUsersCollection;
    late MockDocumentReference<Map<String, dynamic>> mockDocRef;
    late MockUser mockUser;
    late AuthService service;

    MockDocumentSnapshot<Map<String, dynamic>> snapshotWith(
        Map<String, dynamic> data, {
      String id = 'uid-123',
    }) {
      final snap = MockDocumentSnapshot<Map<String, dynamic>>();
      when(snap.exists).thenReturn(true);
      when(snap.id).thenReturn(id);
      when(snap.data()).thenReturn(data);
      return snap;
    }

    setUp(() {
      mockAuth = MockFirebaseAuth();
      mockFirestore = MockFirebaseFirestore();
      mockStorage = MockFirebaseStorage();
      mockUsersCollection = MockCollectionReference<Map<String, dynamic>>();
      mockDocRef = MockDocumentReference<Map<String, dynamic>>();
      mockUser = MockUser();

      // Default user setup
      when(mockAuth.currentUser).thenReturn(mockUser);
      when(mockUser.uid).thenReturn('uid-123');
      when(mockUser.reload()).thenAnswer((_) async {});
      when(mockUser.emailVerified).thenReturn(false);

      // Firestore wiring
      when(mockFirestore.collection('users')).thenReturn(mockUsersCollection);
      when(mockUsersCollection.doc(any)).thenReturn(mockDocRef);
      when(mockDocRef.update(any)).thenAnswer((_) async {});

      service = AuthService(
        firebaseAuth: mockAuth,
        firestore: mockFirestore,
        storage: mockStorage,
      );
    });

    group('updateEmailVerified()', () {
      test('idempotent verified transition (sets flags and moves to pending_documents once)', () async {
        // Given: user reload yields emailVerified = true
        when(mockUser.emailVerified).thenReturn(true);

        final initialData = <String, dynamic>{
          'email': 'user@example.com',
          'status': 'pending_email_verification',
          'isEmailVerified': false,
          'hasUploadedDocuments': false,
          'documents': <Map<String, dynamic>>[],
          'role': 'user',
          'createdAt': Timestamp.now(),
          'updatedAt': Timestamp.now(),
        };
        final afterUpdateData = <String, dynamic>{
          ...initialData,
          'status': 'pending_documents',
          'isEmailVerified': true,
          'updatedAt': Timestamp.now(),
        };

        // Sequence: get() before update, then get() after update
        // Return initial once, then always "afterUpdateData" for subsequent calls
        var callCount1 = 0;
        when(mockDocRef.get()).thenAnswer((_) {
          final snap = (callCount1++ == 0)
              ? snapshotWith(initialData)
              : snapshotWith(afterUpdateData);
          return Future.value(snap);
        });

        final first = await service.updateEmailVerified();
        expect(first, isA<UserModel>());
        expect(first!.status, 'pending_documents');
        expect(first.isEmailVerified, isTrue);

        final second = await service.updateEmailVerified();
        expect(second, isA<UserModel>());
        expect(second!.status, 'pending_documents');
        expect(second.isEmailVerified, isTrue);

        // Verify Firestore writes:
        final captured = verify(mockDocRef.update(captureAny)).captured;
        expect(captured.length, greaterThanOrEqualTo(2));

        final Map firstUpdate = captured[0] as Map;
        expect(firstUpdate['isEmailVerified'], true);
        expect(firstUpdate['status'], 'pending_documents');
        expect(firstUpdate['updatedAt'], isA<FieldValue>());

        final Map secondUpdate = captured[1] as Map;
        // Idempotent with respect to status transition (no second transition)
        expect(secondUpdate['isEmailVerified'], true);
        expect(secondUpdate.containsKey('status'), isFalse);
        expect(secondUpdate.containsKey('documents'), isFalse);
        expect(secondUpdate['updatedAt'], isA<FieldValue>());
      });

      test('no-op when not verified (no Firestore write)', () async {
        when(mockUser.emailVerified).thenReturn(false);

        final initialData = <String, dynamic>{
          'email': 'user@example.com',
          'status': 'pending_email_verification',
          'isEmailVerified': false,
          'hasUploadedDocuments': false,
          'documents': <Map<String, dynamic>>[],
          'role': 'user',
          'createdAt': Timestamp.now(),
          'updatedAt': Timestamp.now(),
        };

        when(mockDocRef.get()).thenAnswer((_) async => snapshotWith(initialData));

        final model = await service.updateEmailVerified();
        expect(model, isA<UserModel>());
        expect(model!.status, 'pending_email_verification');
        expect(model.isEmailVerified, isFalse);

        verifyNever(mockDocRef.update(any));
      });
    });

    group('ensureCanUploadDocuments()', () {
      test('throws StateError when emailVerified is false', () async {
        when(mockUser.emailVerified).thenReturn(false);

        await expectLater(
          service.ensureCanUploadDocuments(),
          throwsA(isA<StateError>()),
        );

        verifyNever(mockDocRef.get());
      });

      test('throws StateError when Firestore status != "pending_documents"', () async {
        when(mockUser.emailVerified).thenReturn(true);

        final wrongStatusData = <String, dynamic>{
          'email': 'user@example.com',
          'status': 'pending_approval',
          'isEmailVerified': true,
          'hasUploadedDocuments': false,
          'documents': <Map<String, dynamic>>[],
          'role': 'user',
          'createdAt': Timestamp.now(),
          'updatedAt': Timestamp.now(),
        };

        when(mockDocRef.get()).thenAnswer((_) async => snapshotWith(wrongStatusData));

        await expectLater(
          service.ensureCanUploadDocuments(),
          throwsA(isA<StateError>()),
        );
      });

      test('succeeds silently when verified and status == "pending_documents"', () async {
        when(mockUser.emailVerified).thenReturn(true);

        final okData = <String, dynamic>{
          'email': 'user@example.com',
          'status': 'pending_documents',
          'isEmailVerified': true,
          'hasUploadedDocuments': false,
          'documents': <Map<String, dynamic>>[],
          'role': 'user',
          'createdAt': Timestamp.now(),
          'updatedAt': Timestamp.now(),
        };

        when(mockDocRef.get()).thenAnswer((_) async => snapshotWith(okData));

        await service.ensureCanUploadDocuments(); // no throw
      });
    });

    group('markDocumentsUploaded()', () {
      test('sets flags, transitions once to pending_approval, and avoids duplicates on repeat', () async {
        final p1 = 'gs://bucket/uid-123/a.pdf';
        final p2 = 'gs://bucket/uid-123/b.pdf';

        final initial = <String, dynamic>{
          'email': 'user@example.com',
          'status': 'pending_documents',
          'isEmailVerified': true,
          'hasUploadedDocuments': false,
          'documents': <Map<String, dynamic>>[],
          'role': 'user',
          'createdAt': Timestamp.now(),
          'updatedAt': Timestamp.now(),
        };

        final afterFirst = <String, dynamic>{
          'email': 'user@example.com',
          'status': 'pending_approval',
          'isEmailVerified': true,
          'hasUploadedDocuments': true,
          'documents': <Map<String, dynamic>>[
            {
              'documentName': 'a.pdf',
              'storagePath': p1,
              'uploadedAt': Timestamp.now(),
            },
            {
              'documentName': 'b.pdf',
              'storagePath': p2,
              'uploadedAt': Timestamp.now(),
            },
          ],
          'role': 'user',
          'createdAt': Timestamp.now(),
          'updatedAt': Timestamp.now(),
        };

        // Second call (already pending_approval), no additional docs or status change
        final afterSecond = Map<String, dynamic>.from(afterFirst);

        // Sequence across two calls (each call does get() before and after update)
        // Return initial once, then always "afterFirst" for subsequent calls
        var callCount2 = 0;
        when(mockDocRef.get()).thenAnswer((_) {
          final snap = (callCount2++ == 0)
              ? snapshotWith(initial)
              : snapshotWith(afterFirst);
          return Future.value(snap);
        });

        final r1 = await service.markDocumentsUploaded(
          storagePathsOrRefs: [p1, p2],
        );
        expect(r1, isNotNull);
        expect(r1!.status, 'pending_approval');
        expect(r1.hasUploadedDocuments, isTrue);
        expect(r1.documents.length, 2);

        final r2 = await service.markDocumentsUploaded(
          storagePathsOrRefs: [p1, p2],
        );
        expect(r2, isNotNull);
        expect(r2!.status, 'pending_approval');
        expect(r2.documents.length, 2); // no duplicates

        final captured = verify(mockDocRef.update(captureAny)).captured;
        expect(captured.length, 2);

        final Map firstUpdate = captured[0] as Map;
        expect(firstUpdate['hasUploadedDocuments'], true);
        expect(firstUpdate['status'], 'pending_approval');
        expect(firstUpdate.containsKey('documents'), isTrue);
        expect(firstUpdate['updatedAt'], isA<FieldValue>());

        final Map secondUpdate = captured[1] as Map;
        expect(secondUpdate['hasUploadedDocuments'], true);
        expect(secondUpdate.containsKey('status'), isFalse);
        expect(secondUpdate.containsKey('documents'), isFalse);
        expect(secondUpdate['updatedAt'], isA<FieldValue>());
      });
    });
  });
}