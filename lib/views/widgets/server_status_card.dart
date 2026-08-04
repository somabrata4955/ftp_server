import 'package:flutter/material.dart';

/// Displays whether the server is running, for how long, and how many
/// clients are connected — the primary at-a-glance status widget on Home.
class ServerStatusCard extends StatelessWidget {
  final bool isRunning;
  final Duration uptime;
  final int clientCount;

  const ServerStatusCard({
    super.key,
    required this.isRunning,
    required this.uptime,
    required this.clientCount,
  });

  String _formatUptime(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final hours = two(d.inHours);
    final minutes = two(d.inMinutes.remainder(60));
    final seconds = two(d.inSeconds.remainder(60));
    return '$hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isRunning ? Colors.green : theme.colorScheme.outline;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    boxShadow: isRunning
                        ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 8)]
                        : null,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  isRunning ? 'Server Running' : 'Server Stopped',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _StatColumn(
                  label: 'Uptime',
                  value: isRunning ? _formatUptime(uptime) : '--:--:--',
                  icon: Icons.timer_outlined,
                ),
                _StatColumn(
                  label: 'Clients',
                  value: '$clientCount',
                  icon: Icons.people_outline,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatColumn({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Icon(icon, color: theme.colorScheme.primary),
        const SizedBox(height: 6),
        Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
  }
}
