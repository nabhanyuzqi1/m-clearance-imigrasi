import 'dart:convert';

import 'package:m_clearance_imigrasi/app/localization/localized_strings_data.dart';

void main() {
  const data = localizedStringsData;
  final encoder = const JsonEncoder.withIndent('  ');
  final json = encoder.convert(data);
  print(json);
}
