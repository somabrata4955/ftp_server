import 'dart:async';
import 'dart:io';

import '../../core/constants/app_constants.dart';

/// Encapsulates the FTP "data connection" — the second, short-lived socket
/// used for LIST/NLST/RETR/STOR/APPE, as opposed to the long-lived control
/// connection. Supports both PASV (server listens, client connects) and
/// PORT (client listens, server connects) modes.
class FtpDataConnection {
  ServerSocket? _passiveServer;
  Socket? _activeSocket;
  InternetAddress? _portAddress;
  int? _portPort;
  bool _isPassive = false;

  bool get isConfigured => _isPassive ? _passiveServer != null : _portAddress != null;

  /// Opens a listening socket for PASV mode on the first free port within
  /// the configured passive port range and returns it so the caller can
  /// format the `227 Entering Passive Mode` reply.
  Future<ServerSocket> enterPassiveMode(InternetAddress bindAddress) async {
    await _cleanupPassiveServer();
    _isPassive = true;
    Object? lastError;
    for (int port = AppConstants.passiveModePortRangeStart;
        port <= AppConstants.passiveModePortRangeEnd;
        port++) {
      try {
        final server = await ServerSocket.bind(bindAddress, port, shared: false);
        _passiveServer = server;
        return server;
      } catch (e) {
        lastError = e;
        continue;
      }
    }
    throw StateError('No free passive port available: $lastError');
  }

  /// Configures active (PORT) mode with the client-supplied address/port.
  void enterActiveMode(InternetAddress address, int port) {
    _isPassive = false;
    _portAddress = address;
    _portPort = port;
  }

  /// Establishes the actual data socket for this transfer, depending on
  /// whichever mode ([enterPassiveMode] or [enterActiveMode]) was last set.
  Future<Socket> openDataSocket() async {
    if (_isPassive) {
      final server = _passiveServer;
      if (server == null) {
        throw StateError('Passive mode not initialized');
      }
      final completer = Completer<Socket>();
      late StreamSubscription sub;
      sub = server.listen((socket) {
        if (!completer.isCompleted) {
          completer.complete(socket);
        }
        sub.cancel();
      }, onError: (e) {
        if (!completer.isCompleted) completer.completeError(e);
      });
      return completer.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw TimeoutException('No data connection received'),
      );
    } else {
      final address = _portAddress;
      final port = _portPort;
      if (address == null || port == null) {
        throw StateError('Active (PORT) mode not initialized');
      }
      final socket = await Socket.connect(address, port,
          timeout: const Duration(seconds: 15));
      _activeSocket = socket;
      return socket;
    }
  }

  Future<void> _cleanupPassiveServer() async {
    await _passiveServer?.close();
    _passiveServer = null;
  }

  Future<void> dispose() async {
    await _cleanupPassiveServer();
    await _activeSocket?.close();
    _activeSocket = null;
  }
}
