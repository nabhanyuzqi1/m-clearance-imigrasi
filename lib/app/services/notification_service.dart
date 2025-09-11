import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
        .map((snapshot) =>
            snapshot.docs.map((doc) => NotificationItem.fromFirestore(doc)).toList());
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

      await _firestore
          .collection('notifications')
          .doc(user.uid)
          .collection('items')
          .doc(notificationId)
          .update({'isRead': true});

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

      await _firestore
          .collection('notifications')
          .doc(user.uid)
          .collection('items')
          .doc(notificationId)
          .delete();

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
          body = 'Your application for ship "$shipName" requires additional information.';
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

      return await createNotification(notification);
    } catch (e) {
      LoggingService().error('Error creating application notification', e);
      return null;
    }
  }
}