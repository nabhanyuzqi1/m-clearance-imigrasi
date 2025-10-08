import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:m_clearance_imigrasi/app/services/cache_manager.dart';
import 'package:m_clearance_imigrasi/app/services/logging_service.dart';
import 'package:m_clearance_imigrasi/app/services/network_utils.dart';
import 'package:m_clearance_imigrasi/app/localization/app_strings.dart';

class LocalizationService {
  final FirebaseDatabase _database;
  static const String _stringsPath = 'localization/strings';
  late final CacheManager _cacheManager;
  Future<void>? _cacheInitFuture;

  LocalizationService({FirebaseDatabase? database})
    : _database = database ?? FirebaseDatabase.instance {
    _cacheInitFuture = _initializeCacheManager();
  }

  Future<void> _initializeCacheManager() async {
    _cacheManager = await CacheManager.getInstance();
  }

  Future<void> _ensureCacheManagerInitialized() async {
    _cacheInitFuture ??= _initializeCacheManager();
    await _cacheInitFuture;
  }

  DatabaseReference get _stringsRef => _database.ref().child(_stringsPath);

  /// Upload current app strings to RTDB
  Future<bool> uploadCurrentStrings() async {
    try {
      LoggingService().debug(
        '[LocalizationService] Attempting to upload current strings to RTDB path: $_stringsPath',
      );

      final stringsData = {
        'strings': AppStrings.localizedStrings,
        'lastUpdated': DateTime.now().millisecondsSinceEpoch,
        'version': '1.0.0', // Could be incremented for versioning
      };

      await _stringsRef.set(stringsData);
      LoggingService().debug(
        '[LocalizationService] Successfully uploaded strings to RTDB',
      );

      // Clear cache to force refresh on next fetch
      await _ensureCacheManagerInitialized();
      await _cacheManager.clearLocalizationCache();

      return true;
    } catch (e) {
      LoggingService().error(
        '[LocalizationService] Error uploading strings: $e',
      );
      return false;
    }
  }

  /// Fetch strings with caching
  Future<Map<String, Map<String, Map<String, String>>>?>
  fetchStringsWithCaching({bool forceRefresh = false}) async {
    final startTime = DateTime.now();
    LoggingService().debug(
      '[LocalizationService] fetchStringsWithCaching called',
    );

    await _ensureCacheManagerInitialized();

    final shouldSkipCache = forceRefresh;

    if (!shouldSkipCache) {
      final cachedData = _cacheManager.getCachedLocalizationStrings();
      if (cachedData != null) {
        try {
          final strings = Map<String, Map<String, Map<String, String>>>.from(
            cachedData,
          );
          final cacheTime = DateTime.now().difference(startTime);
          LoggingService().debug(
            '[LocalizationService] Cache hit - fetchStringsWithCaching took ${cacheTime.inMilliseconds}ms',
          );
          return strings;
        } catch (e) {
          LoggingService().warning(
            '[LocalizationService] Cache data corrupted, fetching from server: $e',
          );
          await _cacheManager.clearLocalizationCache();
        }
      }
    } else {
      LoggingService().debug(
        '[LocalizationService] Skipping cache for fetchStringsWithCaching due to forceRefresh',
      );
      await _cacheManager.clearLocalizationCache();
    }

    // Fetch from server with retry logic
    try {
      final stringsData = await NetworkUtils.executeWithRetry(() async {
        final serverStart = DateTime.now();
        LoggingService().debug(
          '[LocalizationService] Performing get() on RTDB path: $_stringsPath',
        );

        final snapshot = await NetworkUtils.withTimeout(
          _stringsRef.get(),
          const Duration(seconds: 10),
        );

        final serverTime = DateTime.now().difference(serverStart);
        LoggingService().debug(
          '[LocalizationService] Server fetch took ${serverTime.inMilliseconds}ms',
        );
        LoggingService().debug(
          '[LocalizationService] Snapshot exists: ${snapshot.exists}',
        );

        if (!snapshot.exists || snapshot.value == null) {
          throw NetworkException(
            'Localization strings not found in RTDB',
            isRetryable: false,
          );
        }

        final data = Map<String, dynamic>.from(snapshot.value as Map);
        final strings = Map<String, Map<String, Map<String, String>>>.from(
          data['strings'] as Map,
        );

        return strings;
      }, shouldRetry: NetworkUtils.isRetryableError);

      // Cache the result unless explicitly skipped
      if (!shouldSkipCache) {
        await _cacheManager.cacheLocalizationStrings(stringsData);
      }

      final totalTime = DateTime.now().difference(startTime);
      LoggingService().debug(
        '[LocalizationService] fetchStringsWithCaching took ${totalTime.inMilliseconds}ms (with caching)',
      );
      return stringsData;
    } catch (e) {
      if (e is NetworkException) {
        LoggingService().error(
          '[LocalizationService] Network error in fetchStringsWithCaching: ${e.message}',
        );
      } else {
        LoggingService().error(
          '[LocalizationService] Unexpected error in fetchStringsWithCaching: $e',
        );
      }
      return null;
    }
  }

  /// Listen to localization strings changes
  Stream<Map<String, Map<String, Map<String, String>>>?> onStringsChanged() {
    return _stringsRef.onValue.map((event) {
      if (event.snapshot.exists && event.snapshot.value != null) {
        try {
          final data = Map<String, dynamic>.from(event.snapshot.value as Map);
          final strings = Map<String, Map<String, Map<String, String>>>.from(
            data['strings'] as Map,
          );

          // Update cache when strings change
          _ensureCacheManagerInitialized().then((_) {
            _cacheManager.cacheLocalizationStrings(strings);
          });

          LoggingService().debug(
            '[LocalizationService] Strings updated from RTDB',
          );
          return strings;
        } catch (e) {
          LoggingService().error(
            '[LocalizationService] Error parsing strings from RTDB: $e',
          );
          return null;
        }
      }
      LoggingService().debug(
        '[LocalizationService] No strings found in RTDB snapshot',
      );
      return null;
    });
  }

  /// Get last updated timestamp from RTDB
  Future<DateTime?> getLastUpdated() async {
    try {
      final snapshot = await _stringsRef.child('lastUpdated').get();
      if (snapshot.exists && snapshot.value != null) {
        final timestamp = snapshot.value as int;
        return DateTime.fromMillisecondsSinceEpoch(timestamp);
      }
      return null;
    } catch (e) {
      LoggingService().error(
        '[LocalizationService] Error fetching last updated timestamp: $e',
      );
      return null;
    }
  }
}
