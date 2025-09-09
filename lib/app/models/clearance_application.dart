import 'package:cloud_firestore/cloud_firestore.dart';

enum ApplicationType { kedatangan, keberangkatan }
enum ApplicationStatus { waiting, revision, approved, declined }

class ClearanceApplication {
  final String id;
  final String shipName;
  final String flag;
  final String agentName;
  final String agentUid;
  final ApplicationStatus status;
  final ApplicationType type;
  final String? notes;
  final String? port;
  final String? date;
  final String? wniCrew;
  final String? wnaCrew;
  final String? officerName;
  final String? location;
  final DateTime createdAt;
  final DateTime updatedAt;

  ClearanceApplication({
    required this.id,
    required this.shipName,
    required this.flag,
    required this.agentName,
    required this.agentUid,
    required this.type,
    this.status = ApplicationStatus.waiting,
    this.notes,
    this.port,
    this.date,
    this.wniCrew,
    this.wnaCrew,
    this.officerName,
    this.location,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  factory ClearanceApplication.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ClearanceApplication(
      id: doc.id,
      shipName: data['shipName'] ?? '',
      flag: data['flag'] ?? '',
      agentName: data['agentName'] ?? '',
      agentUid: data['agentUid'] ?? '',
      type: ApplicationType.values[data['type'] ?? 0],
      status: ApplicationStatus.values[data['status'] ?? 0],
      notes: data['notes'],
      port: data['port'],
      date: data['date'],
      wniCrew: data['wniCrew'],
      wnaCrew: data['wnaCrew'],
      officerName: data['officerName'],
      location: data['location'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'shipName': shipName,
      'flag': flag,
      'agentName': agentName,
      'agentUid': agentUid,
      'type': type.index,
      'status': status.index,
      'notes': notes,
      'port': port,
      'date': date,
      'wniCrew': wniCrew,
      'wnaCrew': wnaCrew,
      'officerName': officerName,
      'location': location,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  ClearanceApplication copyWith({
    ApplicationStatus? status,
    String? notes,
    String? officerName,
    String? location,
    DateTime? updatedAt,
  }) {
    return ClearanceApplication(
      id: id,
      shipName: shipName,
      flag: flag,
      agentName: agentName,
      agentUid: agentUid,
      type: type,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      port: port,
      date: date,
      wniCrew: wniCrew,
      wnaCrew: wnaCrew,
      officerName: officerName ?? this.officerName,
      location: location ?? this.location,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}
