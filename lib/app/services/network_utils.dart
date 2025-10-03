import 'dart:async';

/// Network utilities for handling retries and error management
class NetworkUtils {
  static const int _maxRetries = 3;
  static const Duration _initialDelay = Duration(seconds: 1);

  /// Execute a network operation with retry logic
  static Future<T> executeWithRetry<T>(
    Future<T> Function() operation, {
    int maxRetries = _maxRetries,
    Duration initialDelay = _initialDelay,
    bool Function(Exception)? shouldRetry,
  }) async {
    int attempt = 0;
    Duration delay = initialDelay;

    while (attempt < maxRetries) {
      try {
        return await operation();
      } catch (e) {
        attempt++;

        if (attempt >= maxRetries) {
          rethrow;
        }

        // Check if we should retry this type of error
        if (shouldRetry != null && !shouldRetry(e as Exception)) {
          rethrow;
        }

        print('Network operation failed (attempt $attempt/$maxRetries): $e');
        print('Retrying in ${delay.inSeconds} seconds...');

        await Future.delayed(delay);
        delay *= 2; // Exponential backoff
      }
    }

    throw Exception('Network operation failed after $maxRetries attempts');
  }

  /// Check if an error is retryable
  static bool isRetryableError(dynamic error) {
    if (error is Exception) {
      final errorString = error.toString().toLowerCase();
      // Retry on network errors, timeouts, but not on authentication errors
      return errorString.contains('network') ||
             errorString.contains('timeout') ||
             errorString.contains('connection') ||
             errorString.contains('unavailable') ||
             errorString.contains('server');
    }
    return false;
  }

  /// Wrap a network operation with timeout
  static Future<T> withTimeout<T>(
    Future<T> operation,
    Duration timeout,
  ) async {
    return operation.timeout(
      timeout,
      onTimeout: () => throw TimeoutException('Operation timed out after ${timeout.inSeconds} seconds'),
    );
  }
}

/// Custom exception for network operations
class NetworkException implements Exception {
  final String message;
  final dynamic originalError;
  final bool isRetryable;

  NetworkException(this.message, {this.originalError, this.isRetryable = false});

  @override
  String toString() => 'NetworkException: $message';
}

/// Timeout exception
class TimeoutException implements Exception {
  final String message;

  TimeoutException(this.message);

  @override
  String toString() => 'TimeoutException: $message';
}