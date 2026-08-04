import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/home_controller.dart';
import '../../providers/server_provider.dart';
import '../../providers/settings_provider.dart';
import '../widgets/client_list_item.dart';
import '../widgets/custom_button.dart';
import '../widgets/ftp_url_card.dart';
import '../widgets/section_title.dart';
import '../widgets/server_status_card.dart';
import 'qr_screen.dart';

/// The primary screen: shows server status, exposes the start/stop
/// control, the shareable FTP URL, and a live preview of connected
/// clients.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final serverProvider = context.watch<ServerProvider>();
    final settingsProvider = context.watch<SettingsProvider>();
    final controller = HomeController(serverProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('WiFi FTP Server')),
      body: RefreshIndicator(
        onRefresh: controller.refreshNetworkInfo,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (serverProvider.lastError != null)
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline,
                          color: Theme.of(context).colorScheme.onErrorContainer),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          serverProvider.lastError!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.onErrorContainer),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ServerStatusCard(
              isRunning: serverProvider.isRunning,
              uptime: serverProvider.uptime,
              clientCount: serverProvider.clients.length,
            ),
            const SizedBox(height: 12),
            FtpUrlCard(
              ftpUrl: serverProvider.ftpUrl,
              onShowQrCode: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => QrScreen(ftpUrl: serverProvider.ftpUrl!),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            CustomButton(
              label: serverProvider.isRunning ? 'Stop Server' : 'Start Server',
              icon: serverProvider.isRunning ? Icons.stop_circle_outlined : Icons.play_circle_outline,
              backgroundColor: serverProvider.isRunning
                  ? Theme.of(context).colorScheme.error
                  : null,
              onPressed: settingsProvider.isLoaded
                  ? () => controller.toggleServer(context)
                  : null,
            ),
            const SizedBox(height: 8),
            if (settingsProvider.config.readOnly)
              const _InfoChip(icon: Icons.lock_outline, label: 'Read-only mode enabled'),
            if (settingsProvider.config.anonymousAllowed)
              const _InfoChip(icon: Icons.no_accounts_outlined, label: 'Anonymous login allowed'),

            const SectionTitle(title: 'CONNECTED CLIENTS', icon: Icons.people_outline),
            if (serverProvider.clients.isEmpty)
              const _EmptyHint(text: 'No clients connected yet')
            else
              ...serverProvider.clients.map(
                (client) => ClientListItem(
                  client: client,
                  onDisconnect: () => controller.disconnectClient(client.id),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Chip(
        avatar: Icon(icon, size: 16),
        label: Text(label),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final String text;
  const _EmptyHint({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
      ),
    );
  }
}
