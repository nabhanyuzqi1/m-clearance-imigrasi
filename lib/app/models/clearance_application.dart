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
  final String? portClearanceFile;
  final String? crewListFile;
  final String? notificationLetterFile;
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
    this.portClearanceFile,
    this.crewListFile,
    this.notificationLetterFile,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory ClearanceApplication.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    String statusStr = data['status'] ?? 'waiting';
    ApplicationStatus status;
    switch (statusStr) {
      case 'waiting':
        status = ApplicationStatus.waiting;
        break;
      case 'revision':
        status = ApplicationStatus.revision;
        break;
      case 'approved':
        status = ApplicationStatus.approved;
        break;
      case 'declined':
        status = ApplicationStatus.declined;
        break;
      default:
        status = ApplicationStatus.waiting;
    }
    return ClearanceApplication(
      id: doc.id,
      shipName: data['shipName'] ?? '',
      flag: data['flag'] ?? '',
      agentName: data['agentName'] ?? '',
      agentUid: data['agentUid'] ?? '',
      type: data['type'] == 'arrival' ? ApplicationType.kedatangan : ApplicationType.keberangkatan,
      status: status,
      notes: data['notes'],
      port: data['port'],
      date: data['date'],
      wniCrew: data['wniCrew'],
      wnaCrew: data['wnaCrew'],
      officerName: data['officerName'],
      location: data['location'],
      portClearanceFile: data['portClearanceFile'],
      crewListFile: data['crewListFile'],
      notificationLetterFile: data['notificationLetterFile'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    final data = {
      'shipName': shipName,
      'flag': flag,
      'agentName': agentName,
      'type': type == ApplicationType.kedatangan ? 'arrival' : 'departure',
      'status': status.name,
      'notes': notes,
      'port': port,
      'date': date,
      'wniCrew': wniCrew,
      'wnaCrew': wnaCrew,
      'officerName': officerName,
      'location': location,
      'portClearanceFile': portClearanceFile,
      'crewListFile': crewListFile,
      'notificationLetterFile': notificationLetterFile,
    };

    print('DEBUG: ClearanceApplication.toFirestore() data: $data');
    print('DEBUG: Type enum value: $type (string: ${type == ApplicationType.kedatangan ? 'arrival' : 'departure'})');
    print('DEBUG: Status enum value: $status (name: ${status.name})');

    return data;
  }

  ClearanceApplication copyWith({
    String? id,
    ApplicationStatus? status,
    String? notes,
    String? officerName,
    String? location,
    String? portClearanceFile,
    String? crewListFile,
    String? notificationLetterFile,
    DateTime? updatedAt,
  }) {
    return ClearanceApplication(
      id: id ?? this.id,
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
      portClearanceFile: portClearanceFile ?? this.portClearanceFile,
      crewListFile: crewListFile ?? this.crewListFile,
      notificationLetterFile: notificationLetterFile ?? this.notificationLetterFile,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}
