import 'package:cloud_functions/cloud_functions.dart';
import 'logging_service.dart';

class FunctionsService {
  final FirebaseFunctions _functions;

  FunctionsService({FirebaseFunctions? functions})
    : _functions =
          functions ??
          FirebaseFunctions.instanceFor(region: 'asia-southeast1') {
    LoggingService().info(
      'FunctionsService initialized with asia-southeast1 region',
    );
  }

  Future<Map<String, dynamic>> getOfficerDashboardStats() async {
    LoggingService().info(
      'Attempting to call getOfficerDashboardStats function',
    );
    try {
      final callable = _functions.httpsCallable('getOfficerDashboardStats');
      LoggingService().info('Callable created for getOfficerDashboardStats');
      final result = await callable();
      LoggingService().info('getOfficerDashboardStats call successful');
      final data = Map<String, dynamic>.from(result.data ?? {});
      return data;
    } catch (e) {
      LoggingService().error('getOfficerDashboardStats failed', e);
      return {};
    }
  }

  Future<Map<String, dynamic>> getOfficerStats({
    required DateTime start,
    required DateTime end,
  }) async {
    try {
      final callable = _functions.httpsCallable('getOfficerMonthlyStats');
      final result = await callable(<String, dynamic>{
        'startDate': start.toUtc().toIso8601String(),
        'endDate': end.toUtc().toIso8601String(),
      });
      return Map<String, dynamic>.from(result.data ?? {});
    } catch (e) {
      LoggingService().error('getOfficerStats failed', e);
      return {};
    }
  }

