class BiometricAuthenticator {
  const BiometricAuthenticator();

  Future<bool> isSupported() async => false;

  Future<bool> authenticate({required String reason}) async => false;
}
