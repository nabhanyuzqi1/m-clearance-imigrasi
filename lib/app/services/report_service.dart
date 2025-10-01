import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/report_model.dart';
import 'logging_service.dart';
import 'officer_service.dart';

class ReportService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Stream<List<ReportModel>> getReports() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _firestore
        .collection('reports')
        .where('createdBy', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ReportModel.fromFirestore(doc))
              .toList(),
        );
  }

  Future<ReportModel?> generateReport(
    String type,
    Map<String, dynamic> stats, {
    DateTimeRange? range,
  }) async {
    LoggingService().info('Generating report: type=$type payload=$stats');
    try {
      final user = _auth.currentUser;
      if (user == null) {
        LoggingService().error('No authenticated user found while generating report');
        return null;
      }

      final now = DateTime.now();
      final effectiveRange = range ?? DateTimeRange(start: now, end: now);
      final DateFormat shortFormat = DateFormat('d MMM yyyy');

      final DateTime reportDate =
          type == 'daily' ? effectiveRange.end : effectiveRange.start;
      final String title = type == 'daily'
          ? 'Daily Report - ${shortFormat.format(effectiveRange.end)}'
          : 'Range Report - ${shortFormat.format(effectiveRange.start)} – '
              '${shortFormat.format(effectiveRange.end)}';

      final pdfBytes = await _generatePdf(
        title,
        stats,
        type,
        user.uid,
        range: effectiveRange,
      );
      LoggingService().info('PDF generated (${pdfBytes.length} bytes)');

      final pdfName =
          '${type}_${reportDate.millisecondsSinceEpoch.toString()}.pdf';
      final pdfUrl = await _uploadPdfToStorage(pdfBytes, pdfName);

      final newReport = ReportModel(
        id: '',
        type: type,
        date: reportDate,
        createdBy: user.uid,
        stats: stats,
        pdfUrl: pdfUrl,
        createdAt: DateTime.now(),
        title: title,
      );

      final docRef = await _firestore.collection('reports').add(
            newReport.toFirestore(),
          );

      await OfficerService().logActivity(
        title: title,
        description: 'Generated a ${type.toUpperCase()} report.',
        type: 'reportGenerated',
        iconData: 'analytics',
      );

      return newReport.copyWith(id: docRef.id);
    } catch (error, stackTrace) {
      LoggingService().error('Error generating report', error, stackTrace);
      return null;
    }
  }

  Future<Uint8List> _generatePdf(
    String title,
    Map<String, dynamic> stats,
    String type,
    String officerId, {
    DateTimeRange? range,
  }) async {
    final pdf = pw.Document();

    DateTime parseDate(dynamic value) {
      if (value is String && value.isNotEmpty) return DateTime.parse(value);
      if (value is DateTime) return value;
      return DateTime.now();
    }

    int asInt(dynamic value) {
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    Map<String, dynamic> toMap(dynamic value) =>
        value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

    final arrival = toMap(stats['arrival']);
    final departure = toMap(stats['departure']);
    final accounts = toMap(stats['accounts']);
    final totals = toMap(stats['totals']);
    final rangeMap = toMap(stats['range']);

    final DateFormat dateFormat = DateFormat('d MMM yyyy');
    final DateTime start = range?.start ?? parseDate(rangeMap['start']);
    final DateTime end = range?.end ?? parseDate(rangeMap['end']);

    pdf.addPage(
      pw.Page(
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(
                level: 0,
                child: pw.Text(
                  title,
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                'Generated on: ${DateFormat('d MMM yyyy, HH:mm').format(DateTime.now())}',
                style: const pw.TextStyle(fontSize: 12),
              ),
              pw.Text(
                'Generated by: Officer $officerId',
                style: const pw.TextStyle(fontSize: 12),
              ),
              pw.Text(
                'Data range: ${dateFormat.format(start)} – ${dateFormat.format(end)}',
                style: const pw.TextStyle(fontSize: 12),
              ),
              pw.SizedBox(height: 24),
              pw.Text(
                'Statistics Summary',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Table(
                border: pw.TableBorder.all(),
                children: [
                  pw.TableRow(
                    children: [
                      _tableHeader('Category'),
                      _tableHeader('Pending'),
                      _tableHeader('Approved'),
                      _tableHeader('Rejected'),
                      _tableHeader('Revision'),
                      _tableHeader('Produced'),
                      _tableHeader('Total'),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Text('Arrival'),
                      pw.Text('${asInt(arrival['pending'])}'),
                      pw.Text('${asInt(arrival['approved'])}'),
                      pw.Text('${asInt(arrival['declined'])}'),
                      pw.Text('${asInt(arrival['revision'])}'),
                      pw.Text('${asInt(arrival['produced'])}'),
                      pw.Text('${asInt(arrival['total'])}'),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Text('Departure'),
                      pw.Text('${asInt(departure['pending'])}'),
                      pw.Text('${asInt(departure['approved'])}'),
                      pw.Text('${asInt(departure['declined'])}'),
                      pw.Text('${asInt(departure['revision'])}'),
                      pw.Text('${asInt(departure['produced'])}'),
                      pw.Text('${asInt(departure['total'])}'),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Text('Accounts'),
                      pw.Text('${asInt(accounts['pending'])}'),
                      pw.Text('${asInt(accounts['approved'])}'),
                      pw.Text('${asInt(accounts['rejected'])}'),
                      pw.Text('-'),
                      pw.Text('-'),
                      pw.Text('${asInt(accounts['total'])}'),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 24),
              pw.Text(
                'Overall Totals',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Bullet(text: 'Pending items: ${asInt(totals['pending'])}'),
              pw.Bullet(
                text:
                    'Processed items: ${asInt(totals['approved']) + asInt(totals['rejected'])}',
              ),
              pw.Bullet(
                text: 'Produced certificates: ${asInt(totals['produced'])}',
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _tableHeader(String text) {
    return pw.Text(
      text,
      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      textAlign: pw.TextAlign.center,
    );
  }

  Future<String?> _uploadPdfToStorage(Uint8List pdfBytes, String fileName) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final storageRef = _storage.ref('reports/${user.uid}/$fileName');
      final uploadTask = storageRef.putData(pdfBytes);
      await uploadTask.whenComplete(() => null);
      final downloadUrl = await storageRef.getDownloadURL();
      LoggingService().info('PDF uploaded: $downloadUrl');
      return downloadUrl;
    } catch (error, stackTrace) {
      LoggingService().error('Error uploading PDF', error, stackTrace);
      return null;
    }
  }

  Future<void> downloadReport(String pdfUrl, String fileName) async {
    try {
      await Printing.sharePdf(
        bytes: await _downloadPdfBytes(pdfUrl),
        filename: fileName,
      );
    } catch (error, stackTrace) {
      LoggingService().error('Error downloading report', error, stackTrace);
    }
  }

  Future<Uint8List> _downloadPdfBytes(String url) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      return Uint8List.fromList(response.bodyBytes);
    }
    throw Exception('Failed to download PDF');
  }

  Future<bool> deleteReport(String reportId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final doc = await _firestore.collection('reports').doc(reportId).get();
      if (!doc.exists) return false;

      final report = ReportModel.fromFirestore(doc);
      if (report.createdBy != user.uid) return false;

      if (report.pdfUrl != null) {
        await _storage.refFromURL(report.pdfUrl!).delete();
      }

      await doc.reference.delete();
      return true;
    } catch (error, stackTrace) {
      LoggingService().error('Error deleting report', error, stackTrace);
      return false;
    }
  }
}
