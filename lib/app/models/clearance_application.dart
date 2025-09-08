/// Enum untuk tipe pengajuan clearance.
enum ApplicationType { 
  /// Pengajuan untuk clearance kedatangan kapal.
  kedatangan, 
  /// Pengajuan untuk clearance keberangkatan kapal.
  keberangkatan 
}

/// Enum untuk status pengajuan clearance.
enum ApplicationStatus { 
  /// Pengajuan sedang menunggu verifikasi dari petugas.
  waiting, 
  /// Pengajuan memerlukan perbaikan dari agen.
  revision, 
  /// Pengajuan telah disetujui oleh petugas.
  approved, 
  /// Pengajuan ditolak oleh petugas.
  declined 
}

/// ClearanceApplication Class
///
/// Merepresentasikan sebuah pengajuan clearance yang dibuat oleh agen.
/// Model ini mencakup semua detail yang berkaitan dengan kapal, agen,
/// perjalanan, dan status verifikasi pengajuan.
class ClearanceApplication {
  final String shipName;
  final String flag;
  final String agentName;
  final ApplicationStatus status;
  final ApplicationType type;
  final String? notes;
  final String? port;
  final String? date;
  final String? wniCrew;
  final String? wnaCrew;
  final String? officerName;
  final String? location;

  ClearanceApplication({
    required this.shipName,
    required this.flag,
    required this.agentName,
    required this.type,
    this.status = ApplicationStatus.waiting,
    this.notes,
    this.port,
    this.date,
    this.wniCrew,
    this.wnaCrew,
    this.officerName,
    this.location,
  });

  /// Membuat salinan objek ClearanceApplication dengan beberapa nilai yang diperbarui.
  /// Berguna untuk mengubah status atau menambahkan catatan tanpa memodifikasi objek asli.
  ClearanceApplication copyWith({
    ApplicationStatus? status,
    String? notes,
    String? officerName,
    String? location,
  }) {
    return ClearanceApplication(
      shipName: shipName,
      flag: flag,
      agentName: agentName,
      type: type,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      port: port,
      date: date,
      wniCrew: wniCrew,
      wnaCrew: wnaCrew,
      officerName: officerName ?? this.officerName,
      location: location ?? this.location,
    );
  }
}
