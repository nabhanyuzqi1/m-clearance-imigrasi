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
    return UserAccount(
      uid: doc.id,
      name: data['name'] ?? '',
      username: data['username'] ?? '',
      email: data['email'] ?? '',
      password: data['password'] ?? '',
      nibFileName: data['nibFileName'] ?? '',
      ktpFileName: data['ktpFileName'] ?? '',
      status: AccountStatus.values[data['status'] ?? 0],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
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