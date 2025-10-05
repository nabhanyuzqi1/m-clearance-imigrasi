import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import '../models/legal_document.dart';
import 'logging_service.dart';

class LegalContentService {
  LegalContentService({FirebaseDatabase? database})
    : _database = database ?? _createDatabase();

  final FirebaseDatabase _database;

  static FirebaseDatabase _createDatabase() {
    const databaseUrl =
        'https://m-clearance-imigrasi-sampit.asia-southeast1.firebasedatabase.app/';

    FirebaseApp app;
    try {
      app = Firebase.app('client');
    } catch (_) {
      app = Firebase.app();
    }

    return FirebaseDatabase.instanceFor(app: app, databaseURL: databaseUrl);
  }

  DatabaseReference _docRef(LegalDocumentType type, String languageCode) {
    return _database.ref('legal/${type.databaseKey}/$languageCode');
  }

  Future<LegalDocument> fetchDocument(
    LegalDocumentType type, {
    required String languageCode,
  }) async {
    try {
      final primarySnapshot = await _docRef(type, languageCode).get();
      final primaryDoc = _parseSnapshot(primarySnapshot);
      if (primaryDoc.hasContent) return primaryDoc;

      if (languageCode.toLowerCase() != 'en') {
        final fallbackSnapshot = await _docRef(type, 'en').get();
        final fallbackDoc = _parseSnapshot(fallbackSnapshot);
        if (fallbackDoc.hasContent) return fallbackDoc;
      }
    } catch (error, stackTrace) {
      LoggingService().warning(
        'Failed fetching $type for $languageCode',
        error,
      );
      LoggingService().debug('LegalContentService stack: $stackTrace');
    }
    return LegalDocument.empty;
  }

  Stream<LegalDocument> watchDocument(
    LegalDocumentType type, {
    required String languageCode,
  }) {
    final controller = StreamController<LegalDocument>.broadcast();
    StreamSubscription<DatabaseEvent>? subscription;

    Future<void> emitSnapshot(DatabaseEvent event) async {
      final doc = _parseSnapshot(event.snapshot);
      if (doc.hasContent || languageCode.toLowerCase() == 'en') {
        controller.add(doc);
        return;
      }

      final fallbackSnapshot = await _docRef(type, 'en').get();
      controller.add(_parseSnapshot(fallbackSnapshot));
    }

    subscription = _docRef(type, languageCode).onValue.listen(
      emitSnapshot,
      onError: (error) {
        LoggingService().error(
          'LegalContentService watch error for $type:$languageCode',
          error,
        );
        controller.add(LegalDocument.empty);
      },
    );

    controller.onCancel = () async {
      await subscription?.cancel();
    };

    return controller.stream;
  }

  Future<void> updateDocument(
    LegalDocumentType type, {
    required String languageCode,
    required String content,
  }) async {
    try {
      await _docRef(
        type,
        languageCode,
      ).set({'content': content.trim(), 'updatedAt': ServerValue.timestamp});
    } catch (error, stackTrace) {
      LoggingService().error(
        'Failed updating $type for $languageCode',
        error,
        stackTrace,
      );
      rethrow;
    }
  }

  LegalDocument _parseSnapshot(DataSnapshot snapshot) {
    try {
      if (!snapshot.exists) return LegalDocument.empty;
      final value = snapshot.value;
      if (value is String) {
        return LegalDocument(content: value);
      }
      if (value is Map<Object?, Object?>) {
        final map = value.map((key, dynamic val) => MapEntry('$key', val));
        final content = (map['content'] as String?) ?? '';
        DateTime? updatedAt;
        final updatedRaw = map['updatedAt'];
        if (updatedRaw is int) {
          updatedAt = DateTime.fromMillisecondsSinceEpoch(updatedRaw);
        } else if (updatedRaw is String) {
          updatedAt = DateTime.tryParse(updatedRaw);
        }
        return LegalDocument(content: content, updatedAt: updatedAt);
      }
    } catch (error, stackTrace) {
      LoggingService().warning(
        'Failed parsing legal document snapshot: ${snapshot.key}',
        error,
        stackTrace,
      );
    }
    return LegalDocument.empty;
  }
}
