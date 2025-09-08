// lib/models/clearance_application.dart

enum ApplicationType { kedatangan, keberangkatan }
enum ApplicationStatus { waiting, revision, approved, declined }

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

// PERBAIKAN: Menghapus satu kurung kurawal penutup tambahan yang menyebabkan error sintaks.
