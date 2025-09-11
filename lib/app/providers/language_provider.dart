import 'package:flutter/material.dart';

class LanguageProvider with ChangeNotifier {
  Locale _locale = const Locale('en');

  Locale get locale => _locale;

  void setLocale(Locale locale) {
    debugPrint('[LanguageProvider] setLocale called: old=${_locale.languageCode}, new=${locale.languageCode}');
    if (_locale != locale) {
      _locale = locale;
      debugPrint('[LanguageProvider] Locale changed to: ${_locale.languageCode}');
      notifyListeners();
    } else {
      debugPrint('[LanguageProvider] Locale unchanged: ${_locale.languageCode}');
    }
  }
}