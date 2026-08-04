import 'dart:io';
import 'package:network_info_plus/network_info_plus.dart';

/// Resolves the device's current WiFi IPv4 address.
///
/// Uses `network_info_plus` first (fast, works reliably on real devices
/// once location/nearby-devices permission is granted on Android 13+),
/// and falls back to scanning [NetworkInterface.list] for a private,
/// non-loopback IPv4 address if the plugin can't resolve one (e.g. on
/// emulators or when permission is denied).
class NetworkUtils {
  NetworkUtils._();

  static final NetworkInfo _networkInfo = NetworkInfo();

  static Future<String?> getWifiIPAddress() async {
    try {
      final ip = await _networkInfo.getWifiIP();
      if (ip != null && ip.isNotEmpty && ip != '0.0.0.0') {
        return ip;
      }
    } catch (_) {
      // Fall through to the interface-scan fallback below.
    }
    return _fallbackInterfaceIp();
  }

  static Future<String?> _fallbackInterfaceIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (_isPrivateIPv4(addr.address)) {
            return addr.address;
          }
        }
      }
    } catch (_) {
      // No network available.
    }
    return null;
  }

  static bool _isPrivateIPv4(String address) {
    return address.startsWith('192.168.') ||
        address.startsWith('10.') ||
        _isClassB172(address);
  }

  static bool _isClassB172(String address) {
    if (!address.startsWith('172.')) return false;
    final parts = address.split('.');
    if (parts.length < 2) return false;
    final second = int.tryParse(parts[1]);
    return second != null && second >= 16 && second <= 31;
  }

  static bool isValidPortAvailable(int port) {
    return port > 0 && port <= 65535;
  }
}
