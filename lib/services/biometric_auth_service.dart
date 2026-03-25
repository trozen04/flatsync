import 'package:local_auth/local_auth.dart';

class BiometricAuthService {
  final LocalAuthentication _localAuth;

  BiometricAuthService({LocalAuthentication? localAuth})
      : _localAuth = localAuth ?? LocalAuthentication();

  Future<bool> isAvailable() async {
    try {
      final supported = await _localAuth.isDeviceSupported();
      final canCheck = await _localAuth.canCheckBiometrics;
      return supported || canCheck;
    } catch (_) {
      return false;
    }
  }

  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (_) {
      return const [];
    }
  }

  Future<bool> authenticate({
    String reason = 'Authenticate to continue',
  }) async {
    try {
      return await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: true,
          sensitiveTransaction: false,
        ),
      );
    } catch (_) {
      return false;
    }
  }

  String describeBiometrics(List<BiometricType> biometrics) {
    if (biometrics.contains(BiometricType.face)) return 'Face ID / Face Unlock';
    if (biometrics.contains(BiometricType.fingerprint)) return 'Fingerprint';
    if (biometrics.contains(BiometricType.strong)) return 'Biometric';
    if (biometrics.contains(BiometricType.weak)) return 'Biometric';
    return 'Biometric';
  }
}
