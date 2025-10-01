import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../localization/app_localizations.dart';
import '../../../providers/language_provider.dart';
import '../../../services/logging_service.dart';
import '../../widgets/custom_app_bar.dart';

class LanguageSelectionScreen extends StatelessWidget {
  const LanguageSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    LoggingService().debug('Building LanguageSelectionScreen');
    final languageProvider = Provider.of<LanguageProvider>(context);
    final langCode = languageProvider.locale.languageCode;
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = screenWidth * 0.06; // 6% of screen width
    final maxWidth = screenWidth > 600
        ? 600.0
        : double.infinity; // Constrain width on tablets

    String tr(String key) =>
        AppLocalizations.of(context).get('userProfile.$key');

    return Scaffold(
      appBar: CustomAppBar(titleText: tr('select_language'), centerTitle: true),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: ListView(
              children: [
                _buildLanguageOption(
                  context,
                  languageName: 'English',
                  languageCode: 'en',
                  currentLanguageCode: langCode,
                  onTap: () {
                    LoggingService().info('Setting language to English (en)');
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
                    LoggingService().info(
                      'Setting language to Indonesian (id)',
                    );
                    languageProvider.setLocale(const Locale('id'));
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
        ),
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
    final colorScheme = Theme.of(context).colorScheme;
    final isSelected = currentLanguageCode == languageCode;
    return ListTile(
      title: Text(languageName),
      trailing: isSelected
          ? Icon(Icons.check, color: colorScheme.primary)
          : null,
      onTap: onTap,
    );
  }
}
