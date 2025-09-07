/// Enum untuk tipe notifikasi.
enum NotificationType { 
  /// Notifikasi umum atau pembaruan sistem.
  update, 
  /// Notifikasi bahwa pengajuan telah disetujui.
  approved, 
  /// Notifikasi bahwa pengajuan memerlukan revisi.
  revision 
}

/// NotificationItem Class
///
/// Merepresentasikan sebuah item notifikasi yang akan ditampilkan kepada pengguna.
/// Setiap notifikasi memiliki judul, isi, tanggal, tipe, dan status
/// apakah sudah dibaca atau belum.
class NotificationItem {
  final String title;
  final String body;
  final DateTime date;
  final NotificationType type;
  bool isRead;

  NotificationItem({
    required this.title,
    required this.body,
    required this.date,
    required this.type,
    this.isRead = false,
  });
}
