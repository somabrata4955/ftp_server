import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Resolves filesystem locations used by the server, primarily the FTP
/// "root directory" that clients are jailed into.
///
/// Defaults to the device's shared external storage root (e.g.
/// `/storage/emulated/0`) — where the user's actual Downloads, DCIM,
/// Pictures, etc. live — since the whole point of this app is browsing
/// real files, and it already requests `MANAGE_EXTERNAL_STORAGE` to do
/// so. Falls back to the app's own sandboxed storage only if the shared
/// root isn't accessible on a given device. The user can always override
/// this in Settings.
class StorageService {
  static const String _sharedStorageRoot = '/storage/emulated/0';

  Future<String> getDefaultRootDirectory() async {
    if (Platform.isAndroid) {
      final shared = Directory(_sharedStorageRoot);
      if (await shared.exists()) {
        return _sharedStorageRoot;
      }
    }

    // Fallback: app-sandboxed external storage (always available, but
    // starts out empty — only reached if the shared root above isn't
    // usable on this device).
    final dir = await getExternalStorageDirectory();
    if (dir != null) {
      final ftpRoot = Directory('${dir.path}/ftp_root');
      if (!await ftpRoot.exists()) {
        await ftpRoot.create(recursive: true);
      }
      return ftpRoot.path;
    }
    // Last resort for platforms without external storage (shouldn't
    // happen on Android, but keeps this service safe to unit test
    // elsewhere).
    final appDir = await getApplicationDocumentsDirectory();
    return appDir.path;
  }

  Future<bool> directoryExists(String path) => Directory(path).exists();

  Future<void> ensureDirectoryExists(String path) async {
    final dir = Directory(path);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }

  Future<int> getDirectoryEntryCount(String path) async {
    final dir = Directory(path);
    if (!await dir.exists()) return 0;
    return dir.list().length;
  }
}
