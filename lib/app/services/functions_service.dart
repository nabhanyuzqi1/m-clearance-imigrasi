import 'package:cloud_functions/cloud_functions.dart';

class FunctionsService {
  final FirebaseFunctions _functions;

  FunctionsService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instance; // us-central1 by default

  Future<Map<String, dynamic>> getOfficerDashboardStats() async {
    final callable = _functions.httpsCallable('getOfficerDashboardStats');
    final result = await callable();
    final data = Map<String, dynamic>.from(result.data ?? {});
    return data;
  }

  Future<Map<String, dynamic>> getOfficerStats({
    required DateTime start,
    required DateTime end,
  }) async {
    final callable = _functions.httpsCallable('getOfficerMonthlyStats');
    final result = await callable(<String, dynamic>{
      'startDate': start.toUtc().toIso8601String(),
      'endDate': end.toUtc().toIso8601String(),
    });
    return Map<String, dynamic>.from(result.data ?? {});
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
    final callable = _functions.httpsCallable('officerDecideAccount');
    await callable(<String, dynamic>{
      'targetUid': targetUid,
      'decision': decision,
      if (reason != null && reason.isNotEmpty) 'reason': reason,
    });
  }

  Future<void> setUserRole({
    required String uid,
    required String role, // 'user' | 'officer' | 'admin'
  }) async {
    final callable = _functions.httpsCallable('setUserRole');
    await callable(<String, dynamic>{'uid': uid, 'role': role});
  }

  Future<void> issueEmailVerificationCode() async {
    final callable = _functions.httpsCallable('issueEmailVerificationCode');
    await callable();
  }

  Future<Map<String, dynamic>> issueEmailVerificationCodeEx() async {
    final callable = _functions.httpsCallable('issueEmailVerificationCode');
    final result = await callable();
    return Map<String, dynamic>.from(result.data ?? {});
  }

  Future<void> verifyEmailCode(String code) async {
    final callable = _functions.httpsCallable('verifyEmailCode');
    await callable(<String, dynamic>{'code': code});
  }

  Future<Map<String, dynamic>> generateHistoryPDF(String applicationId) async {
    final callable = _functions.httpsCallable('generateHistoryPDF');
    final result = await callable(<String, dynamic>{
      'applicationId': applicationId,
    });
    return Map<String, dynamic>.from(result.data ?? {});
  }

  Future<Map<String, dynamic>> generateMonthlyReport(
    Map<String, dynamic> stats,
  ) async {
    final callable = _functions.httpsCallable('generateMonthlyReport');
    final result = await callable(<String, dynamic>{'stats': stats});
    return Map<String, dynamic>.from(result.data ?? {});
  }

  Future<void> logOfficerActivity({
    required String title,
    required String description,
    String type = 'activity',
    String? status,
    String? iconData,
    Map<String, dynamic>? metadata,
  }) async {
    final callable = _functions.httpsCallable('logOfficerActivity');
    await callable(<String, dynamic>{
      'title': title,
      'description': description,
      'type': type,
      if (status != null) 'status': status,
      if (iconData != null) 'iconData': iconData,
      if (metadata != null && metadata.isNotEmpty) 'metadata': metadata,
    });
  }

  Future<List<Map<String, dynamic>>> fetchOfficerActivities({
    int limit = 10,
  }) async {
    final callable = _functions.httpsCallable('getOfficerActivities');
    final result = await callable(<String, dynamic>{'limit': limit});
    final data = result.data;
    if (data is List) {
      return data
          .map(
            (item) =>
                item is Map ? Map<String, dynamic>.from(item) : null,
          )
          .whereType<Map<String, dynamic>>()
          .toList();
    }
    return const [];
  }
}
