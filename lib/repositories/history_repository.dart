import '../core/constants/app_constants.dart';
import '../models/transfer_model.dart';

/// In-memory store of completed/failed transfers ("history"), separate
/// from the live "current transfers" list kept in [TransferProvider].
///
/// Kept in-memory (rather than a database) intentionally: transfer
/// history is operationally useful within a session but not something
/// users typically need to survive an app restart, and it keeps the
/// dependency footprint small. The Repository Pattern here still pays
/// off by isolating this storage decision from the UI layer.
class HistoryRepository {
  final List<TransferModel> _history = [];

  List<TransferModel> getAll() => List.unmodifiable(_history);

  void add(TransferModel transfer) {
    _history.insert(0, transfer);
    if (_history.length > AppConstants.maxHistoryEntries) {
      _history.removeRange(
          AppConstants.maxHistoryEntries, _history.length);
    }
  }

  void clear() => _history.clear();
}
