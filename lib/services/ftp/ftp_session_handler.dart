import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../../core/constants/app_constants.dart';
import '../../core/constants/ftp_response_codes.dart';
import '../../core/utils/file_utils.dart';
import '../../core/utils/logger.dart';
import '../../core/utils/validators.dart';
import '../../models/ftp_client_model.dart';
import '../../models/server_config_model.dart';
import '../../models/transfer_model.dart';
import 'ftp_data_connection.dart';

/// Handles a single FTP client's control connection end-to-end: command
/// parsing, authentication, working-directory state, and dispatch to the
/// correct RFC 959 command implementation (including data-connection
/// commands such as LIST/RETR/STOR which stream bytes without ever
/// loading a whole file into memory).
///
/// One instance of this class is created per accepted [Socket] by
/// [FtpServerService].
class FtpSessionHandler {
  final Socket controlSocket;
  final ServerConfigModel Function() getConfig;
  final String? Function() getAdvertisedIp;
  final void Function(FtpClientModel client) onClientChanged;
  final void Function(String clientId) onClientDisconnected;
  final void Function(TransferModel transfer) onTransferChanged;

  late final FtpClientModel _client;
  String _currentDir = '/';
  bool _authenticated = false;
  String _pendingUsername = '';
  String? _renameFromVirtualPath;
  String _transferType = 'A'; // A = ASCII, I = Image/binary
  final FtpDataConnection _dataConnection = FtpDataConnection();
  final List<int> _incomingBuffer = [];
  StreamSubscription<Uint8List>? _subscription;
  bool _closed = false;
  int _transferCounter = 0;

  FtpSessionHandler({
    required this.controlSocket,
    required this.getConfig,
    required this.getAdvertisedIp,
    required this.onClientChanged,
    required this.onClientDisconnected,
    required this.onTransferChanged,
  }) {
    final remote = controlSocket.remoteAddress.address;
    final remotePort = controlSocket.remotePort;
    _client = FtpClientModel(
      id: '$remote:$remotePort#${DateTime.now().microsecondsSinceEpoch}',
      ipAddress: remote,
      port: remotePort,
      connectedAt: DateTime.now(),
    );
  }

  String get _rootDirectory => getConfig().rootDirectory;

  Future<void> start() async {
    onClientChanged(_client);
    AppLogger.info('Client connected: ${_client.ipAddress}:${_client.port}');
    await _sendResponse(FtpResponseCodes.serviceReady,
        'Welcome to ${AppConstants.appName}');

    _subscription = controlSocket.cast<Uint8List>().listen(
      _onData,
      onError: (Object error) {
        AppLogger.error('Socket error (${_client.ipAddress}): $error');
        _cleanup();
      },
      onDone: _cleanup,
      cancelOnError: true,
    );
  }

  void _onData(Uint8List chunk) {
    _incomingBuffer.addAll(chunk);
    // FTP commands are terminated by CRLF; a single TCP chunk may contain
    // multiple commands or a partial one, so we buffer and split.
    while (true) {
      final index = _indexOfCrlf(_incomingBuffer);
      if (index == -1) break;
      final lineBytes = _incomingBuffer.sublist(0, index);
      _incomingBuffer.removeRange(0, index + 2);
      final line = utf8.decode(lineBytes, allowMalformed: true).trim();
      if (line.isNotEmpty) {
        // Handle asynchronously but sequentially per connection.
        _handleCommandSafely(line);
      }
    }
  }

  int _indexOfCrlf(List<int> bytes) {
    for (int i = 0; i < bytes.length - 1; i++) {
      if (bytes[i] == 13 && bytes[i + 1] == 10) return i;
    }
    // Some clients (buggy) send bare \n.
    final lf = bytes.indexOf(10);
    return lf == -1 ? -1 : (lf > 0 && bytes[lf - 1] == 13 ? lf - 1 : -1);
  }

  Future<void> _handleCommandSafely(String rawLine) async {
    try {
      await _handleCommand(rawLine);
    } catch (e, st) {
      AppLogger.error('Unhandled command error: $e\n$st');
      await _sendResponse(
          FtpResponseCodes.actionAbortedLocalError, 'Internal server error');
    }
  }

