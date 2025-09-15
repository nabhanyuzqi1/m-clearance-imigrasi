import 'package:cloud_firestore/cloud_firestore.dart';

class ReportModel {
  final String id;
  final String type; // 'daily' or 'monthly'
  final DateTime date;
  final String createdBy;
  final Map<String, dynamic> stats;
  final String? pdfUrl;
  final DateTime createdAt;
  final String title;

  ReportModel({
    required this.id,
    required this.type,
    required this.date,
    required this.createdBy,
    required this.stats,
    this.pdfUrl,
    required this.createdAt,
    required this.title,
  });

  // Factory constructor to create from Firestore document
  factory ReportModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ReportModel(
      id: doc.id,
      type: data['type'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
      createdBy: data['createdBy'] ?? '',
      stats: data['stats'] ?? {},
      pdfUrl: data['pdfUrl'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      title: data['title'] ?? '',
    );
  }

  // Convert to Map for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'type': type,
      'date': Timestamp.fromDate(date),
      'createdBy': createdBy,
      'stats': stats,
      'pdfUrl': pdfUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'title': title,
    };
  }

  // Copy with method for updates
  ReportModel copyWith({
    String? id,
    String? type,
    DateTime? date,
    String? createdBy,
    Map<String, dynamic>? stats,
    String? pdfUrl,
    DateTime? createdAt,
    String? title,
  }) {
    return ReportModel(
      id: id ?? this.id,
      type: type ?? this.type,
      date: date ?? this.date,
      createdBy: createdBy ?? this.createdBy,
      stats: stats ?? this.stats,
      pdfUrl: pdfUrl ?? this.pdfUrl,
      createdAt: createdAt ?? this.createdAt,
      title: title ?? this.title,
    );
  }
}