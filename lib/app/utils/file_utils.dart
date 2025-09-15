import 'dart:core';

String getFileNameFromUrl(String url) {
  try {
    final decodedUrl = Uri.decodeComponent(url);
    final uri = Uri.parse(decodedUrl);
    final pathSegments = uri.pathSegments;
    if (pathSegments.isNotEmpty) {
      final lastSegment = pathSegments.last;
      final parts = lastSegment.split('?');
      final fileName = parts.first.split('/').last;
      
      // Remove the extra folder name from the filename
      final nameParts = fileName.split('%2F');
      if (nameParts.length > 1) {
        return nameParts.last;
      }
      
      return fileName;
    }
  } catch (e) {
    // Return the original URL if parsing fails
    return url;
  }
  return url;
}