  Future<void> _handleCommand(String rawLine) async {
    final spaceIndex = rawLine.indexOf(' ');
    final verb = (spaceIndex == -1 ? rawLine : rawLine.substring(0, spaceIndex))
        .toUpperCase();
    final arg = spaceIndex == -1 ? '' : rawLine.substring(spaceIndex + 1).trim();

    if (arg.isNotEmpty && !Validators.isSafeCommandArgument(arg)) {
      await _sendResponse(
          FtpResponseCodes.syntaxErrorInParameters, 'Invalid argument');
      return;
    }

    AppLogger.info('${_client.ipAddress} >> $verb $arg');

    switch (verb) {
      case 'USER':
        await _handleUser(arg);
        break;
      case 'PASS':
        await _handlePass(arg);
        break;
      case 'PWD':
      case 'XPWD':
        await _handlePwd();
        break;
      case 'CWD':
      case 'XCWD':
        await _handleCwd(arg);
        break;
      case 'CDUP':
      case 'XCUP':
        await _handleCwd('..');
        break;
      case 'LIST':
        await _handleList(arg, nameListOnly: false);
        break;
      case 'NLST':
        await _handleList(arg, nameListOnly: true);
        break;
      case 'TYPE':
        await _handleType(arg);
        break;
      case 'SIZE':
        await _handleSize(arg);
        break;
      case 'PASV':
        await _handlePasv();
        break;
      case 'PORT':
        await _handlePort(arg);
        break;
      case 'RETR':
        await _handleRetr(arg);
        break;
      case 'STOR':
        await _handleStor(arg, append: false);
        break;
      case 'APPE':
        await _handleStor(arg, append: true);
        break;
      case 'MKD':
      case 'XMKD':
        await _handleMkd(arg);
        break;
      case 'RMD':
      case 'XRMD':
        await _handleRmd(arg);
        break;
      case 'DELE':
        await _handleDele(arg);
        break;
      case 'RNFR':
        await _handleRnfr(arg);
        break;
      case 'RNTO':
        await _handleRnto(arg);
        break;
      case 'QUIT':
        await _handleQuit();
        break;
      case 'NOOP':
        await _sendResponse(FtpResponseCodes.commandOkay, 'NOOP ok');
        break;
      case 'SYST':
        await _sendResponse(FtpResponseCodes.systemType, 'UNIX Type: L8');
        break;
      case 'FEAT':
        await _handleFeat();
        break;
      case 'OPTS':
        await _sendResponse(FtpResponseCodes.commandOkay, 'OPTS ok');
        break;
      default:
        await _sendResponse(FtpResponseCodes.syntaxErrorUnrecognizedCommand,
            "Unrecognized command '$verb'");
    }
  }

  // ---------------------------------------------------------------------
  // Authentication
  // ---------------------------------------------------------------------

  Future<void> _handleUser(String arg) async {
    final config = getConfig();
    if (config.anonymousAllowed && arg.toLowerCase() == 'anonymous') {
      _pendingUsername = 'anonymous';
      await _sendResponse(FtpResponseCodes.usernameOkNeedPassword,
          'Anonymous login accepted, send any password');
      return;
    }
    _pendingUsername = arg;
    await _sendResponse(
        FtpResponseCodes.usernameOkNeedPassword, 'User name okay, need password');
  }

  Future<void> _handlePass(String arg) async {
    final config = getConfig();
    final anonymousOk = config.anonymousAllowed && _pendingUsername == 'anonymous';
    final credsOk = _pendingUsername == config.username && arg == config.password;

    if (anonymousOk || credsOk) {
      _authenticated = true;
      _client.username = _pendingUsername;
      _client.authenticated = true;
      onClientChanged(_client);
      AppLogger.success('${_client.ipAddress} authenticated as $_pendingUsername');
      await _sendResponse(FtpResponseCodes.loginSuccessful, 'Login successful');
    } else {
      AppLogger.warning('${_client.ipAddress} failed authentication');
      await _sendResponse(FtpResponseCodes.notLoggedIn, 'Login incorrect');
    }
  }

  bool _requireAuth() => _authenticated;

  Future<bool> _guardAuth() async {
    if (!_requireAuth()) {
      await _sendResponse(
          FtpResponseCodes.notLoggedIn, 'Please login with USER and PASS');
      return false;
    }
    return true;
  }

  // ---------------------------------------------------------------------
  // Directory navigation
  // ---------------------------------------------------------------------

  Future<void> _handlePwd() async {
    if (!await _guardAuth()) return;
    await _sendResponse(
        FtpResponseCodes.pathnameCreated, '"$_currentDir" is the current directory');
  }

