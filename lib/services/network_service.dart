import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../core/utils/network_utils.dart';

/// Provides the current WiFi IP address and a broadcast stream of
/// connectivity changes so the app can react gracefully when WiFi drops
/// (e.g. auto-stop the server / warn the user) rather than crashing.
///
/// Deliberately does NOT treat `connectivity_plus`'s
/// `ConnectivityResult.wifi` as the source of truth for "is networking
/// available" — that enum only reflects this device acting as a WiFi
/// *client*. When the phone is instead hosting its own mobile hotspot
/// (a common way to use this app: PC connects to the phone's hotspot),
/// the device is never reported as a WiFi client, so that signal would
/// incorrectly read as "WiFi lost" the whole time. Instead, this class
/// uses actual local-IP resolvability as ground truth, which is true in
/// both station mode and hotspot/AP mode.
class NetworkService {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  Timer? _pollTimer;

  Future<String?> getCurrentWifiIp() => NetworkUtils.getWifiIPAddress();

  /// True if either this device is a WiFi client, OR a usable local
  /// IPv4 address can be resolved (covers hotspot/AP mode).
  Future<bool> isConnectedToWifi() async {
    final results = await _connectivity.checkConnectivity();
    if (results.contains(ConnectivityResult.wifi)) return true;
    final ip = await NetworkUtils.getWifiIPAddress();
    return ip != null;
  }

  /// Subscribes to connectivity changes. [onWifiLost] fires when a local
  /// IP address can no longer be resolved (e.g. WiFi was turned off, or
  /// the hotspot was disabled); [onWifiRestored] fires when one becomes
  /// resolvable again. A short interval poll backs up the
  /// `connectivity_plus` event stream so hotspot-mode transitions (which
  /// that stream doesn't reliably surface) are still caught.
  void listen({
    required void Function() onWifiLost,
    required void Function() onWifiRestored,
  }) {
    _subscription?.cancel();
    _pollTimer?.cancel();

    bool? lastKnownHasIp; // null = not yet determined, so no spurious fire

    Future<void> checkAndNotify() async {
      final ip = await NetworkUtils.getWifiIPAddress();
      final hasIp = ip != null;
      if (lastKnownHasIp == true && !hasIp) {
        onWifiLost();
      } else if (lastKnownHasIp == false && hasIp) {
        onWifiRestored();
      }
      lastKnownHasIp = hasIp;
    }

    _subscription = _connectivity.onConnectivityChanged.listen((_) {
      checkAndNotify();
    });
    // Safety-net poll: connectivity_plus does not always emit an event
    // for hotspot enable/disable, so periodically re-verify IP
    // resolvability as well.
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      checkAndNotify();
    });
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _pollTimer?.cancel();
    _pollTimer = null;
  }
}
