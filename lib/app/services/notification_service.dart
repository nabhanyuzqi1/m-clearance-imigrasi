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
  NotificationPreferences? _cachedPreferences;

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

  Future<void> ensureInitialised() async {
    if (_isInitialised) return;

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

    _isInitialised = true;
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
      await _updateAndroidBadge(unread);
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
      await _updateAndroidBadge(unread);
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
      await _updateAndroidBadge(unread);
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
      await _updateAndroidBadge(unread);
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

  Future<void> deleteFcmToken() async {
    try {
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
