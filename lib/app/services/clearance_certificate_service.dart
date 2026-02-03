import 'dart:math';
import 'dart:typed_data';

import 'package:barcode/barcode.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/clearance_application.dart';
import 'logging_service.dart';

class ClearanceCertificateService {
  ClearanceCertificateService({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;
  static pw.Font? _robotoRegular;
  static pw.Font? _robotoMedium;
  static pw.Font? _robotoBold;
  static pw.Font? _robotoItalic;

  Future<String?> generateCertificate({
    required ClearanceApplication application,
    required String officerName,
    required String officerCorporateName,
    required String clearanceCode,
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
        clearanceCode: clearanceCode,
        downloadUrl: downloadUrl,
      );

      final metadata = SettableMetadata(
        contentType: 'application/pdf',
        customMetadata: {
          'firebaseStorageDownloadTokens': resolvedToken,
          'applicationId': application.id,
          'generatedAt': DateTime.now().toIso8601String(),
          'generatedBy': sanitizedOfficerName,
          'clearanceCode': clearanceCode,
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
    required String clearanceCode,
    required String downloadUrl,
  }) async {
    final pdf = pw.Document();
    await _ensureFontsLoaded();
    final baseFont = _robotoRegular ?? pw.Font.helvetica();
    final mediumFont = _robotoMedium ?? baseFont;
    final boldFont = _robotoBold ?? pw.Font.helveticaBold();
    final italicFont = _robotoItalic ?? pw.Font.helveticaOblique();

    final baseColor = const PdfColor(0, 0.16862745098, 0.3568627451);
    final lightBackground = PdfColor.fromInt(0xfff4f7fb);
    final metaBackground = PdfColor.fromInt(0xffe6edf4);
    final detailBorder = PdfColor.fromInt(0xffd4dde8);
    final secondaryTextColor = PdfColor.fromInt(0xff3b536d);
    final signatureBorder = PdfColor.fromInt(0xffa6bcd0);
    final italicTextColor = PdfColor.fromInt(0xff2c4762);

    final immigrationLogo = await _tryLoadAssetImage([
      'assets/images/immigration_logo.png',
      'assets/images/logo.png',
    ]);
    final applicationLogo = await _tryLoadAssetImage([
      'assets/images/isam_logo.png',
      'assets/images/logo.png',
    ]);

    final formatter = DateFormat('dd MMMM yyyy');
    final approvalDate = formatter.format(DateTime.now());
    final submittedDate = formatter.format(application.createdAt);
    final arrivalDate = _resolveDate(application.arrivalDate) ??
        (application.type == ApplicationType.kedatangan
            ? _resolveDate(application.date)
            : null);
    final departureDate = _resolveDate(application.departureDate) ??
        (application.type == ApplicationType.keberangkatan
            ? _resolveDate(application.date)
            : null);
    final destinationPort =
        _resolveText(application.location) ??
        _resolveText(application.nextPort) ??
        _resolveText(application.port) ??
        '-';
    final additionalNote = _resolveText(application.notes) ?? '-';
    final crewDetail = _resolveCrew(application);

    pdf.addPage(
      pw.Page(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          theme: pw.ThemeData.withFont(
            base: baseFont,
            bold: boldFont,
            italic: italicFont,
          ),
        ),
        build: (context) {
          return pw.Container(
            decoration: pw.BoxDecoration(
              borderRadius: pw.BorderRadius.circular(16),
              border: pw.Border.all(color: baseColor, width: 1.2),
            ),
            padding: const pw.EdgeInsets.all(28),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                _buildHeaderRow(
                  baseColor: baseColor,
                  clearanceCode: clearanceCode,
                  downloadUrl: downloadUrl,
                  immigrationLogo: immigrationLogo,
                  appLogo: applicationLogo,
                  mediumFont: mediumFont,
                ),
                pw.SizedBox(height: 18),
                _buildTitleSection(baseColor),
                pw.SizedBox(height: 16),
                _buildMetaBar(
                  backgroundColor: metaBackground,
                  textColor: secondaryTextColor,
                  accentColor: baseColor,
                  application: application,
                  submittedDate: submittedDate,
                  approvalDate: approvalDate,
                  mediumFont: mediumFont,
                ),
                pw.SizedBox(height: 20),
                pw.Container(
                  padding: const pw.EdgeInsets.all(16),
                  decoration: pw.BoxDecoration(
                    color: lightBackground,
                    borderRadius: pw.BorderRadius.circular(12),
                  ),
                  child: _buildDetailsGrid(
                    clearanceCode: clearanceCode,
                    agentName: application.agentName,
                    shipName: application.shipName,
                    flag: application.flag,
                    destinationPort: destinationPort,
                    arrivalDate: arrivalDate ?? '-',
                    departureDate: departureDate ?? '-',
                    crewDetail: crewDetail,
                    additionalNote: additionalNote,
                    applicationId: application.id,
                    detailBorder: detailBorder,
                    detailTextColor: secondaryTextColor,
                  ),
                ),
                pw.SizedBox(height: 22),
                _buildAssuranceBlock(baseColor),
                pw.SizedBox(height: 28),
                _buildSignatureSection(
                  application: application,
                  officerName: officerName,
                  officerCorporateName: officerCorporateName,
                  baseColor: baseColor,
                  borderColor: signatureBorder,
                  secondaryTextColor: secondaryTextColor,
                  italicTextColor: italicTextColor,
                ),
                pw.SizedBox(height: 12),
                pw.Text(
                  'Dokumen ini ditandatangani secara digital melalui sistem M Clearance iSam.',
                  style: pw.TextStyle(
                    fontSize: 10,
                    color: italicTextColor,
                    fontStyle: pw.FontStyle.italic,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  Future<void> _ensureFontsLoaded() async {
    if (_robotoRegular != null) return;
    try {
      _robotoRegular = await _loadFont('assets/fonts/Roboto-Regular.ttf');
      _robotoMedium = await _loadFont('assets/fonts/Roboto-Medium.ttf');
      _robotoBold = await _loadFont('assets/fonts/Roboto-Bold.ttf');
      _robotoItalic = await _loadFont('assets/fonts/Roboto-Italic.ttf');
    } catch (e, stackTrace) {
      LoggingService().warning(
        'Failed to load Roboto fonts for clearance certificate, falling back to defaults.',
        e,
        stackTrace,
      );
    }
  }

  Future<pw.Font> _loadFont(String assetPath) async {
    final data = await rootBundle.load(assetPath);
    return pw.Font.ttf(data);
  }

  Future<pw.ImageProvider?> _tryLoadAssetImage(List<String> candidates) async {
    Object? lastError;
    StackTrace? lastStackTrace;
    for (final path in candidates) {
      try {
        final data = await rootBundle.load(path);
        return pw.MemoryImage(data.buffer.asUint8List());
      } catch (e, stackTrace) {
        lastError = e;
        lastStackTrace = stackTrace;
      }
    }
    if (lastError != null) {
      LoggingService().debug(
        'Logo assets not found for any candidate: ${candidates.join(', ')}',
        lastError,
        lastStackTrace,
      );
    }
    return null;
  }

  pw.Widget _buildHeaderRow({
    required PdfColor baseColor,
    required String clearanceCode,
    required String downloadUrl,
    pw.ImageProvider? immigrationLogo,
    pw.ImageProvider? appLogo,
    required pw.Font mediumFont,
  }) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: _buildLogoBlock(
            label: 'KANTOR IMIGRASI',
            logo: immigrationLogo,
            baseColor: baseColor,
          ),
        ),
        pw.Expanded(
          child: pw.Column(
            mainAxisSize: pw.MainAxisSize.min,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              if (appLogo != null)
                pw.Container(
                  height: 48,
                  width: 120,
                  child: pw.Image(appLogo, fit: pw.BoxFit.contain),
                )
              else
                pw.Container(
                  height: 48,
                  width: 120,
                  alignment: pw.Alignment.center,
                  decoration: pw.BoxDecoration(
                    borderRadius: pw.BorderRadius.circular(12),
                    border: pw.Border.all(color: baseColor, width: 1),
                  ),
                  child: pw.Text(
                    'iSam',
                    style: pw.TextStyle(
                      color: baseColor,
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              pw.SizedBox(height: 6),
              pw.Text(
                'M CLEARANCE ISAM',
                style: pw.TextStyle(
                  font: mediumFont,
                  fontSize: 11,
                  color: baseColor,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
        pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              borderRadius: pw.BorderRadius.circular(12),
              border: pw.Border.all(color: baseColor, width: 1),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'KODE CLEARANCE',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 10,
                    color: baseColor,
                    letterSpacing: 1.4,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  clearanceCode,
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 12.5,
                    color: baseColor,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Container(
                  width: 82,
                  height: 82,
                  decoration: pw.BoxDecoration(
                    borderRadius: pw.BorderRadius.circular(10),
                    border: pw.Border.all(color: baseColor, width: 1),
                  ),
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.BarcodeWidget(
                    barcode: Barcode.qrCode(),
                    data: downloadUrl,
                    drawText: false,
                    color: baseColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  pw.Widget _buildLogoBlock({
    required String label,
    required PdfColor baseColor,
    pw.ImageProvider? logo,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (logo != null)
          pw.Container(
            height: 50,
            width: 120,
            child: pw.Image(logo, fit: pw.BoxFit.contain),
          )
        else
          pw.Container(
            height: 50,
            width: 120,
            alignment: pw.Alignment.center,
            decoration: pw.BoxDecoration(
              borderRadius: pw.BorderRadius.circular(12),
              border: pw.Border.all(color: baseColor, width: 1),
            ),
            child: pw.Text(
              label,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                color: baseColor,
                fontWeight: pw.FontWeight.bold,
                fontSize: 8,
              ),
            ),
          ),
        pw.SizedBox(height: 6),
        pw.Text(
          label,
          style: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            fontSize: 10,
            color: baseColor,
          ),
        ),
      ],
    );
  }

  pw.Widget _buildTitleSection(PdfColor baseColor) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(
          'SURAT KETERANGAN CLEARANCE',
          style: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            fontSize: 18,
            color: baseColor,
            letterSpacing: 1.2,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'CLEARANCE DOCUMENT',
          style: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            fontSize: 11,
            color: baseColor,
            letterSpacing: 1.1,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Container(
          height: 2,
          width: 120,
          color: baseColor,
        ),
      ],
    );
  }

  pw.Widget _buildMetaBar({
    required PdfColor backgroundColor,
    required PdfColor textColor,
    required PdfColor accentColor,
    required ClearanceApplication application,
    required String submittedDate,
    required String approvalDate,
    required pw.Font mediumFont,
  }) {
    final typeLabel = application.type == ApplicationType.kedatangan
        ? 'Kedatangan / Arrival'
        : 'Keberangkatan / Departure';

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: pw.BoxDecoration(
        borderRadius: pw.BorderRadius.circular(12),
        color: backgroundColor,
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          _buildMetaItem(
            label: 'Jenis Clearance',
            value: typeLabel,
            labelColor: accentColor,
            valueColor: textColor,
            mediumFont: mediumFont,
          ),
          _buildMetaItem(
            label: 'Diajukan',
            value: submittedDate,
            labelColor: accentColor,
            valueColor: textColor,
            mediumFont: mediumFont,
          ),
          _buildMetaItem(
            label: 'Disetujui',
            value: approvalDate,
            labelColor: accentColor,
            valueColor: textColor,
            mediumFont: mediumFont,
          ),
        ],
      ),
    );
  }

  pw.Widget _buildMetaItem({
    required String label,
    required String value,
    required PdfColor labelColor,
    required PdfColor valueColor,
    required pw.Font mediumFont,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label.toUpperCase(),
          style: pw.TextStyle(
            fontSize: 8,
            color: labelColor,
            font: mediumFont,
            letterSpacing: 1.1,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            fontSize: 10.5,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  pw.Widget _buildDetailsGrid({
    required String clearanceCode,
    required String agentName,
    required String shipName,
    required String flag,
    required String destinationPort,
    required String arrivalDate,
    required String departureDate,
    required String crewDetail,
    required String additionalNote,
    required String applicationId,
    required PdfColor detailBorder,
    required PdfColor detailTextColor,
  }) {
    final details = <List<String>>[
      ['Nomor Clearance', clearanceCode],
      ['Nama Kapal', shipName],
      ['Bendera Kapal', flag],
      ['Agen Kapal', agentName],
      ['Pelabuhan Tujuan', destinationPort],
      ['Tanggal Kedatangan', arrivalDate],
      ['Tanggal Keberangkatan', departureDate],
      ['Jumlah Awak Kapal', crewDetail],
      ['Keterangan Tambahan', additionalNote],
      ['Referensi Permohonan', applicationId],
    ];

    final rows = <pw.TableRow>[];
    for (var i = 0; i < details.length; i += 2) {
      final first = details[i];
      final second =
          i + 1 < details.length ? details[i + 1] : <String>['', ''];
      rows.add(
        pw.TableRow(
          children: [
            _buildDetailCell(first[0], first[1], detailBorder, detailTextColor),
            _buildDetailCell(second[0], second[1], detailBorder, detailTextColor),
          ],
        ),
      );
    }

    return pw.Table(
      border: pw.TableBorder(
        horizontalInside: pw.BorderSide(color: PdfColors.white, width: 8),
        verticalInside: pw.BorderSide(color: PdfColors.white, width: 8),
      ),
      children: rows,
    );
  }

  pw.Widget _buildDetailCell(
    String label,
    String value,
    PdfColor borderColor,
    PdfColor textColor,
  ) {
    if (label.isEmpty && value.isEmpty) {
      return pw.Container();
    }
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border.all(color: borderColor, width: 1),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: textColor,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: 10.5, color: PdfColors.black),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildAssuranceBlock(PdfColor baseColor) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        borderRadius: pw.BorderRadius.circular(12),
        border: pw.Border.all(color: baseColor, width: 0.8),
      ),
      child: pw.Text(
        'Direktorat Jenderal Imigrasi menyatakan bahwa permohonan clearance ini telah '
        'diverifikasi sesuai peraturan yang berlaku dan telah diterbitkan secara resmi '
        'melalui sistem M Clearance iSam.',
        style: pw.TextStyle(
          fontSize: 10.5,
          color: baseColor,
          height: 1.4,
        ),
        textAlign: pw.TextAlign.justify,
      ),
    );
  }

  pw.Widget _buildSignatureSection({
    required ClearanceApplication application,
    required String officerName,
    required String officerCorporateName,
    required PdfColor baseColor,
    required PdfColor borderColor,
    required PdfColor secondaryTextColor,
    required PdfColor italicTextColor,
  }) {
    final agentCorporate =
        _resolveText(application.agentName) ?? 'Perwakilan Agen';

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: _buildSignatureBlock(
            title: 'Digital Signature Agen',
            name: application.agentName,
            description: agentCorporate,
            baseColor: baseColor,
            borderColor: borderColor,
            secondaryTextColor: secondaryTextColor,
            italicTextColor: italicTextColor,
          ),
        ),
        pw.SizedBox(width: 18),
        pw.Expanded(
          child: _buildSignatureBlock(
            title: 'Digital Signature Officer Imigrasi',
            name: officerName,
            description: officerCorporateName,
            baseColor: baseColor,
            borderColor: borderColor,
            secondaryTextColor: secondaryTextColor,
            italicTextColor: italicTextColor,
            withSeal: true,
          ),
        ),
      ],
    );
  }

  pw.Widget _buildSignatureBlock({
    required String title,
    required String name,
    required String description,
    required PdfColor baseColor,
    required PdfColor borderColor,
    required PdfColor secondaryTextColor,
    required PdfColor italicTextColor,
    bool withSeal = false,
  }) {
    final resolvedName = name.trim().isEmpty ? '-' : name.trim();
    final resolvedDescription =
        description.trim().isEmpty ? '-' : description.trim();
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        borderRadius: pw.BorderRadius.circular(12),
        border: pw.Border.all(color: borderColor, width: 0.8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 10.5,
              color: baseColor,
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Container(
            height: 32,
            decoration: pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(
                  color: borderColor,
                  width: 0.8,
                ),
              ),
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            resolvedName,
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 11.5,
              color: baseColor,
            ),
          ),
          pw.Text(
            resolvedDescription,
            style: pw.TextStyle(
              fontSize: 10,
              color: secondaryTextColor,
            ),
          ),
          if (withSeal) ...[
            pw.SizedBox(height: 10),
            pw.Text(
              'Ditandatangani secara digital',
              style: pw.TextStyle(
                fontSize: 9,
                color: italicTextColor,
                fontStyle: pw.FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String? _resolveDate(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return value.trim();
  }

  String? _resolveText(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    const blacklist = {'n/a', 'na', '-', 'tidak tersedia', 'not available'};
    if (blacklist.contains(trimmed.toLowerCase())) return null;
    return trimmed;
  }

  String _resolveCrew(ClearanceApplication application) {
    final total = application.totalCrewCount;
    final wni = application.wniCrew?.trim();
    final wna = application.wnaCrew?.trim();
    final parts = <String>[];
    if (wni != null && wni.isNotEmpty) {
      parts.add('WNI $wni');
    }
    if (wna != null && wna.isNotEmpty) {
      parts.add('WNA $wna');
    }
    if (total != null) {
      if (parts.isEmpty) {
        return '$total';
      }
      return '$total (${parts.join(' | ')})';
    }
    if (parts.isEmpty) {
      return '-';
    }
    return parts.join(' | ');
  }

  String _generateDownloadToken() {
    final random = Random.secure();
    final values = List<int>.generate(32, (_) => random.nextInt(256));
    return values.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }
}
