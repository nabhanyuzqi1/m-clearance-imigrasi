import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/language_provider.dart';
import '../../../localization/app_strings.dart';

class LanguageSelectionScreen extends StatelessWidget {
  const LanguageSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final langCode = languageProvider.locale.languageCode;

    String tr(String key) => AppStrings.tr(
      context: context,
      screenKey: 'userProfile',
      stringKey: key,
      langCode: langCode.toUpperCase(),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('select_language')),
      ),
      body: ListView(
        children: [
          _buildLanguageOption(
            context,
            languageName: 'English',
            languageCode: 'en',
            currentLanguageCode: langCode,
            onTap: () {
              languageProvider.setLocale(const Locale('en'));
              Navigator.pop(context);
            },
          ),
          _buildLanguageOption(
            context,
            languageName: 'Bahasa Indonesia',
            languageCode: 'id',
            currentLanguageCode: langCode,
            onTap: () {
              languageProvider.setLocale(const Locale('id'));
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageOption(
    BuildContext context, {
    required String languageName,
    required String languageCode,
    required String currentLanguageCode,
    required VoidCallback onTap,
  }) {
    final isSelected = currentLanguageCode == languageCode;
    return ListTile(
      title: Text(languageName),
      trailing: isSelected ? const Icon(Icons.check, color: Colors.blue) : null,
      onTap: onTap,
    );
  }
}