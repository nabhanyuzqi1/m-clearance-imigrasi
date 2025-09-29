import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:universal_html/html.dart' as html;

import '../../../services/auth_service.dart';
import '../../../services/logging_service.dart';

class DocumentViewScreen extends StatefulWidget {
  final String? storagePath;
  final Uint8List? fileData;
  final String? fileName;

  const DocumentViewScreen({
    super.key,
    this.storagePath,
    this.fileData,
    this.fileName,
  });

  @override
  State<DocumentViewScreen> createState() => _DocumentViewScreenState();
}

class _DocumentViewScreenState extends State<DocumentViewScreen> {
  bool _isLoading = true;
  Uint8List? _documentData;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initialiseDocument();
  }

  Future<void> _initialiseDocument() async {
    if (widget.fileData != null) {
      setState(() {
        _documentData = widget.fileData;
        _isLoading = false;
      });
      return;
    }

    final path = widget.storagePath;
    if (path == null || path.isEmpty) {
      setState(() {
        _error = 'No document reference provided.';
        _isLoading = false;
      });
      return;
    }

    await _loadDocumentFromStorage(path);
  }

  Future<void> _loadDocumentFromStorage(String reference) async {
    try {
      final data = await AuthService().downloadFileData(reference);
      if (!mounted) return;
      if (data == null || data.isEmpty) {
        setState(() {
          _error = 'Unable to download document.';
          _isLoading = false;
        });
        return;
      }
      setState(() {
        _documentData = data;
        _isLoading = false;
      });
    } catch (e) {
      LoggingService().error('Error loading document $reference', e);
      if (!mounted) return;
      setState(() {
        _error = 'Error loading document: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _downloadDocument() async {
    if (_documentData == null) return;

    if (kIsWeb) {
      _downloadDocumentForWeb();
    } else {
      _downloadDocumentForMobile();
    }
  }

  Future<void> _downloadDocumentForMobile() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/${widget.fileName ?? 'document'}';
      final file = File(filePath);
      await file.writeAsBytes(_documentData!);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Document downloaded to $filePath')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error downloading document: $e')));
    }
  }

  void _downloadDocumentForWeb() {
    final blob = html.Blob([_documentData]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', widget.fileName ?? 'document')
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.fileName ?? 'Document Viewer'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _isLoading || _documentData == null
                ? null
                : _downloadDocument,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(child: Text(_error!));
    }

    if (_documentData == null) {
      return const Center(child: Text('No document to display.'));
    }

    final isPdf =
        (widget.fileName?.toLowerCase().endsWith('.pdf') ?? false) ||
        (widget.storagePath?.toLowerCase().endsWith('.pdf') ?? false);

    if (isPdf) {
      return PDFView(pdfData: _documentData);
    } else {
      return Center(child: Image.memory(_documentData!));
    }
  }
}
