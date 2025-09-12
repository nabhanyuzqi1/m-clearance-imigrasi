import 'package:cloud_functions/cloud_functions.dart';

class FunctionsService {
  final FirebaseFunctions _functions;

  FunctionsService({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instance; // us-central1 by default

  Future<Map<String, dynamic>> getOfficerDashboardStats() async {
    final callable = _functions.httpsCallable('getOfficerDashboardStats');
    final result = await callable();
    final data = Map<String, dynamic>.from(result.data ?? {});
    return data;
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
    final result = await callable(<String, dynamic>{'applicationId': applicationId});
    return Map<String, dynamic>.from(result.data ?? {});
  }
}
