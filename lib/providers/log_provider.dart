import 'package:flutter/foundation.dart';

import '../core/utils/logger.dart';
import '../models/log_entry_model.dart';
import '../repositories/log_repository.dart';

/// Subscribes to [AppLogger] and republishes entries as a Provider-friendly
/// [ChangeNotifier] for the Logs screen.
class LogProvider extends ChangeNotifier {
  final LogRepository _repository;
  late final LogSink _sink;

  LogProvider(this._repository) {
    _sink = (record) {
      _repository.add(record);
      notifyListeners();
    };
    AppLogger.addSink(_sink);
  }

  List<LogEntryModel> get logs => _repository.getAll();

  void clear() {
    _repository.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    AppLogger.removeSink(_sink);
    super.dispose();
  }
}
