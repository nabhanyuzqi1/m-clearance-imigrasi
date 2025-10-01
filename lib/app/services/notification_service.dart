import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../models/notification_item.dart';
import '../models/clearance_application.dart';
import 'logging_service.dart';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

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

      final notification = NotificationItem(
        id: '',
        title: title,
        body: body,
        date: DateTime.now(),
        type: type,
        userId: user.uid,
      );

      final id = await createNotification(notification);

      // Send push notification if permissions are granted
      if (id != null) {
        final permissionStatus = await checkPermissionStatus();
        if (permissionStatus?.authorizationStatus ==
            AuthorizationStatus.authorized) {
          await sendPushNotification(title, body, user.uid);
        }
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

  // Send push notification alongside in-app notification
  Future<bool> sendPushNotification(
    String title,
    String body,
    String userId,
  ) async {
    try {
      // For now, this is a placeholder. In a real implementation,
      // you would send the notification via your backend server
      // which would use FCM to send the push notification.
      // Here we just create the in-app notification.

      final notification = NotificationItem(
        id: '',
        title: title,
        body: body,
        date: DateTime.now(),
        type: NotificationType.update,
        userId: userId,
      );

      final id = await createNotification(notification);
      return id != null;
    } catch (e) {
      LoggingService().error('Error sending push notification', e);
      return false;
    }
  }
}
