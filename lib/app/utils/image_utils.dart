import 'dart:typed_data';

import 'package:image/image.dart' as img;
import '../services/logging_service.dart';

/// Resize image data while preserving aspect ratio. Returns the original data
/// if decoding fails or the image is already within the [maxDimension].
Future<Uint8List> minifyImageData(
  Uint8List data, {
  int maxDimension = 1600,
  String? fileExtension,
}) async {
  try {
    final image = img.decodeImage(data);
    if (image == null) {
      return data;
    }

    final needsResize =
        image.width > maxDimension || image.height > maxDimension;
    if (!needsResize) {
      return data;
    }

    final bool isLandscape = image.width >= image.height;
    final resized = img.copyResize(
      image,
      width: isLandscape ? maxDimension : null,
      height: isLandscape ? null : maxDimension,
      interpolation: img.Interpolation.average,
    );

    final format = (fileExtension ?? 'jpg').toLowerCase();
    switch (format) {
      case 'png':
        return Uint8List.fromList(img.encodePng(resized));
      case 'jpg':
      case 'jpeg':
      default:
        return Uint8List.fromList(img.encodeJpg(resized, quality: 85));
    }
  } catch (e) {
    LoggingService().error('Failed to minify image data', e);
    return data;
  }
}
