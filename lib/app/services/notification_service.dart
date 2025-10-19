import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import '../models/notification_item.dart';
import '../models/notification_preferences.dart';
import '../models/clearance_application.dart';
import 'logging_service.dart';

class NotificationService {
  NotificationService._internal();

  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  static const MethodChannel _androidNotificationChannel =
      MethodChannel('com.android.imigrasi/notifications');

  bool _isInitialised = false;
  StreamSubscription<String>? _tokenRefreshSubscription;
  NotificationPreferences? _cachedPreferences;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _realtimeSubscription;
  final Set<String> _knownNotificationIds = <String>{};
  bool _initialSnapshotProcessed = false;

    static const AndroidNotificationChannel _defaultAndroidChannel =
      AndroidNotificationChannel(
    'mclearance_updates',
    'M-Clearance Updates',
    description: 'Status updates and announcements from M-Clearance ISam',
    importance: Importance.max,
    enableLights: true,
    enableVibration: true,
    showBadge: true,
  );

  static Future<void> handleBackgroundMessage(RemoteMessage message) async {
    if (kIsWeb) {
      return;
    }
    try {
      final plugin = FlutterLocalNotificationsPlugin();
      const androidSettings = AndroidInitializationSettings('@mipmap/launcher_icon');
      const darwinSettings = DarwinInitializationSettings();
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
      );
      await plugin.initialize(initSettings);
      await plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_defaultAndroidChannel);
      final notification = message.notification;
      final title = notification?.title ?? message.data['title'] ?? 'M-Clearance';
      final body = notification?.body ?? message.data['body'] ?? '';
      final details = NotificationDetails(
        android: AndroidNotificationDetails(
          _defaultAndroidChannel.id,
          _defaultAndroidChannel.name,
          channelDescription: _defaultAndroidChannel.description,
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
        ),
        iOS: const DarwinNotificationDetails(),
      );
      await plugin.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        details,
        payload: message.data.isEmpty ? null : jsonEncode(message.data),
      );
    } catch (error, stackTrace) {
      LoggingService().warning(
        'Failed handling background notification',
        error,
        stackTrace,
      );
    }
  }

  Future<void> ensureInitialised() async {
    if (_isInitialised) return;

    if (kIsWeb) {
      LoggingService().debug(
        'NotificationService initialisation skipped on web platform',
      );
      _isInitialised = true;
      return;
    }

    const androidSettings = AndroidInitializationSettings('@mipmap/launcher_icon');
    const darwinSettings = DarwinInitializationSettings();
    const initializationSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );

    await _localNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (response) {
        LoggingService().info('Local notification tapped: ${response.payload}');
      },
    );

    await _localNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_defaultAndroidChannel);

    _tokenRefreshSubscription ??=
        FirebaseMessaging.instance.onTokenRefresh.listen(
      (token) async {
        await _persistFcmToken(token);
      },
      onError: (error, stackTrace) {
        LoggingService().warning(
          'FCM token refresh listener error',
          error,
          stackTrace,
        );
      },
    );

    _isInitialised = true;
  }

  Future<void> startRealtimeListener({bool force = false}) async {
    final user = _auth.currentUser;
    if (user == null) {
      await stopRealtimeListener();
      return;
    }

    if (_realtimeSubscription != null && !force) {
      return;
    }

    await _realtimeSubscription?.cancel();
    _knownNotificationIds.clear();
    _initialSnapshotProcessed = false;

    await ensureInitialised();

    if (!kIsWeb) {
      await requestPermissions();
      await syncFcmToken();
    }

    final currentUid = user.uid;

    _realtimeSubscription = _firestore
        .collection('notifications')
        .doc(user.uid)
        .collection('items')
        .orderBy('date', descending: true)
        .limit(25)
        .snapshots()
        .listen(
      (snapshot) async {
        if (!_initialSnapshotProcessed) {
          _knownNotificationIds
              .addAll(snapshot.docs.map((doc) => doc.id));
          _initialSnapshotProcessed = true;
          return;
        }

        if (snapshot.docChanges.isEmpty) {
          return;
        }

        final prefs = await getPreferences();
        var deliveredNotification = false;

        for (final change in snapshot.docChanges) {
          final docId = change.doc.id;

          if (change.type == DocumentChangeType.removed) {
            _knownNotificationIds.remove(docId);
            continue;
          }

          if (change.type != DocumentChangeType.added) {
            continue;
          }

          if (_knownNotificationIds.contains(docId)) {
            continue;
          }
          _knownNotificationIds.add(docId);

          final item = NotificationItem.fromFirestore(change.doc);
          if (item.userId != currentUid) {
            LoggingService().warning(
              'Discarding notification ${item.id} with mismatched userId ${item.userId}',
            );
            continue;
          }
          if (item.isRead) {
            continue;
          }
          if (!prefs.pushEnabled || prefs.muteAll) {
            continue;
          }
          if (kIsWeb) {
            LoggingService().debug(
              'Skipping local notification display on web (notification ${item.id})',
            );
            continue;
          }
          final payload = jsonEncode({
            'notificationId': item.id,
            'metadata': item.metadata,
          });
          final title =
              item.title.isEmpty ? 'Notification' : item.title;
          await _showLocalNotification(
            title,
            item.body,
            payload,
            preferences: prefs,
          );
          deliveredNotification = true;
        }

        if (deliveredNotification &&
            !kIsWeb &&
            prefs.pushEnabled &&
            prefs.badgeEnabled &&
            !prefs.muteAll) {
          final unread = await _getUnreadCount();
          await _updateAndroidBadge(unread);
        }
      },
      onError: (error, stackTrace) {
        LoggingService().error(
          'Realtime notification listener error',
          error,
          stackTrace,
        );
      },
    );
  }

  Future<void> stopRealtimeListener() async {
    await _realtimeSubscription?.cancel();
    _realtimeSubscription = null;
    _knownNotificationIds.clear();
    _initialSnapshotProcessed = false;
  }

  // Get user's notifications
  Stream<List<NotificationItem>> getUserNotifications() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _firestore
        .collection('notifications')
        .doc(user.uid)
        .collection('items')
        .orderBy('date', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => NotificationItem.fromFirestore(doc))
              .toList(),
        );
  }

  // Get unread notifications count
  Stream<int> getUnreadCount() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(0);

    return _firestore
        .collection('notifications')
        .doc(user.uid)
        .collection('items')
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // Mark notification as read
  Future<bool> markAsRead(String notificationId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final notifRef = _firestore
          .collection('notifications')
          .doc(user.uid)
          .collection('items')
          .doc(notificationId);
      final snap = await notifRef.get();
      if (!snap.exists) return false;
      final data = snap.data();
      if ((data?['isRead'] ?? false) == true) {
        return true;
      }

      await notifRef.update({'isRead': true});
      final unread = await _getUnreadCount();
      if (unread == 0) {
        await _updateAndroidBadge(0);
      }
      return true;
    } catch (e) {
      LoggingService().error('Error marking notification as read', e);
      return false;
    }
  }

  // Mark all notifications as read
  Future<bool> markAllAsRead() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final batch = _firestore.batch();
      final snapshot = await _firestore
          .collection('notifications')
          .doc(user.uid)
          .collection('items')
          .where('isRead', isEqualTo: false)
          .get();

      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      await batch.commit();
      final unread = await _getUnreadCount();
      if (unread == 0) {
        await _updateAndroidBadge(0);
      }
      return true;
    } catch (e) {
      LoggingService().error('Error marking all notifications as read', e);
      return false;
    }
  }

  // Create notification
  Future<String?> createNotification(NotificationItem notification) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final docRef = await _firestore
          .collection('notifications')
          .doc(user.uid)
          .collection('items')
          .add(notification.toFirestore());
      final unread = await _getUnreadCount();
      if (unread == 0) {
        await _updateAndroidBadge(0);
      }
      return docRef.id;
    } catch (e) {
      LoggingService().error('Error creating notification', e);
      return null;
    }
  }

  // Delete notification
  Future<bool> deleteNotification(String notificationId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final notifRef = _firestore
          .collection('notifications')
          .doc(user.uid)
          .collection('items')
          .doc(notificationId);

      final snap = await notifRef.get();
      if (!snap.exists) return false;
      await notifRef.delete();
      final unread = await _getUnreadCount();
      if (unread == 0) {
        await _updateAndroidBadge(0);
      }
      return true;
    } catch (e) {
      LoggingService().error('Error deleting notification', e);
      return false;
    }
  }

  // Create application status notification
  Future<String?> createApplicationNotification(
    String applicationId,
    String shipName,
    ApplicationStatus status,
  ) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      String title;
      String body;
      NotificationType type;

      switch (status) {
        case ApplicationStatus.approved:
          title = 'Application Approved';
          body = 'Your application for ship "$shipName" has been approved.';
          type = NotificationType.approved;
          break;
        case ApplicationStatus.revision:
          title = 'Application Needs Revision';
          body =
              'Your application for ship "$shipName" requires additional information.';
          type = NotificationType.revision;
          break;
        case ApplicationStatus.declined:
          title = 'Application Declined';
          body = 'Your application for ship "$shipName" has been declined.';
          type = NotificationType.update;
          break;
        default:
          return null;
      }

      final preferences = await getPreferences();

      final notification = NotificationItem(
        id: '',
        title: title,
        body: body,
        date: DateTime.now(),
        type: type,
        userId: user.uid,
      );

      final id = await createNotification(notification);
      if (id == null) {
        return null;
      }

      if (preferences.pushEnabled && !preferences.muteAll) {
        await _showLocalNotification(title, body, user.uid, preferences: preferences);
      }

      return id;
    } catch (e) {
      LoggingService().error('Error creating application notification', e);
      return null;
    }
  }

  // FCM-related methods

  // Request notification permissions
  Future<NotificationSettings?> requestPermissions() async {
    try {
      if (kIsWeb) {
        LoggingService().debug(
          'Skipping notification permission prompt on web platform',
        );
        return null;
      }
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      LoggingService().info('Notification permissions requested: $settings');
      return settings;
    } catch (e) {
      LoggingService().error('Error requesting notification permissions', e);
      return null;
    }
  }

  // Check notification permission status
  Future<NotificationSettings?> checkPermissionStatus() async {
    try {
      if (kIsWeb) {
        return null;
      }
      final settings = await FirebaseMessaging.instance
          .getNotificationSettings();
      return settings;
    } catch (e) {
      LoggingService().error(
        'Error checking notification permission status',
        e,
      );
      return null;
    }
  }

  // Get FCM token
  Future<String?> getFCMToken() async {
    try {
      if (kIsWeb) {
        LoggingService().debug('Skipping FCM token retrieval on web');
        return null;
      }
      final token = await FirebaseMessaging.instance.getToken();
      LoggingService().info(
        'FCM Token retrieved: ${token != null ? 'Present' : 'Null'}',
      );
      return token;
    } catch (e) {
      LoggingService().error('Error getting FCM token', e);
      return null;
    }
  }

  Future<void> syncFcmToken() async {
    if (kIsWeb) {
      return;
    }
    final user = _auth.currentUser;
    if (user == null) {
      return;
    }
    try {
      await ensureInitialised();
      final token = await getFCMToken();
      await _persistFcmToken(token);
    } catch (e, stackTrace) {
      LoggingService().warning(
        'Failed syncing FCM token',
        e,
        stackTrace,
      );
    }
  }

  Future<void> clearFcmToken() async {
    if (kIsWeb) {
      return;
    }
    final user = _auth.currentUser;
    if (user == null) {
      await deleteFcmToken();
      return;
    }
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        await _firestore.collection('users').doc(user.uid).set(
          {
            'messagingTokens': FieldValue.arrayRemove([token]),
            'messagingTokensUpdatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }
    } catch (e, stackTrace) {
      LoggingService().warning(
        'Failed removing FCM token from Firestore',
        e,
        stackTrace,
      );
    } finally {
      await deleteFcmToken();
    }
  }

  Future<void> _persistFcmToken(String? token) async {
    if (kIsWeb) {
      return;
    }
    final resolvedToken = token ?? '';
    if (resolvedToken.isEmpty) {
      return;
    }
    final user = _auth.currentUser;
    if (user == null) {
      return;
    }
    try {
      await _firestore.collection('users').doc(user.uid).set(
        {
          'messagingTokens': FieldValue.arrayUnion([resolvedToken]),
          'messagingTokensUpdatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e, stackTrace) {
      LoggingService().warning(
        'Failed persisting FCM token',
        e,
        stackTrace,
      );
    }
  }

  Future<void> deleteFcmToken() async {
    try {
      if (kIsWeb) {
        return;
      }
      await FirebaseMessaging.instance.deleteToken();
      LoggingService().info('FCM token deleted');
    } catch (e) {
      LoggingService().error('Error deleting FCM token', e);
    }
  }

  Future<NotificationPreferences> getPreferences() async {
    if (_cachedPreferences != null) {
      return _cachedPreferences!;
    }

    final user = _auth.currentUser;
    if (user == null) {
      return const NotificationPreferences(
        pushEnabled: true,
        muteAll: false,
        playSound: true,
        badgeEnabled: true,
      );
    }

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      final data = doc.data();
      final preferencesMap =
          data != null && data.containsKey('notificationPreferences')
              ? (data['notificationPreferences'] as Map<String, dynamic>?)
              : null;
      final preferences = NotificationPreferences.fromMap(preferencesMap);
      _cachedPreferences = preferences;
      return preferences;
    } catch (e, stackTrace) {
      LoggingService().error('Failed fetching notification preferences', e, stackTrace);
      return const NotificationPreferences(
        pushEnabled: true,
        muteAll: false,
        playSound: true,
        badgeEnabled: true,
      );
    }
  }

  Future<void> updatePreferences(NotificationPreferences preferences) async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      await _firestore.collection('users').doc(user.uid).set(
        {
          'notificationPreferences': preferences
              .copyWith(updatedAt: DateTime.now())
              .toMap(),
        },
        SetOptions(merge: true),
      );
      _cachedPreferences = preferences;

      if (!preferences.pushEnabled) {
        await deleteFcmToken();
      } else {
        await getFCMToken();
      }

      if (!preferences.badgeEnabled) {
        await _updateAndroidBadge(0);
      }
    } catch (e, stackTrace) {
      LoggingService().error('Failed updating notification preferences', e, stackTrace);
    }
  }

  Future<void> handleForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) {
      return;
    }

    await ensureInitialised();
    final prefs = await getPreferences();
    if (!prefs.pushEnabled || prefs.muteAll) {
      return;
    }

    await _showLocalNotification(
      notification.title ?? 'Notification',
      notification.body ?? '',
      message.data['payload'] as String?,
      preferences: prefs,
    );
  }

  Future<void> _showLocalNotification(
    String title,
    String body,
    String? payload, {
    NotificationPreferences? preferences,
  }) async {
    await ensureInitialised();
    final prefs = preferences ?? await getPreferences();

    if (kIsWeb) {
      LoggingService().debug(
        'Suppressing local notification on web: $title',
      );
      return;
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      final unreadCount = prefs.badgeEnabled ? await _getUnreadCount() + 1 : 0;
      try {
        await _androidNotificationChannel.invokeMethod('showBubble', {
          'title': title,
          'body': body,
          'badge': prefs.badgeEnabled ? unreadCount : 0,
          'muted': prefs.muteAll,
        });
      } catch (e, stackTrace) {
        LoggingService().warning('Falling back to standard notification', e, stackTrace);
        await _showStandardLocalNotification(title, body, payload, prefs);
      }
      return;
    }

    await _showStandardLocalNotification(title, body, payload, prefs);
  }

  Future<void> _showStandardLocalNotification(
    String title,
    String body,
    String? payload,
    NotificationPreferences prefs,
  ) async {
    if (kIsWeb) {
      return;
    }
    final badgeNumber = prefs.badgeEnabled ? await _getUnreadCount() : null;
    final androidDetails = AndroidNotificationDetails(
      _defaultAndroidChannel.id,
      _defaultAndroidChannel.name,
      channelDescription: _defaultAndroidChannel.description,
      importance: Importance.max,
      priority: Priority.high,
      playSound: prefs.playSound && !prefs.muteAll,
      enableVibration: !prefs.muteAll,
      channelShowBadge: prefs.badgeEnabled,
      icon: '@mipmap/launcher_icon',
      ticker: title,
      number: badgeNumber,
    );

    const darwinDetails = DarwinNotificationDetails();

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
    );

    await _localNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  Future<int> _getUnreadCount() async {
    final user = _auth.currentUser;
    if (user == null) return 0;
    try {
      final snapshot = await _firestore
          .collection('notifications')
          .doc(user.uid)
          .collection('items')
          .where('isRead', isEqualTo: false)
          .count()
          .get();
      final countValue = snapshot.count;
      return countValue is int ? countValue : 0;
    } catch (e, stackTrace) {
      LoggingService().warning('Failed to compute unread count', e, stackTrace);
      return 0;
    }
  }

  Future<void> _updateAndroidBadge(int count) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    try {
      await _androidNotificationChannel.invokeMethod(
        'updateBadge',
        {'badge': count},
      );
    } catch (e, stackTrace) {
      LoggingService().warning('Failed to update Android badge count', e, stackTrace);
    }
  }

  // Send push notification alongside in-app notification
  Future<bool> sendPushNotification(
    String title,
    String body,
    String userId,
  ) async {
    try {
      await ensureInitialised();
      final prefs = await getPreferences();
      if (!prefs.pushEnabled || prefs.muteAll) {
        return false;
      }

      final notification = NotificationItem(
        id: '',
        title: title,
        body: body,
        date: DateTime.now(),
        type: NotificationType.update,
        userId: userId,
      );

      final id = await createNotification(notification);

      if (id == null) {
        return false;
      }

      await _showLocalNotification(title, body, userId, preferences: prefs);

      return true;
    } catch (e) {
      LoggingService().error('Error sending push notification', e);
      return false;
    }
  }

  Future<void> handleOpenedNotification(RemoteMessage message) async {
    LoggingService().info('Notification opened with payload: ${message.data}');
  }
}
