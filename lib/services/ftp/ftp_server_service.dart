import 'dart:async';
import 'dart:io';

import '../../core/utils/logger.dart';
import '../../models/ftp_client_model.dart';
import '../../models/server_config_model.dart';
import '../../models/transfer_model.dart';
import 'ftp_session_handler.dart';

/// Thrown when the server fails to bind, e.g. because the port is already
/// in use by another process.
class FtpServerBindException implements Exception {
  final String message;
  FtpServerBindException(this.message);
  @override
  String toString() => 'FtpServerBindException: $message';
}

/// Top-level FTP server: owns the [ServerSocket], accepts inbound client
/// connections and spins up one [FtpSessionHandler] per client, and
/// exposes the running state (uptime, connected clients) to the rest of
/// the app via simple callbacks so the Provider layer can react to it.
///
/// This class deliberately has no Flutter/UI dependencies — it is a pure
/// Dart service, keeping the architecture's networking layer testable and
/// decoupled (Repository/Service pattern).
class FtpServerService {
  ServerSocket? _serverSocket;
  ServerConfigModel _config;
  DateTime? _startedAt;
  final Map<String, FtpSessionHandler> _sessions = {};
  final Map<String, FtpClientModel> _clients = {};

  final void Function(List<FtpClientModel> clients)? onClientsChanged;
  final void Function(TransferModel transfer)? onTransferChanged;
  final void Function() onServerStopped;

  FtpServerService({
    required ServerConfigModel initialConfig,
    this.onClientsChanged,
    this.onTransferChanged,
    required this.onServerStopped,
  }) : _config = initialConfig;

  bool get isRunning => _serverSocket != null;
  DateTime? get startedAt => _startedAt;
  int get connectedClientCount => _clients.length;
  List<FtpClientModel> get connectedClients => _clients.values.toList();

  /// The externally-reachable IP address (e.g. the phone's WiFi or
  /// hotspot IP) to advertise in PASV replies. The server socket itself
  /// still binds to the wildcard address so it accepts connections on
  /// any interface — this is purely what we *tell the client* to
  /// connect back to, which must be a real routable address, not
  /// `0.0.0.0`.
  String? _advertisedIp;
  void setAdvertisedIp(String? ip) {
    _advertisedIp = ip;
  }

  void updateConfig(ServerConfigModel config) {
    _config = config;
  }

  ServerConfigModel get config => _config;

  /// Starts listening on [InternetAddress.anyIPv4] at [_config.port].
  ///
  /// Throws [FtpServerBindException] on port conflicts or permission
  /// errors so the caller (provider) can surface a friendly message.
  Future<void> start() async {
    if (isRunning) {
      AppLogger.warning('Start requested but server is already running');
      return;
    }
    if (_config.rootDirectory.isEmpty) {
      throw FtpServerBindException('Root directory is not configured');
    }
    try {
      final server = await ServerSocket.bind(
        InternetAddress.anyIPv4,
        _config.port,
        shared: false,
      );
      _serverSocket = server;
      _startedAt = DateTime.now();
      AppLogger.success('FTP server started on port ${_config.port}');

      server.listen(
        _onClientConnected,
        onError: (Object error) {
          AppLogger.error('Server socket error: $error');
        },
        onDone: () {
          AppLogger.info('Server socket closed');
        },
        cancelOnError: false,
      );
    } on SocketException catch (e) {
      final message = e.osError?.message ?? e.message;
      if (message.toLowerCase().contains('address already in use') ||
          e.osError?.errorCode == 98 ||
          e.osError?.errorCode == 48) {
        throw FtpServerBindException(
            'Port ${_config.port} is already in use. Choose another port.');
      }
      if (message.toLowerCase().contains('permission')) {
        throw FtpServerBindException(
            'Permission denied binding to port ${_config.port}.');
      }
      throw FtpServerBindException('Failed to start server: $message');
    }
  }

  void _onClientConnected(Socket socket) {
    try {
      socket.setOption(SocketOption.tcpNoDelay, true);
    } catch (_) {
      // Not all platforms support this; safe to ignore.
    }

    final handler = FtpSessionHandler(
      controlSocket: socket,
      getConfig: () => _config,
      getAdvertisedIp: () => _advertisedIp,
      onClientChanged: _handleClientChanged,
      onClientDisconnected: _handleClientDisconnected,
      onTransferChanged: (transfer) => onTransferChanged?.call(transfer),
    );
    _sessions[handler.clientId] = handler;
    handler.start();
  }

  void _handleClientChanged(FtpClientModel client) {
    _clients[client.id] = client;
    onClientsChanged?.call(connectedClients);
  }

  void _handleClientDisconnected(String clientId) {
    _clients.remove(clientId);
    _sessions.remove(clientId);
    onClientsChanged?.call(connectedClients);
  }

  /// Forcibly disconnects a specific client (used by the "Clients" screen).
  Future<void> disconnectClient(String clientId) async {
    final session = _sessions[clientId];
    await session?.forceDisconnect();
  }

  /// Stops the server: closes all active sessions and the listening
  /// socket. Safe to call even if the server isn't running.
  Future<void> stop() async {
    if (!isRunning) return;
    AppLogger.info('Stopping FTP server...');
    for (final session in List<FtpSessionHandler>.from(_sessions.values)) {
      await session.forceDisconnect();
    }
    _sessions.clear();
    _clients.clear();
    await _serverSocket?.close();
    _serverSocket = null;
    _startedAt = null;
    onClientsChanged?.call(const []);
    onServerStopped();
    AppLogger.info('FTP server stopped');
  }

  Duration get uptime =>
      _startedAt == null ? Duration.zero : DateTime.now().difference(_startedAt!);
}
