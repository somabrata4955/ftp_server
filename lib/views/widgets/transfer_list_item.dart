import 'package:flutter/material.dart';

import '../../core/utils/file_utils.dart';
import '../../models/transfer_model.dart';

/// Renders a single transfer (active or historical) with a progress bar
/// when in-progress, or a status icon/summary when finished.
class TransferListItem extends StatelessWidget {
  final TransferModel transfer;

  const TransferListItem({super.key, required this.transfer});

  IconData get _directionIcon =>
      transfer.direction == TransferDirection.upload
          ? Icons.upload_outlined
          : Icons.download_outlined;

  Color _statusColor(BuildContext context) {
    switch (transfer.status) {
      case TransferStatus.completed:
        return Colors.green;
      case TransferStatus.failed:
        return Theme.of(context).colorScheme.error;
      case TransferStatus.cancelled:
        return Theme.of(context).colorScheme.outline;
      case TransferStatus.inProgress:
        return Theme.of(context).colorScheme.primary;
    }
  }

  String get _subtitle {
    switch (transfer.status) {
      case TransferStatus.completed:
        return '${FileUtils.formatBytes(transfer.transferredBytes)} · completed';
      case TransferStatus.failed:
        return 'Failed: ${transfer.errorMessage ?? "unknown error"}';
      case TransferStatus.cancelled:
        return 'Cancelled';
      case TransferStatus.inProgress:
        return '${FileUtils.formatBytes(transfer.transferredBytes)} · '
            '${FileUtils.formatSpeed(transfer.speedBytesPerSecond)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_directionIcon, color: color),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    transfer.fileName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Text(transfer.remoteClientIp, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 6),
            if (transfer.status == TransferStatus.inProgress && transfer.totalBytes > 0)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(value: transfer.progress, minHeight: 6),
              ),
            const SizedBox(height: 4),
            Text(_subtitle, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
