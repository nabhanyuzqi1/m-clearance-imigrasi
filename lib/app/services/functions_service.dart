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
    required String decision, // 'approved' | 'rejected'
    String? note,
  }) async {
    final callable = _functions.httpsCallable('officerDecideAccount');
    await callable(<String, dynamic>{
      'targetUid': targetUid,
      'decision': decision,
      if (note != null && note.isNotEmpty) 'note': note,
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

  Future<void> verifyEmailCode(String code) async {
    final callable = _functions.httpsCallable('verifyEmailCode');
    await callable(<String, dynamic>{'code': code});
  }
}
