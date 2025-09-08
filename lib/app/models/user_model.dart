import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String corporateName;
  final String username;
  final String nationality;
  final String role;
  final String status; // Should be one of the enum values
  final bool isEmailVerified;
  final bool hasUploadedDocuments;
  final Timestamp createdAt;
  final Timestamp updatedAt;
  final List<Map<String, dynamic>> documents;

  UserModel({
    required this.uid,
    required this.email,
    required this.corporateName,
    required this.username,
    required this.nationality,
    required this.role,
    required this.status,
    required this.isEmailVerified,
    required this.hasUploadedDocuments,
    required this.createdAt,
    required this.updatedAt,
    required this.documents,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      email: data['email'] ?? '',
      corporateName: data['corporateName'] ?? '',
      username: data['username'] ?? '',
      nationality: data['nationality'] ?? '',
      role: data['role'] ?? 'user',
      status: data['status'] ?? 'pending_email_verification',
      isEmailVerified: data['isEmailVerified'] ?? false,
      hasUploadedDocuments: data['hasUploadedDocuments'] ?? false,
      createdAt: data['createdAt'] ?? Timestamp.now(),
      updatedAt: data['updatedAt'] ?? Timestamp.now(),
      documents: List<Map<String, dynamic>>.from(data['documents'] ?? []),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'corporateName': corporateName,
      'username': username,
      'nationality': nationality,
      'role': role,
      'status': status,
      'isEmailVerified': isEmailVerified,
      'hasUploadedDocuments': hasUploadedDocuments,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'documents': documents,
    };
  }
}