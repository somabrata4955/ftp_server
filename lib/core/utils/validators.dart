import '../constants/app_constants.dart';

/// Simple, dependency-free validators used by the settings screen and by
/// the FTP command processor to reject malformed input early.
class Validators {
  Validators._();

  static String? validatePort(String? value) {
    if (value == null || value.trim().isEmpty) return 'Port is required';
    final port = int.tryParse(value.trim());
    if (port == null) return 'Port must be a number';
    if (port < AppConstants.minPort || port > AppConstants.maxPort) {
      return 'Port must be between ${AppConstants.minPort} and ${AppConstants.maxPort}';
    }
    return null;
  }

  static String? validateUsername(String? value, {required bool anonymous}) {
    if (anonymous) return null;
    if (value == null || value.trim().isEmpty) return 'Username is required';
    if (value.length < 3) return 'Username must be at least 3 characters';
    return null;
  }

  static String? validatePassword(String? value, {required bool anonymous}) {
    if (anonymous) return null;
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 4) return 'Password must be at least 4 characters';
    return null;
  }

  /// Rejects raw command path arguments that contain NUL bytes or other
  /// control characters, which are a common exploitation vector.
  static bool isSafeCommandArgument(String arg) {
    for (final codeUnit in arg.codeUnits) {
      if (codeUnit == 0 || (codeUnit < 32 && codeUnit != 9)) {
        return false;
      }
    }
    return true;
  }
}
