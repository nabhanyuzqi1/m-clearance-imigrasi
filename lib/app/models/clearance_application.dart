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
  final String? lastPort;
  final String? nextPort;
  final String? date;
  final String? arrivalDate;
  final String? departureDate;
  final String? wniCrew;
  final String? wnaCrew;
  final String? officerName;
  final String? location;
  final List<String> portClearanceFiles;
  final List<String> crewListFiles;
  final List<String> notificationLetterFiles;
  final String? clearanceResultFile;
  final DateTime? clearanceResultGeneratedAt;
  final String? clearanceResultSignedBy;
  final String? clearanceResultSignedByCorporate;
  final DateTime? clearanceResultSentAt;
  final String? clearanceCode;
  final String? shortLink;
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
    this.lastPort,
    this.nextPort,
    this.date,
    this.arrivalDate,
    this.departureDate,
    this.wniCrew,
    this.wnaCrew,
    this.officerName,
    this.location,
    this.shortLink,
    List<String>? portClearanceFiles,
    String? portClearanceFile,
    List<String>? crewListFiles,
    List<String>? notificationLetterFiles,
    String? notificationLetterFile,
    this.clearanceResultFile,
    this.clearanceResultGeneratedAt,
    this.clearanceResultSignedBy,
    this.clearanceResultSignedByCorporate,
    this.clearanceResultSentAt,
    this.clearanceCode,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : portClearanceFiles = _normalizeList(
         explicit: portClearanceFiles,
         single: portClearanceFile,
       ),
       crewListFiles = crewListFiles != null
           ? List<String>.from(crewListFiles)
           : const [],
       notificationLetterFiles = _normalizeList(
         explicit: notificationLetterFiles,
         single: notificationLetterFile,
       ),
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
      lastPort: data['lastPort'],
      nextPort: data['nextPort'],
      date: data['date'],
      arrivalDate: data['arrivalDate'] ?? data['arrival_date'],
      departureDate: data['departureDate'] ?? data['departure_date'],
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
      portClearanceFiles: _resolveFileList(
        data,
        multipleKey: 'portClearanceFiles',
        singleKey: 'portClearanceFile',
      ),
      crewListFiles: _resolveCrewListFiles(data),
      notificationLetterFiles: _resolveFileList(
        data,
        multipleKey: 'notificationLetterFiles',
        singleKey: 'notificationLetterFile',
      ),
      clearanceResultFile: data['clearanceResultFile'],
      clearanceResultGeneratedAt:
          (data['clearanceResultGeneratedAt'] as Timestamp?)?.toDate(),
      clearanceResultSignedBy: data['clearanceResultSignedBy'],
      clearanceResultSignedByCorporate:
          data['clearanceResultSignedByCorporate'],
      clearanceResultSentAt: (data['clearanceResultSentAt'] as Timestamp?)
          ?.toDate(),
      clearanceCode: data['clearanceCode'],
      shortLink: data['shortLink'],
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
      'lastPort': lastPort,
      'nextPort': nextPort,
      'date': date,
      'arrivalDate': arrivalDate,
      'departureDate': departureDate,
      'wniCrew': wniCrew,
      'wnaCrew': wnaCrew,
      'officerName': officerName,
      'location': location,
      'portClearanceFiles': portClearanceFiles,
      'portClearanceFile': portClearanceFile,
      'crewListFiles': crewListFiles,
      'crewListFile': crewListFiles.isNotEmpty ? crewListFiles.first : null,
      'notificationLetterFiles': notificationLetterFiles,
      'notificationLetterFile': notificationLetterFile,
      'clearanceResultFile': clearanceResultFile,
      'clearanceResultGeneratedAt': clearanceResultGeneratedAt,
      'clearanceResultSignedBy': clearanceResultSignedBy,
      'clearanceResultSignedByCorporate': clearanceResultSignedByCorporate,
      'clearanceResultSentAt': clearanceResultSentAt,
      'clearanceCode': clearanceCode,
      'shortLink': shortLink,
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
    String? shortLink,
    String? wniCrew,
    String? wnaCrew,
    List<String>? portClearanceFiles,
    List<String>? crewListFiles,
    List<String>? notificationLetterFiles,
    String? clearanceResultFile,
    DateTime? clearanceResultGeneratedAt,
    DateTime? clearanceResultSentAt,
    String? clearanceResultSignedBy,
    String? clearanceResultSignedByCorporate,
    String? clearanceCode,
    String? port,
    String? lastPort,
    String? nextPort,
    String? date,
    String? arrivalDate,
    String? departureDate,
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
      port: port ?? this.port,
      lastPort: lastPort ?? this.lastPort,
      nextPort: nextPort ?? this.nextPort,
      date: date ?? this.date,
      arrivalDate: arrivalDate ?? this.arrivalDate,
      departureDate: departureDate ?? this.departureDate,
      wniCrew: wniCrew ?? this.wniCrew,
      wnaCrew: wnaCrew ?? this.wnaCrew,
      officerName: officerName ?? this.officerName,
      location: location ?? this.location,
      shortLink: shortLink ?? this.shortLink,
      portClearanceFiles:
          portClearanceFiles ?? List<String>.from(this.portClearanceFiles),
      crewListFiles: crewListFiles ?? List<String>.from(this.crewListFiles),
      notificationLetterFiles:
          notificationLetterFiles ??
          List<String>.from(this.notificationLetterFiles),
      clearanceResultFile: clearanceResultFile ?? this.clearanceResultFile,
      clearanceResultGeneratedAt:
          clearanceResultGeneratedAt ?? this.clearanceResultGeneratedAt,
      clearanceResultSentAt:
          clearanceResultSentAt ?? this.clearanceResultSentAt,
      clearanceResultSignedBy:
          clearanceResultSignedBy ?? this.clearanceResultSignedBy,
      clearanceResultSignedByCorporate:
          clearanceResultSignedByCorporate ??
          this.clearanceResultSignedByCorporate,
      clearanceCode: clearanceCode ?? this.clearanceCode,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  String? get crewListFile =>
      crewListFiles.isNotEmpty ? crewListFiles.first : null;

  String? get portClearanceFile =>
      portClearanceFiles.isNotEmpty ? portClearanceFiles.first : null;

  String? get notificationLetterFile =>
      notificationLetterFiles.isNotEmpty ? notificationLetterFiles.first : null;

  int? get totalCrewCount {
    final wni = int.tryParse(wniCrew ?? '');
    final wna = int.tryParse(wnaCrew ?? '');
    if (wni == null && wna == null) {
      return null;
    }
    return (wni ?? 0) + (wna ?? 0);
  }
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

List<String> _resolveFileList(
  Map<String, dynamic> data, {
  required String multipleKey,
  required String singleKey,
}) {
  final List<String> files = [];
  final rawList = data[multipleKey];
  if (rawList is List) {
    for (final item in rawList) {
      if (item is String && item.trim().isNotEmpty) {
        files.add(item.trim());
      }
    }
  }
  final single = data[singleKey];
  if (single is String && single.trim().isNotEmpty) {
    if (!files.contains(single.trim())) {
      files.add(single.trim());
    }
  }
  return files;
}

List<String> _normalizeList({List<String>? explicit, String? single}) {
  if (explicit != null) {
    return explicit
        .whereType<String>()
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }
  if (single != null && single.trim().isNotEmpty) {
    return [single.trim()];
  }
  return const [];
}
