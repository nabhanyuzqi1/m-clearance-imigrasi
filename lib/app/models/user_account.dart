import 'package:cloud_firestore/cloud_firestore.dart';

enum AccountStatus { pending, verified, rejected }

String _stringOrEmpty(dynamic value) {
  if (value == null) return '';
  if (value is String) return value;
  return value.toString();
}

class UserAccount {
  final String uid;
  final String name;
  final String corporateName;
  final String fullName;
  final String username;
  final String email;
  final String password;
  final String nibFileName;
  final String ktpFileName;
  final String? profileImageUrl;
  final AccountStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserAccount({
    required this.uid,
    required this.name,
    this.corporateName = '',
    this.fullName = '',
    required this.username,
    required this.email,
    required this.password,
    required this.nibFileName,
    required this.ktpFileName,
    this.profileImageUrl,
    this.status = AccountStatus.pending,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  factory UserAccount.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final corporateNameRaw = _stringOrEmpty(data['corporateName']);
    final fullNameRaw = _stringOrEmpty(data['fullName']);
    final usernameRaw = _stringOrEmpty(data['username']);
    final nameRaw = _stringOrEmpty(data['name']);
    final fallbackName = corporateNameRaw.isNotEmpty
        ? corporateNameRaw
        : fullNameRaw.isNotEmpty
        ? fullNameRaw
        : nameRaw.isNotEmpty
        ? nameRaw
        : usernameRaw;
    final profileImageRaw = _stringOrEmpty(
      data['profileImageUrl'] ?? data['photoURL'],
    );
    AccountStatus status;
    if (data['status'] is int) {
      status = AccountStatus.values[data['status']];
    } else if (data['status'] is String) {
      switch (data['status']) {
        case 'approved':
          status = AccountStatus.verified;
          break;
        case 'pending_email_verification':
        case 'pending_documents':
        case 'pending_approval':
          status = AccountStatus.pending;
          break;
        case 'rejected':
          status = AccountStatus.rejected;
          break;
        default:
          status = AccountStatus.pending;
      }
    } else {
      status = AccountStatus.pending;
    }
    return UserAccount(
      uid: doc.id,
      name: fallbackName,
      corporateName: corporateNameRaw.isNotEmpty
          ? corporateNameRaw
          : fallbackName,
      fullName: fullNameRaw.isNotEmpty ? fullNameRaw : fallbackName,
      username: usernameRaw,
      email: _stringOrEmpty(data['email']),
      password: _stringOrEmpty(data['password']),
      nibFileName: _stringOrEmpty(data['nibFileName']),
      ktpFileName: _stringOrEmpty(data['ktpFileName']),
      profileImageUrl: profileImageRaw.isNotEmpty ? profileImageRaw : null,
      status: status,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    final data = <String, dynamic>{
      'name': name,
      'corporateName': corporateName,
      'fullName': fullName,
      'username': username,
      'email': email,
      'password': password,
      'nibFileName': nibFileName,
      'ktpFileName': ktpFileName,
      'status': status.index,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };

    if (profileImageUrl != null) {
      data['profileImageUrl'] = profileImageUrl;
    }

    print('DEBUG: UserAccount.toFirestore() data: $data');
    print('DEBUG: Status enum value: $status (index: ${status.index})');

    return data;
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'name': name,
      'corporateName': corporateName,
      'fullName': fullName,
      'username': username,
      'email': email,
      'password': password,
      'nibFileName': nibFileName,
      'ktpFileName': ktpFileName,
      'profileImageUrl': profileImageUrl,
      'photoURL': profileImageUrl,
      'status': status.index,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory UserAccount.fromJson(Map<String, dynamic> json) {
    final statusRaw = json['status'];
    AccountStatus parsedStatus;
    if (statusRaw is int &&
        statusRaw >= 0 &&
        statusRaw < AccountStatus.values.length) {
      parsedStatus = AccountStatus.values[statusRaw];
    } else {
      parsedStatus = AccountStatus.pending;
    }

    DateTime parseDate(dynamic value) {
      if (value is String) {
        return DateTime.tryParse(value) ?? DateTime.now();
      }
      if (value is int) {
        return DateTime.fromMillisecondsSinceEpoch(value);
      }
      return DateTime.now();
    }

    final nameRaw = _stringOrEmpty(json['name']);
    final corporateNameRaw = _stringOrEmpty(json['corporateName']);
    final fullNameRaw = _stringOrEmpty(json['fullName']);
    final usernameRaw = _stringOrEmpty(json['username']);
    final fallbackName = nameRaw.isNotEmpty
        ? nameRaw
        : corporateNameRaw.isNotEmpty
        ? corporateNameRaw
        : fullNameRaw.isNotEmpty
        ? fullNameRaw
        : usernameRaw;
    final resolvedCorporateName = corporateNameRaw.isNotEmpty
        ? corporateNameRaw
        : fallbackName;
    final resolvedFullName = fullNameRaw.isNotEmpty
        ? fullNameRaw
        : fallbackName;
    final profileImage = _stringOrEmpty(
      json['profileImageUrl'] ?? json['photoURL'],
    );

    return UserAccount(
      uid: _stringOrEmpty(json['uid']),
      name: fallbackName,
      corporateName: resolvedCorporateName,
      fullName: resolvedFullName,
      username: usernameRaw,
      email: _stringOrEmpty(json['email']),
      password: _stringOrEmpty(json['password']),
      nibFileName: _stringOrEmpty(json['nibFileName']),
      ktpFileName: _stringOrEmpty(json['ktpFileName']),
      profileImageUrl: profileImage.isNotEmpty ? profileImage : null,
      status: parsedStatus,
      createdAt: parseDate(json['createdAt']),
      updatedAt: parseDate(json['updatedAt']),
    );
  }

  UserAccount copyWith({
    String? name,
    String? corporateName,
    String? fullName,
    String? email,
    String? profileImageUrl,
    AccountStatus? status,
    DateTime? updatedAt,
  }) {
    return UserAccount(
      uid: uid,
      name: name ?? this.name,
      corporateName: corporateName ?? this.corporateName,
      fullName: fullName ?? this.fullName,
      username: username,
      email: email ?? this.email,
      password: password,
      nibFileName: nibFileName,
      ktpFileName: ktpFileName,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}
