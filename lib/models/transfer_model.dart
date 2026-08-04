/// Direction of a file transfer relative to the server.
enum TransferDirection { upload, download }

/// Current lifecycle status of a transfer.
enum TransferStatus { inProgress, completed, failed, cancelled }

/// Represents a single file transfer (STOR/APPE = upload, RETR = download),
/// including live progress, so the UI can render a progress bar and speed.
class TransferModel {
  final String id;
  final String fileName;
  final String remoteClientIp;
  final TransferDirection direction;
  final int totalBytes;
  int transferredBytes;
  TransferStatus status;
  final DateTime startedAt;
  DateTime? finishedAt;
  double speedBytesPerSecond;
  String? errorMessage;

  TransferModel({
    required this.id,
    required this.fileName,
    required this.remoteClientIp,
    required this.direction,
    required this.totalBytes,
    this.transferredBytes = 0,
    this.status = TransferStatus.inProgress,
    required this.startedAt,
    this.finishedAt,
    this.speedBytesPerSecond = 0,
    this.errorMessage,
  });

  double get progress =>
      totalBytes <= 0 ? 0 : (transferredBytes / totalBytes).clamp(0, 1);

  bool get isFinished => status != TransferStatus.inProgress;
}
