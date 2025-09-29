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
  final List<String> crewListFiles;
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
    List<String>? crewListFiles,
    this.notificationLetterFile,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : crewListFiles = crewListFiles ?? const [],
       createdAt = createdAt ?? DateTime.now(),
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
      type: data['type'] == 'arrival'
          ? ApplicationType.kedatangan
          : ApplicationType.keberangkatan,
      status: status,
      notes: data['notes'],
      port: data['port'],
      date: data['date'],
      wniCrew: data['wniCrew'],
      wnaCrew: data['wnaCrew'],
      officerName: data['officerName'],
      location: _normalizeLocation(
        data['location'] ??
            data['locationName'] ??
            data['location_name'] ??
            data['portLocation'] ??
            data['locationDisplay'] ??
            data['lokasi'],
      ),
      portClearanceFile: data['portClearanceFile'],
      crewListFiles: _resolveCrewListFiles(data),
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
      'crewListFiles': crewListFiles,
      'crewListFile': crewListFiles.isNotEmpty ? crewListFiles.first : null,
      'notificationLetterFile': notificationLetterFile,
    };

    print('DEBUG: ClearanceApplication.toFirestore() data: $data');
    print(
      'DEBUG: Type enum value: $type (string: ${type == ApplicationType.kedatangan ? 'arrival' : 'departure'})',
    );
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
    List<String>? crewListFiles,
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
      crewListFiles: crewListFiles ?? List<String>.from(this.crewListFiles),
      notificationLetterFile:
          notificationLetterFile ?? this.notificationLetterFile,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  String? get crewListFile =>
      crewListFiles.isNotEmpty ? crewListFiles.first : null;
}

String? _normalizeLocation(dynamic value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  final normalized = trimmed.toLowerCase();
  const invalidTokens = {
    'n/a',
    'na',
    'n.a',
    'not available',
    'tidak tersedia',
    '-',
  };
  if (invalidTokens.contains(normalized)) return null;
  return trimmed;
}

List<String> _resolveCrewListFiles(Map<String, dynamic> data) {
  final List<String> files = [];
  final crewFiles = data['crewListFiles'];
  if (crewFiles is List) {
    for (final item in crewFiles) {
      if (item is String && item.trim().isNotEmpty) {
        files.add(item.trim());
      }
    }
  }
  final singleFile = data['crewListFile'];
  if (singleFile is String && singleFile.trim().isNotEmpty) {
    if (!files.contains(singleFile.trim())) {
      files.add(singleFile.trim());
    }
  }
  return files;
}
