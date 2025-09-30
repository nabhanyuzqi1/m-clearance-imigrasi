import 'dart:math';
import 'dart:typed_data';

import 'package:barcode/barcode.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/clearance_application.dart';
import 'logging_service.dart';

class ClearanceCertificateService {
  ClearanceCertificateService({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;

  Future<String?> generateCertificate({
    required ClearanceApplication application,
    required String officerName,
    required String officerCorporateName,
    String? downloadToken,
  }) async {
    try {
      final sanitizedOfficerName = officerName.trim().isEmpty
          ? 'Immigration Officer'
          : officerName.trim();
      final sanitizedCorporateName = officerCorporateName.trim().isEmpty
          ? sanitizedOfficerName
          : officerCorporateName.trim();

      final storagePath =
          'applications/${application.id}/clearance_certificate.pdf';
      final resolvedToken = downloadToken ?? _generateDownloadToken();
      final rootRef = _storage.ref();
      final bucket = rootRef.bucket;
      final encodedPath = Uri.encodeComponent(storagePath);
      final downloadUrl =
          'https://firebasestorage.googleapis.com/v0/b/$bucket/o/$encodedPath?alt=media&token=$resolvedToken';

      LoggingService().info(
        'Generating clearance certificate for application ${application.id}',
      );

      final pdfBytes = await _buildCertificatePdf(
        application: application,
        officerName: sanitizedOfficerName,
        officerCorporateName: sanitizedCorporateName,
        downloadUrl: downloadUrl,
      );

      final metadata = SettableMetadata(
        contentType: 'application/pdf',
        customMetadata: {
          'firebaseStorageDownloadTokens': resolvedToken,
          'applicationId': application.id,
          'generatedAt': DateTime.now().toIso8601String(),
          'generatedBy': sanitizedOfficerName,
        },
      );

      final pdfRef = rootRef.child(storagePath);
      await pdfRef.putData(pdfBytes, metadata);

      LoggingService().info(
        'Clearance certificate uploaded for application ${application.id}',
      );

      return downloadUrl;
    } catch (e, stackTrace) {
      LoggingService().error(
        'Failed to generate clearance certificate for ${application.id}',
        e,
        stackTrace,
      );
      return null;
    }
  }

  Future<Uint8List> _buildCertificatePdf({
    required ClearanceApplication application,
    required String officerName,
    required String officerCorporateName,
    required String downloadUrl,
  }) async {
    final pdf = pw.Document();
    final formatter = DateFormat('dd MMMM yyyy');
    final applicationDate = application.createdAt;
    final formattedApplicationDate = formatter.format(applicationDate);
    final approvalDate = formatter.format(DateTime.now());
    final applicationType =
        application.type == ApplicationType.kedatangan ? 'Arrival' : 'Departure';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 32),
        build: (context) {
          return pw.Stack(
            children: [
              pw.Positioned(
                top: 0,
                right: 0,
                child: pw.Container(
                  width: 100,
                  height: 100,
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(width: 1, color: PdfColors.blueGrey),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.BarcodeWidget(
                    barcode: Barcode.qrCode(),
                    data: downloadUrl,
                    color: PdfColors.blueGrey900,
                  ),
                ),
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'IMMIGRATION CLEARANCE CERTIFICATE',
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blueGrey800,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Official Record of Vessel Clearance Verification',
                    style: pw.TextStyle(
                      fontSize: 11,
                      color: PdfColors.blueGrey600,
                    ),
                  ),
                  pw.SizedBox(height: 24),
                  pw.Text(
                    'Application Information',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blueGrey800,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  _buildRow('Application ID', application.id),
                  _buildRow('Vessel Name', application.shipName),
                  _buildRow('Flag', application.flag),
                  _buildRow('Application Type', applicationType),
                  _buildRow('Agent Name', application.agentName),
                  if (application.location != null &&
                      application.location!.isNotEmpty)
                    _buildRow('Port / Location', application.location!),
                  if (application.date != null && application.date!.isNotEmpty)
                    _buildRow('Declared Voyage Date', application.date!),
                  _buildRow('Application Submitted', formattedApplicationDate),
                  _buildRow('Approved On', approvalDate),
                  pw.SizedBox(height: 24),
                  pw.Text(
                    'Clearance Confirmation',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blueGrey800,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'The Directorate General of Immigration hereby certifies that '
                    'the above-mentioned application has been reviewed and approved. '
                    'All mandatory documents have been verified and meet the clearance '
                    'requirements stipulated for maritime operations.',
                    textAlign: pw.TextAlign.justify,
                    style: pw.TextStyle(fontSize: 11, height: 1.4),
                  ),
                  pw.SizedBox(height: 16),
                  pw.Container(
                    width: double.infinity,
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.blueGrey300, width: 1),
                      borderRadius: pw.BorderRadius.circular(8),
                      color: PdfColors.blueGrey50,
                    ),
                    child: pw.Text(
                      'This certificate contains a secure QR code linking to the '
                      'digitally signed clearance record stored within the official '
                      'Immigration system.',
                      style: pw.TextStyle(fontSize: 10.5, color: PdfColors.blueGrey700),
                    ),
                  ),
                  pw.SizedBox(height: 32),
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(
                        child: _buildSignatureBlock(
                          title: 'Applicant / Agent',
                          name: application.agentName,
                          description: 'Digital acknowledgement via M-Clearance',
                        ),
                      ),
                      pw.SizedBox(width: 24),
                      pw.Expanded(
                        child: _buildSignatureBlock(
                          title: 'Immigration Officer',
                          name: officerName,
                          description: officerCorporateName,
                          showSeal: true,
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 12),
                  pw.Text(
                    'Document Reference: ${application.id}-${DateTime.now().millisecondsSinceEpoch}',
                    style: pw.TextStyle(fontSize: 8, color: PdfColors.blueGrey500),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 140,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blueGrey700,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(fontSize: 11, color: PdfColors.blueGrey900),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildSignatureBlock({
    required String title,
    required String name,
    required String description,
    bool showSeal = false,
  }) {
    final signatureLine = '______________________________';
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blueGrey700,
          ),
        ),
        pw.SizedBox(height: 12),
        if (showSeal)
          pw.Text(
            'Digitally Signed by Directorate General of Immigration',
            style: pw.TextStyle(
              fontSize: 10,
              fontStyle: pw.FontStyle.italic,
              color: PdfColors.blueGrey600,
            ),
          ),
        pw.SizedBox(height: showSeal ? 8 : 16),
        pw.Text(
          signatureLine,
          style: pw.TextStyle(color: PdfColors.blueGrey300),
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          name,
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blueGrey900,
          ),
        ),
        pw.Text(
          description,
          style: pw.TextStyle(fontSize: 10, color: PdfColors.blueGrey600),
        ),
      ],
    );
  }

  String _generateDownloadToken() {
    final random = Random.secure();
    final values = List<int>.generate(32, (_) => random.nextInt(256));
    return values.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }
}
