import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth/error_codes.dart' as local_auth_error;

class BiometricAuthenticator {
  const BiometricAuthenticator();

  static final LocalAuthentication _auth = LocalAuthentication();

  Future<bool> isSupported() async {
    try {
      final supported = await _auth.isDeviceSupported();
      if (!supported) return false;
      return await _auth.canCheckBiometrics;
    } on Exception {
      return false;
    }
  }

  Future<bool> authenticate({required String reason}) async {
    try {
      final options = const AuthenticationOptions(
        biometricOnly: true,
        stickyAuth: true,
        useErrorDialogs: true,
      );
      return await _auth.authenticate(
        localizedReason: reason,
        options: options,
      );
    } on PlatformException catch (error) {
      if (error.code == local_auth_error.notEnrolled ||
          error.code == local_auth_error.notAvailable ||
          error.code == local_auth_error.passcodeNotSet) {
        return false;
      }
      rethrow;
    }
  }
}
