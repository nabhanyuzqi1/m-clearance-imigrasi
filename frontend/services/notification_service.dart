import '../models/notification_item.dart';

class NotificationService {
  static final List<NotificationItem> notifications = [
    NotificationItem(
      title: "Perbaikan Dokumen Diperlukan",
      body: "Dokumen Crew List Anda untuk kapal MV. Ocean Queen perlu diperbaiki. Catatan: Data kru tidak lengkap.",
      date: DateTime.now().subtract(const Duration(hours: 2)),
      type: NotificationType.revision,
    ),
    NotificationItem(
      title: "Pengajuan Disetujui!",
      body: "Pengajuan keberangkatan untuk kapal KM. Bahari telah disetujui.",
      date: DateTime.now().subtract(const Duration(days: 1)),
      type: NotificationType.approved,
      isRead: true,
    ),
    NotificationItem(
      title: "Update Aplikasi",
      body: "Versi baru aplikasi (v1.1.0) telah tersedia dengan perbaikan bug dan peningkatan performa.",
      date: DateTime.now().subtract(const Duration(days: 3)),
      type: NotificationType.update,
      isRead: true,
    ),
  ];

  static int get unreadCount => notifications.where((n) => !n.isRead).length;

  static void markAllAsRead() {
    for (var notification in notifications) {
      notification.isRead = true;
    }
  }
}