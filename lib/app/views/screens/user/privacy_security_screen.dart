import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../localization/app_strings.dart';
import '../../../providers/language_provider.dart';

class PrivacySecurityScreen extends StatefulWidget {
  const PrivacySecurityScreen({super.key});

  @override
  State<PrivacySecurityScreen> createState() => _PrivacySecurityScreenState();
}

class _PrivacySecurityScreenState extends State<PrivacySecurityScreen> {
  String _tr(String key) {
    final langCode = Provider.of<LanguageProvider>(context, listen: false).locale.languageCode;
    return AppStrings.tr(context: context, screenKey: 'privacySecurity', stringKey: key, langCode: langCode.toUpperCase());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_tr('title')),
      ),
      body: Center(
        child: Text(_tr('content')),
      ),
    );
  }
}