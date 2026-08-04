/// Represents a single connected FTP client (one control connection).
class FtpClientModel {
  final String id;
  final String ipAddress;
  final int port;
  final DateTime connectedAt;
  String username;
  bool authenticated;
  String currentDirectory;

  FtpClientModel({
    required this.id,
    required this.ipAddress,
    required this.port,
    required this.connectedAt,
    this.username = '',
    this.authenticated = false,
    this.currentDirectory = '/',
  });

  Duration get connectedDuration => DateTime.now().difference(connectedAt);

  FtpClientModel copyWith({
    String? username,
    bool? authenticated,
    String? currentDirectory,
  }) {
    return FtpClientModel(
      id: id,
      ipAddress: ipAddress,
      port: port,
      connectedAt: connectedAt,
      username: username ?? this.username,
      authenticated: authenticated ?? this.authenticated,
      currentDirectory: currentDirectory ?? this.currentDirectory,
    );
  }
}
