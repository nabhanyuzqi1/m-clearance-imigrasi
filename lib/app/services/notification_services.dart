import '../models/notification_item.dart';

/// NotificationService (Mock)
///
/// Kelas ini menyimulasikan pengambilan data notifikasi dari server atau Firebase Cloud Messaging.
/// Dalam aplikasi nyata, data ini akan didorong dari server atau diambil dari koleksi Firestore.
/// Untuk saat ini, kami menggunakan List statis untuk menyediakan data notifikasi.
class NotificationService {
  
  /// Daftar notifikasi statis (simulasi database)
  static final List<NotificationItem> notifications = [
    NotificationItem(
      id: '1',
      userId: 'user1',
      title: "Perbaikan Dokumen Diperlukan",
      body: "Dokumen Crew List Anda untuk kapal MV. Ocean Queen perlu diperbaiki. Catatan: Data kru tidak lengkap.",
      date: DateTime.now().subtract(const Duration(hours: 2)),
      type: NotificationType.revision,
    ),
    NotificationItem(
      id: '2',
      userId: 'user1',
      title: "Pengajuan Disetujui!",
      body: "Pengajuan keberangkatan untuk kapal KM. Bahari telah disetujui.",
      date: DateTime.now().subtract(const Duration(days: 1)),
      type: NotificationType.approved,
      isRead: true,
    ),
    NotificationItem(
      id: '3',
      userId: 'user1',
      title: "Update Aplikasi",
      body: "Versi baru aplikasi (v1.1.0) telah tersedia dengan perbaikan bug dan peningkatan performa.",
      date: DateTime.now().subtract(const Duration(days: 3)),
      type: NotificationType.update,
      isRead: true,
    ),
  ];

  /// Menghitung jumlah notifikasi yang belum dibaca.
  static int get unreadCount => notifications.where((n) => !n.isRead).length;

  /// Menandai semua notifikasi sebagai sudah dibaca.
  static void markAllAsRead() {
    for (var notification in notifications) {
      notification.isRead = true;
    }
  }
}
