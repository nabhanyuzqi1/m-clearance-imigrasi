import 'package:logger/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

class LoggingService {
  static final LoggingService _instance = LoggingService._internal();
  late Logger _logger;

  factory LoggingService() {
    return _instance;
  }

  LoggingService._internal() {
    _initializeLogger();
  }

  void _initializeLogger() {
    final isProduction = !kDebugMode; // In production, kDebugMode is false

    _logger = Logger(
      filter: isProduction ? ProductionFilter() : DevelopmentFilter(),
      printer: PrettyPrinter(
        methodCount: 2,
        errorMethodCount: 8,
        lineLength: 120,
        colors: !isProduction, // Colors in development
        printEmojis: true,
        dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart, // Include timestamps
      ),
      output: ConsoleOutput(), // Console output
    );
  }

  void debug(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.d(message, error: error, stackTrace: stackTrace);
  }

  void info(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.i(message, error: error, stackTrace: stackTrace);
  }

  void warning(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.w(message, error: error, stackTrace: stackTrace);
  }

  void error(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.e(message, error: error, stackTrace: stackTrace);

    // Report to Crashlytics in production (only on mobile platforms)
    if (!kDebugMode && error != null && !kIsWeb) {
      FirebaseCrashlytics.instance.recordError(error, stackTrace, reason: message);
    }
  }

  // Custom error reporting for key operations
  void reportCustomError(String operation, dynamic error, [StackTrace? stackTrace]) {
    final message = 'Custom error in $operation: $error';
    _logger.e(message, error: error, stackTrace: stackTrace);

    // Report to Crashlytics in production (only on mobile platforms)
    if (!kDebugMode && !kIsWeb) {
      FirebaseCrashlytics.instance.recordError(error, stackTrace, reason: message);
    }
  }

  // For file output, can be extended later
  // void logToFile(String message) {
  //   // Implement file logging if needed
  // }
}

// Custom filters for dev/prod
class DevelopmentFilter extends LogFilter {
  @override
  bool shouldLog(LogEvent event) {
    return true; // Log everything in development
  }
}

class ProductionFilter extends LogFilter {
  @override
  bool shouldLog(LogEvent event) {
    return event.level.index >= Level.warning.index; // Only warning and above in production
  }
}