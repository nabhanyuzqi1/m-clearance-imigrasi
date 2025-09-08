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
  final String? id;
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
    this.id,
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
    String? id,
    ApplicationStatus? status,
    String? notes,
    String? officerName,
    String? location,
  }) {
    return ClearanceApplication(
      id: id ?? this.id,
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

/// Mapper utilities for converting to/from Firestore maps without coupling
/// the model to Firestore types.
class ClearanceApplicationMapper {
  static ApplicationType _parseType(dynamic v) {
    final s = (v ?? '').toString().toLowerCase();
    switch (s) {
      case 'arrival':
      case 'kedatangan':
        return ApplicationType.kedatangan;
      case 'departure':
      case 'keberangkatan':
        return ApplicationType.keberangkatan;
      default:
        return ApplicationType.kedatangan;
    }
  }

  static ApplicationStatus _parseStatus(dynamic v) {
    final s = (v ?? '').toString().toLowerCase();
    switch (s) {
      case 'waiting':
        return ApplicationStatus.waiting;
      case 'revision':
        return ApplicationStatus.revision;
      case 'approved':
        return ApplicationStatus.approved;
      case 'declined':
        return ApplicationStatus.declined;
      default:
        return ApplicationStatus.waiting;
    }
  }

  static ClearanceApplication fromMap(Map<String, dynamic> data, {String? id}) {
    return ClearanceApplication(
      id: id,
      shipName: (data['shipName'] ?? data['vesselName'] ?? 'Vessel').toString(),
      flag: (data['flag'] ?? '-').toString(),
      agentName: (data['agentName'] ?? data['agent'] ?? '-').toString(),
      type: _parseType(data['type']),
      status: _parseStatus(data['status']),
      notes: data['notes']?.toString(),
      port: (data['port'] ?? data['location'])?.toString(),
      date: (data['date'] ?? data['arrivalDate'] ?? data['departureDate'])?.toString(),
      wniCrew: data['wniCrew']?.toString(),
      wnaCrew: data['wnaCrew']?.toString(),
      officerName: data['officerName']?.toString(),
      location: data['location']?.toString(),
    );
  }
}
