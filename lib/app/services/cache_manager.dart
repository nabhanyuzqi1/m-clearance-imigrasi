import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Simple cache manager for API responses and user data
class CacheManager {
  static const String _userDataKey = 'cached_user_data';
  static const String _userDataTimestampKey = 'cached_user_data_timestamp';
  static const Duration _defaultCacheDuration = Duration(minutes: 30);

  static CacheManager? _instance;
  static SharedPreferences? _prefs;

  CacheManager._();

  static Future<CacheManager> getInstance() async {
    if (_instance == null) {
      _instance = CacheManager._();
      _prefs = await SharedPreferences.getInstance();
    }
    return _instance!;
  }

  /// Cache user data with timestamp
  Future<void> cacheUserData(Map<String, dynamic> userData) async {
    if (_prefs == null) return;

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    await _prefs!.setString(_userDataKey, jsonEncode(userData));
    await _prefs!.setInt(_userDataTimestampKey, timestamp);
  }

  /// Get cached user data if not expired
  Map<String, dynamic>? getCachedUserData({Duration? maxAge}) {
    if (_prefs == null) return null;

    final cachedData = _prefs!.getString(_userDataKey);
    final timestamp = _prefs!.getInt(_userDataTimestampKey);

    if (cachedData == null || timestamp == null) return null;

    final cacheAge = DateTime.now().millisecondsSinceEpoch - timestamp;
    final maxAgeMs = (maxAge ?? _defaultCacheDuration).inMilliseconds;

    if (cacheAge > maxAgeMs) {
      // Cache expired, remove it
      clearUserDataCache();
      return null;
    }

    try {
      return jsonDecode(cachedData);
    } catch (e) {
      // Invalid cache data
      clearUserDataCache();
      return null;
    }
  }

  /// Clear user data cache
  Future<void> clearUserDataCache() async {
    if (_prefs == null) return;
    await _prefs!.remove(_userDataKey);
    await _prefs!.remove(_userDataTimestampKey);
  }

  /// Check if user data is cached and valid
  bool hasValidUserDataCache({Duration? maxAge}) {
    return getCachedUserData(maxAge: maxAge) != null;
  }
}