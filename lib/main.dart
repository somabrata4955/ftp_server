import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'providers/log_provider.dart';
import 'providers/server_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/transfer_provider.dart';
import 'repositories/history_repository.dart';
import 'repositories/log_repository.dart';
import 'repositories/settings_repository.dart';
import 'services/network_service.dart';
import 'services/notification_service.dart';
import 'services/permission_service.dart';
import 'services/storage_service.dart';

void main() {
  
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _AppBootstrap());
}

/// Wires up every repository/service/provider by hand (manual dependency
/// injection — no external DI framework needed for a project this size)
/// and then hands control to [WiFiFtpServerApp] once settings have
/// finished loading, optionally auto-starting the server per the user's
/// saved preference.
class _AppBootstrap extends StatelessWidget {
  const _AppBootstrap();

  @override
  Widget build(BuildContext context) {
    // ---- Repositories --------------------------------------------------
    final settingsRepository = SettingsRepository();
    final historyRepository = HistoryRepository();
    final logRepository = LogRepository();

    // ---- Services --------------------------------------------------------
    final storageService = StorageService();
    final notificationService = NotificationService();
    final networkService = NetworkService();
    final permissionService = PermissionService();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider(settingsRepository)),
        ChangeNotifierProvider(create: (_) => LogProvider(logRepository)),
        ChangeNotifierProvider(create: (_) => TransferProvider(historyRepository)),
        ChangeNotifierProvider(
          create: (_) => SettingsProvider(settingsRepository, storageService),
        ),
        ChangeNotifierProxyProvider<SettingsProvider, ServerProvider>(
          create: (context) => ServerProvider(
            settingsProvider: context.read<SettingsProvider>(),
            transferProvider: context.read<TransferProvider>(),
            notificationService: notificationService,
            networkService: networkService,
            permissionService: permissionService,
          ),
          update: (context, settingsProvider, previous) {
            final serverProvider = previous ??
                ServerProvider(
                  settingsProvider: settingsProvider,
                  transferProvider: context.read<TransferProvider>(),
                  notificationService: notificationService,
                  networkService: networkService,
                  permissionService: permissionService,
                );
            return serverProvider;
          },
        ),
      ],
      child: const _AutoStartGate(child: WiFiFtpServerApp()),
    );
  }
}

/// Waits for [SettingsProvider] to finish loading, then triggers an
/// automatic server start if the user enabled "Auto-start" in Settings.
class _AutoStartGate extends StatefulWidget {
  final Widget child;
  const _AutoStartGate({required this.child});

  @override
  State<_AutoStartGate> createState() => _AutoStartGateState();
}

class _AutoStartGateState extends State<_AutoStartGate> {
  bool _autoStartTriggered = false;

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();
    if (settingsProvider.isLoaded &&
        settingsProvider.config.autoStart &&
        !_autoStartTriggered) {
      _autoStartTriggered = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<ServerProvider>().startServer();
      });
    }
    return widget.child;
  }
}
