import 'package:flutter/material.dart';
import 'app_strings.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    final localizations = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
    assert(
      localizations != null,
      'Could not find an AppLocalizations object above this widget.',
    );
    return localizations!;
  }

  String get languageCode => locale.languageCode;

  String get(String key) {
    final keys = key.split('.');
    if (keys.length != 2) {
      debugPrint(
        'Invalid localization key format: $key. Expected format: screenKey.stringKey',
      );
      return '[$key]';
    }
    return AppStrings.tr(
      screenKey: keys[0],
      stringKey: keys[1],
      langCode: languageCode,
    );
  }
}

class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'id'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    // Load strings asynchronously from RTDB/cache/local
    await AppStrings.loadStrings();
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(AppLocalizationsDelegate old) => true;
}
