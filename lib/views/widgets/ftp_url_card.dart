import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

/// Shows the current `ftp://ip:port` URL with quick actions to copy,
/// share, or view it as a QR code (e.g. for scanning with a phone).
class FtpUrlCard extends StatelessWidget {
  final String? ftpUrl;
  final VoidCallback onShowQrCode;

  const FtpUrlCard({super.key, required this.ftpUrl, required this.onShowQrCode});

  Future<void> _copyToClipboard(BuildContext context) async {
    if (ftpUrl == null) return;
    await Clipboard.setData(ClipboardData(text: ftpUrl!));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('FTP URL copied to clipboard')),
      );
    }
  }

  void _share() {
    if (ftpUrl == null) return;
    SharePlus.instance.share(ShareParams(text: 'Connect to my FTP server: $ftpUrl'));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasUrl = ftpUrl != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('FTP Address', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            SelectableText(
              hasUrl ? ftpUrl! : 'Start the server to see your FTP address',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: hasUrl ? theme.colorScheme.primary : theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: hasUrl ? () => _copyToClipboard(context) : null,
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('Copy'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: hasUrl ? _share : null,
                    icon: const Icon(Icons.share, size: 18),
                    label: const Text('Share'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: hasUrl ? onShowQrCode : null,
                    icon: const Icon(Icons.qr_code, size: 18),
                    label: const Text('QR'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