  Future<void> _handleCwd(String arg) async {
    if (!await _guardAuth()) return;
    final target = arg.isEmpty ? '/' : arg;
    final resolved = FileUtils.resolveSafePath(
      rootDir: _rootDirectory,
      currentDir: _currentDir,
      requestedPath: target,
    );
    if (resolved == null) {
      await _sendResponse(
          FtpResponseCodes.fileActionNotTakenNoAccess, 'Access denied');
      return;
    }
    final dir = Directory(resolved);
    if (!await dir.exists()) {
      await _sendResponse(
          FtpResponseCodes.fileActionNotTaken, 'Directory not found');
      return;
    }
    _currentDir = FileUtils.toVirtualPath(_rootDirectory, resolved);
    _client.currentDirectory = _currentDir;
    onClientChanged(_client);
    await _sendResponse(
        FtpResponseCodes.requestedFileActionOkay, 'Directory changed to $_currentDir');
  }

  // ---------------------------------------------------------------------
  // Listing
  // ---------------------------------------------------------------------

  Future<void> _handleList(String arg, {required bool nameListOnly}) async {
    if (!await _guardAuth()) return;
    // Some clients pass listing flags (e.g. "-la") as the argument; treat
    // any leading-dash token as "no path given" rather than a real path.
    final pathArg = (arg.startsWith('-') || arg.isEmpty) ? '.' : arg;
    final resolved = FileUtils.resolveSafePath(
      rootDir: _rootDirectory,
      currentDir: _currentDir,
      requestedPath: pathArg,
    );
    if (resolved == null) {
      await _sendResponse(
          FtpResponseCodes.fileActionNotTakenNoAccess, 'Access denied');
      return;
    }
    final dir = Directory(resolved);
    if (!await dir.exists()) {
      await _sendResponse(
          FtpResponseCodes.fileActionNotTaken, 'Directory not found');
      return;
    }

    Socket dataSocket;
    try {
      dataSocket = await _openDataSocketForTransfer();
    } catch (e) {
      await _sendResponse(
          FtpResponseCodes.cantOpenDataConnection, 'Cannot open data connection');
      return;
    }

    await _sendResponse(FtpResponseCodes.fileStatusOk, 'Opening data connection for listing');

    try {
      final config = getConfig();
      final entities = await dir.list(followLinks: false).toList();
      final buffer = StringBuffer();
      for (final entity in entities) {
        final name = p.basename(entity.path);
        if (!config.showHiddenFiles && name.startsWith('.')) continue;
        if (nameListOnly) {
          buffer.write('$name\r\n');
        } else {
          try {
            final stat = await entity.stat();
            buffer.write('${FileUtils.formatListLine(entity, stat)}\r\n');
          } catch (_) {
            // Skip entries we can't stat (e.g. broken symlink).
          }
        }
      }
      dataSocket.add(utf8.encode(buffer.toString()));
      await dataSocket.flush();
    } finally {
      await dataSocket.close();
      await _dataConnection.dispose();
    }
    await _sendResponse(
        FtpResponseCodes.closingDataConnection, 'Directory send OK');
  }

  // ---------------------------------------------------------------------
  // TYPE / SIZE
  // ---------------------------------------------------------------------

  Future<void> _handleType(String arg) async {
    final upper = arg.toUpperCase().trim();
    if (upper.startsWith('A')) {
      _transferType = 'A';
      await _sendResponse(FtpResponseCodes.commandOkay, 'Switching to ASCII mode');
    } else if (upper.startsWith('I')) {
      _transferType = 'I';
      await _sendResponse(FtpResponseCodes.commandOkay, 'Switching to Binary mode');
    } else {
      await _sendResponse(
          FtpResponseCodes.commandNotImplementedForParameter, 'Unsupported type');
    }
  }

  Future<void> _handleSize(String arg) async {
    if (!await _guardAuth()) return;
    final resolved = _resolveOrNull(arg);
    if (resolved == null) return _denyAccess();
    final file = File(resolved);
    if (!await file.exists()) {
      await _sendResponse(FtpResponseCodes.fileActionNotTaken, 'File not found');
      return;
    }
    final size = await file.length();
    await _sendResponse(FtpResponseCodes.fileStatus, '$size');
  }

  // ---------------------------------------------------------------------
  // PASV / PORT
  // ---------------------------------------------------------------------

