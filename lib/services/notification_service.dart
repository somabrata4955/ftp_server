import 'dart:io';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../core/constants/app_constants.dart';

/// A no-op [TaskHandler] — all real work (the FTP server) runs on the
/// main isolate's event loop via `dart:io` sockets, which keep the app
/// alive as long as the foreground service notification is showing.
/// This handler exists purely to satisfy the `flutter_foreground_task`
/// plugin API and to let us push status text updates into the
/// notification from [NotificationService.updateNotification].
class _FtpForegroundTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp) async {}
}

/// Manages the persistent "FTP server running" notification and keeps
/// the process alive in the background via Android's foreground-service
/// APIs, which is required for the server to keep accepting connections
/// while the app is backgrounded.
class NotificationService {
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized || !Platform.isAndroid) return;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: AppConstants.notificationChannelId,
        channelName: AppConstants.notificationChannelName,
        channelDescription: AppConstants.notificationChannelDescription,
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(30000),
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
    _initialized = true;
  }

  Future<void> startForegroundService({
    required String title,
    required String description,
  }) async {
    await initialize();
    if (!Platform.isAndroid) return;
    final isRunning = await FlutterForegroundTask.isRunningService;
    if (isRunning) {
      await updateNotification(title: title, description: description);
      return;
    }
    await FlutterForegroundTask.startService(
      notificationTitle: title,
      notificationText: description,
      callback: startCallback,
    );
  }

  Future<void> updateNotification({
    required String title,
    required String description,
  }) async {
    if (!Platform.isAndroid) return;
    await FlutterForegroundTask.updateService(
      notificationTitle: title,
      notificationText: description,
    );
  }

  Future<void> stopForegroundService() async {
    if (!Platform.isAndroid) return;
    await FlutterForegroundTask.stopService();
  }
}

/// Top-level entry point required by `flutter_foreground_task` — it runs
/// in a separate isolate context on Android.
@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(_FtpForegroundTaskHandler());
}
