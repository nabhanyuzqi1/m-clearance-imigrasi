class StorageReferenceUtils {
  StorageReferenceUtils._();

  static String canonicalize(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return '';
    }

    if (_startsWithIgnoreCase(trimmed, 'gs://')) {
      final uri = Uri.tryParse(trimmed);
      if (uri != null) {
        final path = uri.pathSegments.join('/');
        if (path.isNotEmpty) {
          return path;
        }
      }
      final slashIndex = trimmed.indexOf('/', 5);
      if (slashIndex != -1 && slashIndex + 1 < trimmed.length) {
        return trimmed.substring(slashIndex + 1);
      }
      return trimmed;
    }

    if (_startsWithIgnoreCase(trimmed, 'http://') ||
        _startsWithIgnoreCase(trimmed, 'https://')) {
      final uri = Uri.tryParse(trimmed);
      if (uri != null) {
        final segments = uri.pathSegments;
        final oIndex = segments.indexOf('o');
        if (oIndex != -1 && oIndex + 1 < segments.length) {
          final encoded = segments[oIndex + 1];
          final decoded = Uri.decodeComponent(encoded);
          if (decoded.isNotEmpty) {
            return decoded;
          }
        }
        if (segments.isNotEmpty) {
          final last = segments.last;
          final questionIndex = last.indexOf('?');
          final segment =
              questionIndex == -1 ? last : last.substring(0, questionIndex);
          if (segment.isNotEmpty) {
            return Uri.decodeComponent(segment);
          }
        }
      }
      return trimmed;
    }

    return trimmed;
  }

  static String fileName(String? reference) {
    final canonical = canonicalize(reference);
    if (canonical.isEmpty) {
      return '';
    }
    final parts = canonical.split('/');
    return parts.isNotEmpty ? parts.last : canonical;
  }

  static bool _startsWithIgnoreCase(String value, String prefix) {
    return value.length >= prefix.length &&
        value.substring(0, prefix.length).toLowerCase() ==
            prefix.toLowerCase();
  }
}
