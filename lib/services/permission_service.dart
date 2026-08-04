import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

import '../core/utils/logger.dart';

/// Wraps `permission_handler` to request everything the app needs,
/// tailored to modern Android (13+) permission models:
///  - `MANAGE_EXTERNAL_STORAGE` (or scoped storage on 13+) for file access
///  - `POST_NOTIFICATIONS` (new in Android 13) for the persistent
///    foreground-service notification
///  - `NEARBY_WIFI_DEVICES` (Android 13+) which is what actually gates
///    WiFi info APIs like SSID/IP resolution now that legacy location
///    permission is being phased out for this purpose.
class PermissionService {
  /// Requests every permission required for full functionality and
  /// returns true only if all of them were granted.
  Future<bool> requestAllRequiredPermissions() async {
    if (!Platform.isAndroid) return true;

    final results = <Permission, PermissionStatus>{};

    results[Permission.notification] = await Permission.notification.request();

    // Storage: on Android 13+ scoped storage plus per-media permissions
    // apply, but for full folder access most FTP-server apps request
    // MANAGE_EXTERNAL_STORAGE via the special app-settings flow.
    results[Permission.manageExternalStorage] =
        await Permission.manageExternalStorage.request();

    results[Permission.nearbyWifiDevices] =
        await Permission.nearbyWifiDevices.request();

    for (final entry in results.entries) {
      AppLogger.info('Permission ${entry.key}: ${entry.value}');
    }

    return results.values.every(
      (status) => status.isGranted || status.isLimited,
    );
  }

  Future<bool> hasStoragePermission() async {
    if (!Platform.isAndroid) return true;
    return Permission.manageExternalStorage.isGranted;
  }

  Future<bool> hasNotificationPermission() async {
    if (!Platform.isAndroid) return true;
    return Permission.notification.isGranted;
  }

  Future<void> openSettings() => openAppSettings();
}
