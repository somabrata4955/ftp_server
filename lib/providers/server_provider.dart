import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/utils/logger.dart';
import '../models/ftp_client_model.dart';
import '../models/server_config_model.dart';
import '../services/ftp/ftp_server_service.dart';
import '../services/network_service.dart';
import '../services/notification_service.dart';
import '../services/permission_service.dart';
import 'settings_provider.dart';
import 'transfer_provider.dart';

/// The user-facing server state, driving the Home screen: running/stopped,
/// uptime, connected clients, WiFi IP + FTP URL, and any last error.
///
/// This is the glue between the pure-Dart [FtpServerService] and the
/// Flutter widget tree — it owns the [ChangeNotifier] contract, wires the
/// service's callbacks into [TransferProvider]/[AppLogger], drives the
/// foreground-service notification, and reacts to WiFi connectivity
/// changes so the server degrades gracefully instead of crashing.
class ServerProvider extends ChangeNotifier {
  final SettingsProvider settingsProvider;
  final TransferProvider transferProvider;
  final NotificationService _notificationService;
  final NetworkService _networkService;
  final PermissionService _permissionService;

  late FtpServerService _ftpServerService;
  Timer? _uptimeTicker;

  ServerProvider({
    required this.settingsProvider,
    required this.transferProvider,
    required NotificationService notificationService,
    required NetworkService networkService,
    required PermissionService permissionService,
  })  : _notificationService = notificationService,
        _networkService = networkService,
        _permissionService = permissionService {
    _ftpServerService = FtpServerService(
      initialConfig: settingsProvider.config,
      onClientsChanged: _onClientsChanged,
      onTransferChanged: transferProvider.onTransferUpdate,
      onServerStopped: _onServerStopped,
    );
    _networkService.listen(
      onWifiLost: _onWifiLost,
      onWifiRestored: _onWifiRestored,
    );
  }

  bool get isRunning => _ftpServerService.isRunning;
  List<FtpClientModel> _clients = [];
  List<FtpClientModel> get clients => _clients;
  Duration get uptime => _ftpServerService.uptime;

  String? _wifiIp;
  String? get wifiIp => _wifiIp;

  String? get ftpUrl {
    if (_wifiIp == null) return null;
    final config = settingsProvider.config;
    return 'ftp://$_wifiIp:${config.port}';
  }

  String? _lastError;
  String? get lastError => _lastError;

  bool _wifiWarningActive = false;
  bool get wifiWarningActive => _wifiWarningActive;

  /// Requests permissions, resolves the current WiFi IP, and starts the
  /// server socket + persistent foreground notification.
  Future<bool> startServer() async {
    _lastError = null;
    try {
      final granted = await _permissionService.requestAllRequiredPermissions();
      if (!granted) {
        _lastError =
            'Required permissions were not granted. Please enable them in Settings.';
        notifyListeners();
        return false;
      }

      // NOTE: we deliberately do NOT gate on
      // `_networkService.isConnectedToWifi()` here. That check reflects
      // whether this device is a WiFi *client*, which is false when the
      // phone is instead hosting its own mobile hotspot (a very common
      // way to use this app — PC connects to the phone's hotspot). The
      // real signal that matters is simply: can we resolve a usable
      // local IPv4 address? That works in both station mode (phone
      // joins a router) and AP mode (phone hosts the hotspot).
      _wifiIp = await _networkService.getCurrentWifiIp();
      if (_wifiIp == null) {
        _lastError =
            'Could not determine a local IP address. Make sure WiFi is on '
            '(either connected to a network, or your phone\'s hotspot is '
            'enabled) and try again.';
        notifyListeners();
        return false;
      }

      _ftpServerService.updateConfig(settingsProvider.config);
      _ftpServerService.setAdvertisedIp(_wifiIp);
      await _ftpServerService.start();

      await _notificationService.startForegroundService(
        title: 'FTP Server Running',
        description: 'ftp://$_wifiIp:${settingsProvider.config.port}',
      );

      _startUptimeTicker();
      notifyListeners();
      return true;
    } on Exception catch (e) {
      _lastError = e.toString().replaceFirst('FtpServerBindException: ', '');
      AppLogger.error('Failed to start server: $_lastError');
      notifyListeners();
      return false;
    }
  }

  Future<void> stopServer() async {
    await _ftpServerService.stop();
    await _notificationService.stopForegroundService();
    _stopUptimeTicker();
    notifyListeners();
  }

  Future<void> disconnectClient(String clientId) =>
      _ftpServerService.disconnectClient(clientId);

  void _onClientsChanged(List<FtpClientModel> clients) {
    _clients = clients;
    notifyListeners();
  }

  void _onServerStopped() {
    _clients = [];
    _stopUptimeTicker();
    notifyListeners();
  }

  void _startUptimeTicker() {
    _uptimeTicker?.cancel();
    _uptimeTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      notifyListeners();
    });
  }

  void _stopUptimeTicker() {
    _uptimeTicker?.cancel();
    _uptimeTicker = null;
  }

  Future<void> _onWifiLost() async {
    if (!isRunning) return;
    _wifiWarningActive = true;
    AppLogger.warning('WiFi connection lost — stopping FTP server');
    await stopServer();
    _lastError = 'WiFi connection was lost. The server has been stopped.';
    notifyListeners();
  }

  void _onWifiRestored() {
    _wifiWarningActive = false;
    notifyListeners();
  }

  Future<void> refreshWifiIp() async {
    _wifiIp = await _networkService.getCurrentWifiIp();
    _ftpServerService.setAdvertisedIp(_wifiIp);
    notifyListeners();
  }

  /// Re-applies the latest settings to the running server (e.g. toggling
  /// read-only mode or hidden files takes effect immediately without a
  /// restart; port/credentials changes require a restart).
  void applyLatestConfig(ServerConfigModel config) {
    _ftpServerService.updateConfig(config);
  }

  @override
  void dispose() {
    _stopUptimeTicker();
    _networkService.dispose();
    super.dispose();
  }
}
