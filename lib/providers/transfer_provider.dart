import 'package:flutter/foundation.dart';

import '../models/transfer_model.dart';
import '../repositories/history_repository.dart';

/// Tracks currently in-progress transfers plus a completed/failed history,
/// consumed by the Transfers screen.
class TransferProvider extends ChangeNotifier {
  final HistoryRepository _historyRepository;

  TransferProvider(this._historyRepository);

  final Map<String, TransferModel> _active = {};

  List<TransferModel> get activeTransfers => _active.values.toList();
  List<TransferModel> get history => _historyRepository.getAll();

  /// Called by [FtpServerService] every time a transfer is created or its
  /// progress/status changes.
  void onTransferUpdate(TransferModel transfer) {
    if (transfer.isFinished) {
      _active.remove(transfer.id);
      _historyRepository.add(transfer);
    } else {
      _active[transfer.id] = transfer;
    }
    notifyListeners();
  }

  void clearHistory() {
    _historyRepository.clear();
    notifyListeners();
  }
}
