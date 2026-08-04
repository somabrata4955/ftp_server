import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/transfer_provider.dart';
import '../widgets/section_title.dart';
import '../widgets/transfer_list_item.dart';

/// Two-part screen: currently in-progress transfers (with live progress
/// bars and speed) followed by completed/failed transfer history.
class TransfersScreen extends StatelessWidget {
  const TransfersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final transferProvider = context.watch<TransferProvider>();
    final active = transferProvider.activeTransfers;
    final history = transferProvider.history;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transfers'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear history',
            onPressed: transferProvider.clearHistory,
          ),
        ],
      ),
      body: (active.isEmpty && history.isEmpty)
          ? const Center(child: Text('No transfers yet'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (active.isNotEmpty) ...[
                  const SectionTitle(title: 'ACTIVE', icon: Icons.sync),
                  ...active.map((t) => TransferListItem(transfer: t)),
                ],
                if (history.isNotEmpty) ...[
                  const SectionTitle(title: 'HISTORY', icon: Icons.history),
                  ...history.map((t) => TransferListItem(transfer: t)),
                ],
              ],
            ),
    );
  }
}
