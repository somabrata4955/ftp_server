import 'package:flutter/material.dart';

import '../../models/ftp_client_model.dart';

/// Renders a single connected client with its IP, username, and a
/// disconnect action — used on the Home screen's client list.
class ClientListItem extends StatelessWidget {
  final FtpClientModel client;
  final VoidCallback onDisconnect;

  const ClientListItem({super.key, required this.client, required this.onDisconnect});

  String _formatDuration(Duration d) {
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    if (d.inMinutes > 0) return '${d.inMinutes}m ${d.inSeconds.remainder(60)}s';
    return '${d.inSeconds}s';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: client.authenticated
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.errorContainer,
          child: Icon(
            client.authenticated ? Icons.person : Icons.person_off_outlined,
          ),
        ),
        title: Text(client.ipAddress),
        subtitle: Text(
          '${client.authenticated ? client.username : "unauthenticated"} · '
          'connected ${_formatDuration(client.connectedDuration)} · ${client.currentDirectory}',
        ),
        trailing: IconButton(
          icon: const Icon(Icons.link_off),
          tooltip: 'Disconnect',
          onPressed: onDisconnect,
        ),
      ),
    );
  }
}