  Future<Map<String, dynamic>> getOfficerMonthlyStats() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999);
    return getOfficerStats(start: start, end: end);
  }

  Future<void> officerDecideAccount({
    required String targetUid,
    required String decision, // 'approved' | 'rejected' | 'revision_requested'
    String? reason,
  }) async {
    LoggingService().info(
      'Attempting to call officerDecideAccount for uid: $targetUid, decision: $decision',
    );
    try {
      final callable = _functions.httpsCallable('officerDecideAccount');
      LoggingService().info('Callable created for officerDecideAccount');
      await callable(<String, dynamic>{
        'targetUid': targetUid,
        'decision': decision,
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      });
      LoggingService().info('officerDecideAccount call successful');
    } catch (e) {
      LoggingService().error('officerDecideAccount failed', e);
      rethrow;
    }
  }

  Future<void> setUserRole({
    required String uid,
    required String role, // 'user' | 'officer' | 'admin'
  }) async {
    try {
      final callable = _functions.httpsCallable('setUserRole');
      await callable(<String, dynamic>{'uid': uid, 'role': role});
    } catch (e) {
      LoggingService().error('setUserRole failed', e);
      rethrow;
    }
  }

  Future<void> issueEmailVerificationCode({String? language}) async {
    try {
      final callable = _functions.httpsCallable('issueEmailVerificationCode');
      await callable(<String, dynamic>{
        if (language != null && language.isNotEmpty)
          'language': language.toLowerCase(),
      });
    } catch (e) {
      LoggingService().error('issueEmailVerificationCode failed', e);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> issueEmailVerificationCodeEx({
    String? language,
  }) async {
    try {
      final callable = _functions.httpsCallable('issueEmailVerificationCode');
      final result = await callable(<String, dynamic>{
        if (language != null && language.isNotEmpty)
          'language': language.toLowerCase(),
      });
      return Map<String, dynamic>.from(result.data ?? {});
    } catch (e) {
      LoggingService().error('issueEmailVerificationCodeEx failed', e);
      return {};
    }
  }

  Future<void> sendPasswordResetEmailLink({
    required String email,
    String? language,
  }) async {
    try {
      final callable = _functions.httpsCallable('sendPasswordResetEmailLink');
      await callable(<String, dynamic>{
        'email': email,
        if (language != null && language.isNotEmpty)
          'language': language.toLowerCase(),
      });
    } catch (e) {
      if (e is FirebaseFunctionsException) {
        LoggingService().error(
          'sendPasswordResetEmailLink failed: ${e.code} ${e.message} details=${e.details}',
          e,
        );
      } else {
        LoggingService().error('sendPasswordResetEmailLink failed', e);
      }
      rethrow;
    }
  }

  Future<void> verifyEmailCode(String code) async {
    try {
      final callable = _functions.httpsCallable('verifyEmailCode');
      await callable(<String, dynamic>{'code': code});
    } catch (e) {
      LoggingService().error('verifyEmailCode failed', e);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> generateHistoryPDF(String applicationId) async {
    try {
      final callable = _functions.httpsCallable('generateHistoryPDF');
      final result = await callable(<String, dynamic>{
        'applicationId': applicationId,
      });
      return Map<String, dynamic>.from(result.data ?? {});
    } catch (e) {
      LoggingService().error('generateHistoryPDF failed', e);
      return {};
    }
  }

  Future<Map<String, dynamic>> generateMonthlyReport(
    Map<String, dynamic> stats,
  ) async {
    try {
      final callable = _functions.httpsCallable('generateMonthlyReport');
      final result = await callable(<String, dynamic>{'stats': stats});
      return Map<String, dynamic>.from(result.data ?? {});
    } catch (e) {
      LoggingService().error('generateMonthlyReport failed', e);
      return {};
    }
  }

  Future<Map<String, dynamic>> sendClearanceCertificate({
    required String applicationId,
    String? officerName,
    String? officerCorporateName,
    bool generateOnly = false,
  }) async {
    try {
      final callable = _functions.httpsCallable('sendClearanceCertificate');
      final payload = <String, dynamic>{
        'applicationId': applicationId,
        if (officerName != null && officerName.trim().isNotEmpty)
          'officerName': officerName.trim(),
        if (officerCorporateName != null &&
            officerCorporateName.trim().isNotEmpty)
          'officerCorporateName': officerCorporateName.trim(),
        if (generateOnly) 'generateOnly': true,
      };
      final result = await callable(payload);

      final data = Map<String, dynamic>.from(result.data ?? {});

      // If clearance was sent successfully, generate a short link
      if (!generateOnly && data['ok'] == true && data['downloadUrl'] != null) {
        try {
          final shortUrl = await createShortUrl(data['downloadUrl']);
          data['shortLink'] = shortUrl;
          LoggingService().info(
            'Short link generated for clearance: $shortUrl',
          );
        } catch (shortLinkError) {
          LoggingService().warning(
            'Failed to generate short link',
            shortLinkError,
          );
          // Don't fail the whole operation if short link generation fails
        }
      }

      return data;
    } catch (e) {
      LoggingService().error('sendClearanceCertificate failed', e);
      rethrow;
    }
  }

  Future<void> logOfficerActivity({
    required String title,
    required String description,
    String type = 'activity',
    String? status,
    String? iconData,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final callable = _functions.httpsCallable('logOfficerActivity');
      await callable(<String, dynamic>{
        'title': title,
        'description': description,
        'type': type,
        if (status != null) 'status': status,
        if (iconData != null) 'iconData': iconData,
        if (metadata != null && metadata.isNotEmpty) 'metadata': metadata,
      });
    } catch (e) {
      LoggingService().error('logOfficerActivity failed', e);
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchOfficerActivities({
    int limit = 10,
  }) async {
    LoggingService().info('Calling getOfficerActivities with limit: $limit');
    try {
      final callable = _functions.httpsCallable('getOfficerActivities');
      final result = await callable(<String, dynamic>{'limit': limit});
      LoggingService().info('getOfficerActivities call successful');
      final data = result.data;
      if (data is List) {
        return data
            .map((item) => item is Map ? Map<String, dynamic>.from(item) : null)
            .whereType<Map<String, dynamic>>()
            .toList();
      }
      return const [];
    } catch (e) {
      LoggingService().error('getOfficerActivities call failed', e);
      return [];
    }
  }

  /// Create a short URL for a clearance document (Officer function)
  Future<String> createShortUrl(String longUrl) async {
    LoggingService().info('Creating short URL for document');
    try {
      // Use the createShortUrl function that should be available in Firebase Functions
      // This function stores the mapping in Firestore and returns a short URL
      final callable = _functions.httpsCallable('createShortUrl');
      final result = await callable(<String, dynamic>{'longUrl': longUrl});

      final data = Map<String, dynamic>.from(result.data ?? {});
      final shortUrl = data['shortUrl'] as String?;

      if (shortUrl != null && shortUrl.isNotEmpty) {
        LoggingService().info('Short URL created successfully: $shortUrl');
        return shortUrl;
      } else {
        throw Exception('Invalid response: shortUrl not found');
      }
    } catch (e) {
      LoggingService().error('createShortUrl failed', e);
      rethrow;
    }
  }

  /// Resolve a short URL to get the original document URL (User function)
  Future<String> resolveShortUrl(String shortId) async {
    LoggingService().info('Resolving short URL: $shortId');
    try {
      // Use HTTP call to the Firebase HTTP function
      // This is different from httpsCallable - it's a direct HTTP request
      final response = await _functions
          .httpsCallable('resolveShortUrlHTTP')
          .call(<String, dynamic>{'id': shortId});

      final data = Map<String, dynamic>.from(response.data ?? {});
      final originalUrl = data['originalUrl'] as String?;

      if (originalUrl != null && originalUrl.isNotEmpty) {
        LoggingService().info('Short URL resolved successfully');
        return originalUrl;
      } else {
        throw Exception('Document not found or expired');
      }
    } catch (e) {
      LoggingService().error('resolveShortUrl failed', e);
      rethrow;
    }
  }

  /// Generate and share short link for a clearance document (Officer function)
  Future<String> generateClearanceShortLink(String applicationId) async {
    LoggingService().info(
      'Generating clearance short link for application: $applicationId',
    );
    try {
      // First generate/send the clearance certificate
      final certificateResult = await sendClearanceCertificate(
        applicationId: applicationId,
      );

      final documentUrl = certificateResult['downloadUrl'] as String?;
      if (documentUrl == null || documentUrl.isEmpty) {
        throw Exception('Failed to generate clearance document');
      }

      // Create short URL for the document
      final shortUrl = await createShortUrl(documentUrl);

      LoggingService().info('Clearance short link generated: $shortUrl');
      return shortUrl;
    } catch (e) {
      LoggingService().error('generateClearanceShortLink failed', e);
      rethrow;
    }
  }
}