  Future<void> _handlePasv() async {
    if (!await _guardAuth()) return;
    try {
      // The server socket is bound to the wildcard address (0.0.0.0) so
      // it accepts connections on any interface, but we must advertise
      // a real, routable IP in the PASV reply — echoing the wildcard
      // address back would make clients try to connect to 0.0.0.0,
      // which always fails. Prefer the known WiFi/hotspot IP; only fall
      // back to the socket's local address if that isn't available yet.
      final bindAddress = controlSocket.address;
      final server = await _dataConnection.enterPassiveMode(bindAddress);
      final advertisedIp = getAdvertisedIp() ?? controlSocket.address.address;
      final ipParts = advertisedIp.split('.');
      final port = server.port;
      final p1 = port >> 8;
      final p2 = port & 0xFF;
      await _sendResponse(
        FtpResponseCodes.enteringPassiveMode,
        'Entering Passive Mode (${ipParts.join(',')},$p1,$p2)',
      );
    } catch (e) {
      await _sendResponse(
          FtpResponseCodes.cantOpenDataConnection, 'Cannot enter passive mode');
    }
  }

  Future<void> _handlePort(String arg) async {
    if (!await _guardAuth()) return;
    final parts = arg.split(',');
    if (parts.length != 6) {
      await _sendResponse(
          FtpResponseCodes.syntaxErrorInParameters, 'Malformed PORT argument');
      return;
    }
    try {
      final ip = parts.sublist(0, 4).join('.');
      final p1 = int.parse(parts[4]);
      final p2 = int.parse(parts[5]);
      final port = (p1 << 8) + p2;
      _dataConnection.enterActiveMode(InternetAddress(ip), port);
      await _sendResponse(FtpResponseCodes.commandOkay, 'PORT command successful');
    } catch (e) {
      await _sendResponse(
          FtpResponseCodes.syntaxErrorInParameters, 'Malformed PORT argument');
    }
  }

  Future<Socket> _openDataSocketForTransfer() {
    return _dataConnection.openDataSocket();
  }

  // ---------------------------------------------------------------------
  // RETR (download) / STOR & APPE (upload)
  // ---------------------------------------------------------------------

  Future<void> _handleRetr(String arg) async {
    if (!await _guardAuth()) return;
    final resolved = _resolveOrNull(arg);
    if (resolved == null) return _denyAccess();

    final file = File(resolved);
    if (!await file.exists()) {
      await _sendResponse(FtpResponseCodes.fileActionNotTaken, 'File not found');
      return;
    }

    Socket dataSocket;
    try {
      dataSocket = await _openDataSocketForTransfer();
    } catch (e) {
      await _sendResponse(
          FtpResponseCodes.cantOpenDataConnection, 'Cannot open data connection');
      return;
    }

    final totalBytes = await file.length();
    final transfer = _createTransfer(
      fileName: p.basename(resolved),
      direction: TransferDirection.download,
      totalBytes: totalBytes,
    );

    await _sendResponse(FtpResponseCodes.fileStatusOk,
        'Opening BINARY mode data connection for ${transfer.fileName} ($totalBytes bytes)');

    try {
      // Stream the file in fixed-size chunks so files of any size
      // (including 10GB+) never need to be fully resident in memory.
      final stream = file.openRead();
      int lastReported = DateTime.now().millisecondsSinceEpoch;
      int bytesSinceLastReport = 0;
      await for (final chunk in stream) {
        dataSocket.add(chunk);
        await dataSocket.flush();
        transfer.transferredBytes += chunk.length;
        bytesSinceLastReport += chunk.length;
        final now = DateTime.now().millisecondsSinceEpoch;
        if (now - lastReported >= 500) {
          transfer.speedBytesPerSecond =
              bytesSinceLastReport / ((now - lastReported) / 1000);
          bytesSinceLastReport = 0;
          lastReported = now;
          onTransferChanged(transfer);
        }
      }
      transfer.status = TransferStatus.completed;
      transfer.finishedAt = DateTime.now();
      onTransferChanged(transfer);
      AppLogger.success('Downloaded ${transfer.fileName} to ${_client.ipAddress}');
      await _sendResponse(
          FtpResponseCodes.closingDataConnection, 'Transfer complete');
    } catch (e) {
      transfer.status = TransferStatus.failed;
      transfer.errorMessage = e.toString();
      transfer.finishedAt = DateTime.now();
      onTransferChanged(transfer);
      AppLogger.error('Download failed: $e');
      await _sendResponse(FtpResponseCodes.connectionClosedTransferAborted,
          'Transfer aborted: $e');
    } finally {
      await dataSocket.close();
      await _dataConnection.dispose();
    }
  }

