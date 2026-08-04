import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/log_provider.dart';
import '../widgets/log_list_item.dart';

/// Displays server activity logs with timestamps, auto-scrolling to the
/// newest entry as new lines arrive.
class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _autoScroll = true;

  void _scrollToBottom() {
    if (!_autoScroll || !_scrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logProvider = context.watch<LogProvider>();
    final logs = logProvider.logs;
    _scrollToBottom();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Logs'),
        actions: [
          IconButton(
            icon: Icon(_autoScroll ? Icons.vertical_align_bottom : Icons.pause),
            tooltip: _autoScroll ? 'Auto-scroll on' : 'Auto-scroll off',
            onPressed: () => setState(() => _autoScroll = !_autoScroll),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear logs',
            onPressed: logProvider.clear,
          ),
        ],
      ),
      body: logs.isEmpty
          ? const Center(child: Text('No log entries yet'))
          : ListView.builder(
              controller: _scrollController,
              itemCount: logs.length,
              itemBuilder: (context, index) => LogListItem(entry: logs[index]),
            ),
    );
  }
}
