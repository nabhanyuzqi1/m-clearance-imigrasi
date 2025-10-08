import 'dart:async';
import 'package:m_clearance_imigrasi/app/services/localization_service.dart';
import 'package:m_clearance_imigrasi/app/services/logging_service.dart';
import 'package:m_clearance_imigrasi/app/localization/localized_strings_data.dart';

/// AppStrings Class
///
/// Kelas ini berfungsi sebagai pusat untuk semua string (teks) dalam aplikasi.
/// Dengan pendekatan ini, kita memisahkan konten teks dari kode UI, yang sangat
/// penting untuk kemudahan maintenance dan proses internasionalisasi (i18n).
/// Sekarang menggunakan LocalizationService untuk integrasi RTDB dengan fallback
/// ke cache dan string lokal.
class AppStrings {
  static final LocalizationService _localizationService = LocalizationService();
  static Map<String, Map<String, Map<String, String>>>? _loadedStrings;
  static bool _isLoading = false;
  static Completer<void>? _loadingCompleter;

  /// Get the current localized strings map (fallback to local)
  static Map<String, Map<String, Map<String, String>>> get localizedStrings =>
      _loadedStrings ?? _localizedStrings;

  /// Load strings asynchronously from RTDB with fallbacks
  static Future<void> loadStrings({bool forceRefresh = false}) async {
    if (_isLoading) {
      // If already loading, wait for completion
      await _loadingCompleter?.future;
      return;
    }

    if (_loadedStrings != null && !forceRefresh) {
      // Already loaded and not forcing refresh
      return;
    }

    _isLoading = true;
    _loadingCompleter = Completer<void>();

    try {
      // Try to fetch from RTDB via LocalizationService
      final remoteStrings = await _localizationService.fetchStringsWithCaching(
        forceRefresh: forceRefresh,
      );

      if (remoteStrings != null) {
        _loadedStrings = remoteStrings;
        LoggingService().debug('[AppStrings] Loaded strings from RTDB/cache');
        return;
      }

      // Fallback to local strings if RTDB/cache failed
      _loadedStrings = Map.from(_localizedStrings);
      LoggingService().debug('[AppStrings] Fallback to local strings');
    } catch (e) {
      // Final fallback to local strings
      _loadedStrings = Map.from(_localizedStrings);
      LoggingService().error(
        '[AppStrings] Error loading strings, using local fallback: $e',
      );
    } finally {
      _isLoading = false;
      _loadingCompleter?.complete();
    }
  }

  /// Map privat yang menyimpan semua terjemahan.
  /// Strukturnya adalah: Bahasa -> NamaLayar -> KunciString -> Teks
  static final Map<String, Map<String, Map<String, String>>> _localizedStrings =
      Map<String, Map<String, Map<String, String>>>.from(localizedStringsData);

  /// Method untuk mendapatkan string yang diterjemahkan.
  ///
  /// [context] diperlukan untuk mengakses BuildContext jika diperlukan di masa depan.
  /// [screenKey] adalah kunci unik untuk setiap layar (misal: 'registrationPending').
  /// [stringKey] adalah kunci untuk string spesifik di dalam layar tersebut (misal: 'title').
  /// [langCode] adalah kode bahasa saat ini (misal: 'EN' atau 'ID').
  static String tr({
    required String screenKey,
    required String stringKey,
    required String langCode,
  }) {
    final code = (langCode).toUpperCase();

    // Try loaded strings first (from RTDB/cache)
    if (_loadedStrings != null) {
      final primary = _loadedStrings![code]?[screenKey]?[stringKey];
      if (primary != null) return primary;
      // Fallback to English in loaded strings
      final en = _loadedStrings!['EN']?[screenKey]?[stringKey];
      if (en != null) return en;
      // Fallback to Indonesian in loaded strings
      final id = _loadedStrings!['ID']?[screenKey]?[stringKey];
      if (id != null) return id;
    }

    // Fallback to local strings
    final primary = _localizedStrings[code]?[screenKey]?[stringKey];
    if (primary != null) return primary;
    // Fallback to English
    final en = _localizedStrings['EN']?[screenKey]?[stringKey];
    if (en != null) return en;
    // Fallback to Indonesian
    final id = _localizedStrings['ID']?[screenKey]?[stringKey];
    if (id != null) return id;

    // Not found
    // For now, return a detailed error message to help with debugging.
    LoggingService().warning(
      'Localization key not found: $screenKey.$stringKey for language $code',
    );
    return '[$screenKey.$stringKey]';
  }
}