  Future<void> _handleStor(String arg, {required bool append}) async {
    if (!await _guardAuth()) return;
    final config = getConfig();
    if (config.readOnly) {
      await _sendResponse(FtpResponseCodes.fileActionNotTakenNoAccess,
          'Server is in read-only mode');
      return;
    }
    final resolved = _resolveOrNull(arg);
    if (resolved == null) return _denyAccess();

    Socket dataSocket;
    try {
      dataSocket = await _openDataSocketForTransfer();
    } catch (e) {
      await _sendResponse(
          FtpResponseCodes.cantOpenDataConnection, 'Cannot open data connection');
      return;
    }

    final transfer = _createTransfer(
      fileName: p.basename(resolved),
      direction: TransferDirection.upload,
      totalBytes: 0, // unknown ahead of time for uploads
    );

    await _sendResponse(FtpResponseCodes.fileStatusOk,
        'Opening BINARY mode data connection for ${transfer.fileName}');

    IOSink? sink;
    try {
      final file = File(resolved);
      sink = file.openWrite(mode: append ? FileMode.append : FileMode.write);
      int lastReported = DateTime.now().millisecondsSinceEpoch;
      int bytesSinceLastReport = 0;
      await for (final chunk in dataSocket) {
        sink.add(chunk);
        transfer.transferredBytes += chunk.length;
        bytesSinceLastReport += chunk.length;
        final now = DateTime.now().millisecondsSinceEpoch;
        if (now - lastReported >= 500) {
          transfer.speedBytesPerSecond =
              bytesSinceLastReport / ((now - lastReported) / 1000);
          bytesSinceLastReport = 0;
          lastReported = now;
          onTransferChanged(transfer);
        }
      }
      await sink.flush();
      await sink.close();
      transfer.status = TransferStatus.completed;
      transfer.finishedAt = DateTime.now();
      onTransferChanged(transfer);
      AppLogger.success('Received ${transfer.fileName} from ${_client.ipAddress}');
      await _sendResponse(
          FtpResponseCodes.closingDataConnection, 'Transfer complete');
    } catch (e) {
      try {
        await sink?.close();
      } catch (_) {}
      transfer.status = TransferStatus.failed;
      transfer.errorMessage = e.toString();
      transfer.finishedAt = DateTime.now();
      onTransferChanged(transfer);
      AppLogger.error('Upload failed: $e');
      await _sendResponse(FtpResponseCodes.connectionClosedTransferAborted,
          'Transfer aborted: $e');
    } finally {
      await dataSocket.close();
      await _dataConnection.dispose();
    }
  }

  TransferModel _createTransfer({
    required String fileName,
    required TransferDirection direction,
    required int totalBytes,
  }) {
    _transferCounter++;
    final transfer = TransferModel(
      id: '${_client.id}#$_transferCounter',
      fileName: fileName,
      remoteClientIp: _client.ipAddress,
      direction: direction,
      totalBytes: totalBytes,
      startedAt: DateTime.now(),
    );
    onTransferChanged(transfer);
    return transfer;
  }

  // ---------------------------------------------------------------------
  // Directory / file management
  // ---------------------------------------------------------------------

  Future<void> _handleMkd(String arg) async {
    if (!await _guardAuth()) return;
    if (getConfig().readOnly) return _denyReadOnly();
    final resolved = _resolveOrNull(arg);
    if (resolved == null) return _denyAccess();
    try {
      final dir = Directory(resolved);
      if (await dir.exists()) {
        await _sendResponse(
            FtpResponseCodes.fileActionNotTaken, 'Directory already exists');
        return;
      }
      await dir.create(recursive: false);
      final virtual = FileUtils.toVirtualPath(_rootDirectory, resolved);
      await _sendResponse(
          FtpResponseCodes.pathnameCreated, '"$virtual" directory created');
    } catch (e) {
      await _sendResponse(
          FtpResponseCodes.fileActionNotTaken, 'Could not create directory: $e');
    }
  }

  Future<void> _handleRmd(String arg) async {
    if (!await _guardAuth()) return;
    if (getConfig().readOnly) return _denyReadOnly();
    final resolved = _resolveOrNull(arg);
    if (resolved == null) return _denyAccess();
    try {
      final dir = Directory(resolved);
      if (!await dir.exists()) {
        await _sendResponse(
            FtpResponseCodes.fileActionNotTaken, 'Directory not found');
        return;
      }
      await dir.delete(recursive: true);
      await _sendResponse(
          FtpResponseCodes.requestedFileActionOkay, 'Directory deleted');
    } catch (e) {
      await _sendResponse(
          FtpResponseCodes.fileActionNotTaken, 'Could not remove directory: $e');
    }
  }

