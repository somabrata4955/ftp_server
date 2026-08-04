import 'package:flutter/material.dart';

import '../providers/server_provider.dart';

/// Mediates between the Home [View] and the [ServerProvider] "Model",
/// per the MVC split requested for this project: views never talk to
/// services directly, they go through a controller which applies any
/// UI-level orchestration (snackbars, confirmation results) around the
/// provider calls.
class HomeController {
  final ServerProvider serverProvider;

  HomeController(this.serverProvider);

  Future<void> toggleServer(BuildContext context) async {
    if (serverProvider.isRunning) {
      await serverProvider.stopServer();
      return;
    }
    final started = await serverProvider.startServer();
    if (!started && context.mounted && serverProvider.lastError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(serverProvider.lastError!)),
      );
    }
  }

  Future<void> refreshNetworkInfo() => serverProvider.refreshWifiIp();

  Future<void> disconnectClient(String clientId) =>
      serverProvider.disconnectClient(clientId);
}
