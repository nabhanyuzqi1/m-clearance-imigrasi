import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../localization/app_strings.dart';
import 'cache_manager.dart';
import 'logging_service.dart';
import 'network_utils.dart';

class LocalizationService {
  LocalizationService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance {
    _cacheInitFuture = _initializeCacheManager();
  }

  final FirebaseFirestore _firestore;
  static const String _collection = 'localization';
  static const String _stringsDoc = 'strings';
  static const String _metaDoc = 'meta';

  late final CacheManager _cacheManager;
  Future<void>? _cacheInitFuture;

  Future<void> _initializeCacheManager() async {
    _cacheManager = await CacheManager.getInstance();
  }

  Future<void> _ensureCacheManagerInitialized() async {
    _cacheInitFuture ??= _initializeCacheManager();
    await _cacheInitFuture;
  }

  DocumentReference<Map<String, dynamic>> get _stringsRef =>
      _firestore.collection(_collection).doc(_stringsDoc);

  DocumentReference<Map<String, dynamic>> get _metaRef =>
      _firestore.collection(_collection).doc(_metaDoc);

  /// Upload current localization strings to Firestore.
  Future<bool> uploadCurrentStrings() async {
    try {
      LoggingService().debug(
        '[LocalizationService] Uploading localization strings to Firestore',
      );

      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final batch = _firestore.batch();

      batch.set(_stringsRef, {
        'strings': AppStrings.localizedStrings,
        'lastUpdated': nowMs,
        'version': '1.0.0',
      }, SetOptions(merge: true));

      batch.set(_metaRef, {
        'lastUpdated': nowMs,
        'version': '1.0.0',
      }, SetOptions(merge: true));

      await batch.commit();

      await _ensureCacheManagerInitialized();
      await _cacheManager.clearLocalizationCache();

      LoggingService().debug(
        '[LocalizationService] Localization strings uploaded successfully',
      );
      return true;
    } catch (error, stackTrace) {
      LoggingService().error(
        '[LocalizationService] Error uploading localization strings: $error',
        stackTrace,
      );
      return false;
    }
  }

  Future<Map<String, Map<String, Map<String, String>>>?>
  fetchStringsWithCaching({bool forceRefresh = false}) async {
    final startTime = DateTime.now();
    LoggingService().debug(
      '[LocalizationService] fetchStringsWithCaching called',
    );

    await _ensureCacheManagerInitialized();

    final cachedStrings = forceRefresh
        ? null
        : _cacheManager.getCachedLocalizationStrings();

    int? remoteTimestamp;
    String? remoteVersion;

    try {
      final metaSnap = await NetworkUtils.withTimeout(
        _metaRef.get(),
        const Duration(seconds: 10),
      );
      if (metaSnap.exists) {
        final data = metaSnap.data();
        if (data != null) {
          remoteTimestamp = _parseTimestampMs(data['lastUpdated']);
          remoteVersion = data['version'] as String?;
        }
      }
    } catch (error) {
      LoggingService().warning(
        '[LocalizationService] Failed to fetch localization metadata: $error',
      );
    }

    final cachedTimestamp = _cacheManager.getCachedLocalizationTimestamp();
    final hasCache = cachedStrings != null;
    final isUpToDate =
        !forceRefresh &&
        hasCache &&
        remoteTimestamp != null &&
        cachedTimestamp != null &&
        cachedTimestamp >= remoteTimestamp;

    if (isUpToDate) {
      LoggingService().debug(
        '[LocalizationService] Cached localization strings are up to date',
      );
      return cachedStrings;
    }

    if (!forceRefresh && hasCache && remoteTimestamp == null) {
      LoggingService().warning(
        '[LocalizationService] Unable to verify localization freshness, using cache',
      );
      return cachedStrings;
    }

    try {
      final snapshot = await NetworkUtils.executeWithRetry(() async {
        return await NetworkUtils.withTimeout(
          _stringsRef.get(),
          const Duration(seconds: 10),
        );
      }, shouldRetry: NetworkUtils.isRetryableError);

      if (!snapshot.exists) {
        throw NetworkException(
          'Localization strings not found in Firestore',
          isRetryable: false,
        );
      }

      final data = snapshot.data() ?? const <String, dynamic>{};
      final stringsRaw = data['strings'];
      if (stringsRaw is! Map) {
        throw const FormatException('Invalid localization payload.');
      }

      final strings = _normalizeStrings(stringsRaw);
      final serverTimestamp =
          _parseTimestampMs(data['lastUpdated']) ?? remoteTimestamp;
      final version = (data['version'] as String?) ?? remoteVersion;

      await _cacheManager.cacheLocalizationStrings(
        strings,
        lastUpdatedMs: serverTimestamp,
        version: version,
      );

      final totalTime = DateTime.now().difference(startTime);
      LoggingService().debug(
        '[LocalizationService] Fetched localization strings in ${totalTime.inMilliseconds}ms',
      );
      return strings;
    } catch (error) {
      LoggingService().error(
        '[LocalizationService] Failed to fetch localization strings: $error',
      );
      if (cachedStrings != null) {
        LoggingService().warning(
          '[LocalizationService] Falling back to cached localization strings',
        );
        return cachedStrings;
      }
      return null;
    }
  }