  Future<void> _handleDele(String arg) async {
    if (!await _guardAuth()) return;
    if (getConfig().readOnly) return _denyReadOnly();
    final resolved = _resolveOrNull(arg);
    if (resolved == null) return _denyAccess();
    try {
      final file = File(resolved);
      if (!await file.exists()) {
        await _sendResponse(FtpResponseCodes.fileActionNotTaken, 'File not found');
        return;
      }
      await file.delete();
      await _sendResponse(
          FtpResponseCodes.requestedFileActionOkay, 'File deleted');
    } catch (e) {
      await _sendResponse(
          FtpResponseCodes.fileActionNotTaken, 'Could not delete file: $e');
    }
  }

  Future<void> _handleRnfr(String arg) async {
    if (!await _guardAuth()) return;
    if (getConfig().readOnly) return _denyReadOnly();
    final resolved = _resolveOrNull(arg);
    if (resolved == null) return _denyAccess();
    final exists =
        await File(resolved).exists() || await Directory(resolved).exists();
    if (!exists) {
      await _sendResponse(
          FtpResponseCodes.fileActionNotTaken, 'File/directory not found');
      return;
    }
    _renameFromVirtualPath = resolved;
    await _sendResponse(FtpResponseCodes.requestedFileActionPendingFurtherInfo,
        'Ready for RNTO');
  }

  Future<void> _handleRnto(String arg) async {
    if (!await _guardAuth()) return;
    if (getConfig().readOnly) return _denyReadOnly();
    final from = _renameFromVirtualPath;
    if (from == null) {
      await _sendResponse(
          FtpResponseCodes.badSequenceOfCommands, 'RNFR required first');
      return;
    }
    final resolved = _resolveOrNull(arg);
    _renameFromVirtualPath = null;
    if (resolved == null) return _denyAccess();
    try {
      final fileEntity = File(from);
      final dirEntity = Directory(from);
      if (await fileEntity.exists()) {
        await fileEntity.rename(resolved);
      } else if (await dirEntity.exists()) {
        await dirEntity.rename(resolved);
      } else {
        await _sendResponse(
            FtpResponseCodes.fileActionNotTaken, 'Source no longer exists');
        return;
      }
      await _sendResponse(
          FtpResponseCodes.requestedFileActionOkay, 'Rename successful');
    } catch (e) {
      await _sendResponse(
          FtpResponseCodes.fileActionNotTaken, 'Rename failed: $e');
    }
  }

  // ---------------------------------------------------------------------
  // Misc
  // ---------------------------------------------------------------------

  Future<void> _handleFeat() async {
    const features = ['SIZE', 'PASV', 'UTF8', 'REST STREAM'];
    controlSocket.add(utf8.encode('211-Features:\r\n'));
    for (final f in features) {
      controlSocket.add(utf8.encode(' $f\r\n'));
    }
    controlSocket.add(utf8.encode('211 End\r\n'));
    await controlSocket.flush();
  }

  Future<void> _handleQuit() async {
    await _sendResponse(
        FtpResponseCodes.closingControlConnection, 'Goodbye');
    await _cleanup();
  }

  // ---------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------

  String? _resolveOrNull(String arg) {
    return FileUtils.resolveSafePath(
      rootDir: _rootDirectory,
      currentDir: _currentDir,
      requestedPath: arg,
    );
  }

  Future<void> _denyAccess() => _sendResponse(
      FtpResponseCodes.fileActionNotTakenNoAccess, 'Access denied');

  Future<void> _denyReadOnly() => _sendResponse(
      FtpResponseCodes.fileActionNotTakenNoAccess, 'Server is in read-only mode');

  Future<void> _sendResponse(int code, String message) async {
    if (_closed) return;
    try {
      controlSocket.add(utf8.encode('$code $message\r\n'));
      await controlSocket.flush();
    } catch (e) {
      AppLogger.error('Failed to send response: $e');
    }
  }

  Future<void> _cleanup() async {
    if (_closed) return;
    _closed = true;
    await _subscription?.cancel();
    await _dataConnection.dispose();
    try {
      await controlSocket.close();
    } catch (_) {}
    AppLogger.info('Client disconnected: ${_client.ipAddress}:${_client.port}');
    onClientDisconnected(_client.id);
  }

  Future<void> forceDisconnect() => _cleanup();

  String get clientId => _client.id;
}
