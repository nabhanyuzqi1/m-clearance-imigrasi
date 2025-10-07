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

  Future<Map<String, dynamic>> issueEmailVerificationCodeEx({String? language}) async {
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
}
