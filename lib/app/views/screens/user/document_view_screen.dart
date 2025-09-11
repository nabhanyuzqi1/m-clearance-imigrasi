import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../../widgets/custom_app_bar.dart';

class DocumentViewScreen extends StatelessWidget {
  final Uint8List fileData;
  final String fileName;

  const DocumentViewScreen({
    super.key,
    required this.fileData,
    required this.fileName,
  });

  @override
  Widget build(BuildContext context) {
    final isPdf = fileName.toLowerCase().endsWith('.pdf');

    return Scaffold(
      appBar: CustomAppBar(
        titleText: fileName,
      ),
      body: isPdf
          ? SfPdfViewer.memory(fileData)
          : PhotoView(
              imageProvider: MemoryImage(fileData),
            ),
    );
  }
}