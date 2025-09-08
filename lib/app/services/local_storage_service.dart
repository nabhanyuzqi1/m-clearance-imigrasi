import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:m_clearance_imigrasi/app/models/user_model.dart';

class LocalStorageService {
  static const String _userDataKey = 'cached_user_data';
  static const String _lastRouteKey = 'last_navigation_route';
  static const String _authStateKey = 'auth_state';
  static const String _cacheTimestampKey = 'cache_timestamp';

  // Cache expiry time (24 hours)
  static const Duration _cacheExpiry = Duration(hours: 24);

  static Future<SharedPreferences> get _prefs async =>
      await SharedPreferences.getInstance();

  /// Cache user data locally
  static Future<void> cacheUserData(UserModel user) async {
    final prefs = await _prefs;
    try {
      final userDataJson = jsonEncode(user.toJson());
      await prefs.setString(_userDataKey, userDataJson);
      await prefs.setInt(_cacheTimestampKey, DateTime.now().millisecondsSinceEpoch);
      print('User data cached successfully');
    } catch (e) {
      print('Error caching user data: $e');
      print('User data to cache: ${user.toJson()}');
      rethrow;
    }
  }

  /// Get cached user data
  static Future<UserModel?> getCachedUserData() async {
    final prefs = await _prefs;
    final userDataJson = prefs.getString(_userDataKey);
    final timestamp = prefs.getInt(_cacheTimestampKey);

    if (userDataJson == null || timestamp == null) {
      return null;
    }

    // Check if cache is expired
    final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    if (DateTime.now().difference(cacheTime) > _cacheExpiry) {
      await clearUserData();
      return null;
    }

    try {
      final userData = jsonDecode(userDataJson) as Map<String, dynamic>;
      return UserModel.fromJson(userData);
    } catch (e) {
      print('Error parsing cached user data: $e');
      await clearUserData();
      return null;
    }
  }

  /// Cache last navigation route
  static Future<void> cacheLastRoute(String routeName, {Map<String, dynamic>? args}) async {
    final prefs = await _prefs;
    final routeData = {
      'routeName': routeName,
      'args': args,
    };
    await prefs.setString(_lastRouteKey, jsonEncode(routeData));
  }

  /// Get cached last route
  static Future<Map<String, dynamic>?> getCachedLastRoute() async {
    final prefs = await _prefs;
    final routeDataJson = prefs.getString(_lastRouteKey);
    if (routeDataJson == null) return null;

    try {
      return jsonDecode(routeDataJson) as Map<String, dynamic>;
    } catch (e) {
      print('Error parsing cached route data: $e');
      return null;
    }
  }

  /// Cache authentication state
  static Future<void> cacheAuthState(bool isAuthenticated, {String? userId}) async {
    final prefs = await _prefs;
    final authData = {
      'isAuthenticated': isAuthenticated,
      'userId': userId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    await prefs.setString(_authStateKey, jsonEncode(authData));
  }

  /// Get cached authentication state
  static Future<Map<String, dynamic>?> getCachedAuthState() async {
    final prefs = await _prefs;
    final authDataJson = prefs.getString(_authStateKey);
    if (authDataJson == null) return null;

    try {
      return jsonDecode(authDataJson) as Map<String, dynamic>;
    } catch (e) {
      print('Error parsing cached auth state: $e');
      return null;
    }
  }

  /// Clear all cached user data
  static Future<void> clearUserData() async {
    final prefs = await _prefs;
    await prefs.remove(_userDataKey);
    await prefs.remove(_cacheTimestampKey);
  }

  /// Clear all cached data
  static Future<void> clearAll() async {
    final prefs = await _prefs;
    await prefs.remove(_userDataKey);
    await prefs.remove(_lastRouteKey);
    await prefs.remove(_authStateKey);
    await prefs.remove(_cacheTimestampKey);
  }

  /// Check if user data is cached and valid
  static Future<bool> hasValidCachedData() async {
    final cachedUser = await getCachedUserData();
    return cachedUser != null;
  }
}

/// Mock DocumentSnapshot for deserializing cached data
class _MockDocumentSnapshot {
  final Map<String, dynamic> _data;

  _MockDocumentSnapshot(this._data);

  Map<String, dynamic> get data => _data;

  String get id => _data['uid'] ?? '';

  bool get exists => true;

  dynamic get reference => _MockDocumentReference();

  SnapshotMetadata get metadata => _MockSnapshotMetadata();

  dynamic operator [](Object key) => key is String ? _data[key] : null;

  dynamic get(Object field) => field is String ? _data[field] : null;
}

class _MockDocumentReference {
  dynamic get id => throw UnimplementedError();

  dynamic get parent => throw UnimplementedError();

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _MockSnapshotMetadata implements SnapshotMetadata {
  @override
  bool get hasPendingWrites => false;

  @override
  bool get isFromCache => true;
}