  Stream<Map<String, Map<String, Map<String, String>>>?> onStringsChanged() {
    return _stringsRef.snapshots().map((snapshot) {
      if (!snapshot.exists) {
        LoggingService().warning(
          '[LocalizationService] Localization strings document missing',
        );
        return null;
      }
      final data = snapshot.data();
      if (data == null) return null;
      final stringsRaw = data['strings'];
      if (stringsRaw is! Map) return null;

      final strings = _normalizeStrings(stringsRaw);
      final lastUpdatedMs = _parseTimestampMs(data['lastUpdated']);
      final version = data['version'] as String?;

      _ensureCacheManagerInitialized().then((_) {
        _cacheManager.cacheLocalizationStrings(
          strings,
          lastUpdatedMs: lastUpdatedMs,
          version: version,
        );
      });

      return strings;
    });
  }

  Future<DateTime?> getLastUpdated() async {
    try {
      final snapshot = await _metaRef.get();
      if (snapshot.exists) {
        final data = snapshot.data();
        if (data != null) {
          final ms = _parseTimestampMs(data['lastUpdated']);
          if (ms != null) {
            return DateTime.fromMillisecondsSinceEpoch(ms);
          }
        }
      }
      return null;
    } catch (error, stackTrace) {
      LoggingService().error(
        '[LocalizationService] Failed to get localization lastUpdated: $error',
        stackTrace,
      );
      return null;
    }
  }

  Map<String, Map<String, Map<String, String>>> _normalizeStrings(
    Map<dynamic, dynamic> raw,
  ) {
    final transformed = <String, Map<String, Map<String, String>>>{};
    raw.forEach((languageKey, languageValue) {
      final screensDynamic = Map<String, dynamic>.from(
        Map<dynamic, dynamic>.from(languageValue as Map),
      );
      final screenMap = <String, Map<String, String>>{};
      screensDynamic.forEach((screenKey, screenValue) {
        final stringsDynamic = Map<String, dynamic>.from(
          Map<dynamic, dynamic>.from(screenValue as Map),
        );
        final stringMap = stringsDynamic.map(
          (key, value) => MapEntry(key, value.toString()),
        );
        screenMap[screenKey] = stringMap;
      });
      transformed[languageKey as String] = screenMap;
    });
    return transformed;
  }

  int? _parseTimestampMs(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.millisecondsSinceEpoch;
    if (value is DateTime) return value.millisecondsSinceEpoch;
    if (value is int) return value;
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) return parsed;
      final date = DateTime.tryParse(value);
      if (date != null) return date.millisecondsSinceEpoch;
    }
    return null;
  }
}
