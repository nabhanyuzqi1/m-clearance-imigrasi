import 'package:cloud_firestore/cloud_firestore.dart';

enum AccountStatus { pending, verified, rejected }

class UserAccount {
  final String uid;
  final String name;
  final String username;
  final String email;
  final String password;
  final String nibFileName;
  final String ktpFileName;
  final AccountStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserAccount({
    required this.uid,
    required this.name,
    required this.username,
    required this.email,
    required this.password,
    required this.nibFileName,
    required this.ktpFileName,
    this.status = AccountStatus.pending,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  factory UserAccount.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
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
      name: data['corporateName'] ?? data['name'] ?? '',
      username: data['username'] ?? '',
      email: data['email'] ?? '',
      password: data['password'] ?? '',
      nibFileName: data['nibFileName'] ?? '',
      ktpFileName: data['ktpFileName'] ?? '',
      status: status,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    final data = {
      'name': name,
      'username': username,
      'email': email,
      'password': password,
      'nibFileName': nibFileName,
      'ktpFileName': ktpFileName,
      'status': status.index,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };

    print('DEBUG: UserAccount.toFirestore() data: $data');
    print('DEBUG: Status enum value: $status (index: ${status.index})');

    return data;
  }

  UserAccount copyWith({
    String? name,
    String? email,
    AccountStatus? status,
    DateTime? updatedAt,
  }) {
    return UserAccount(
      uid: uid,
      name: name ?? this.name,
      username: username,
      email: email ?? this.email,
      password: password,
      nibFileName: nibFileName,
      ktpFileName: ktpFileName,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}