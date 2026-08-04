import 'dart:io';
import 'package:path/path.dart' as p;

/// File-system related helpers shared by the FTP server and the UI layer.
///
/// The most security-critical piece here is [resolveSafePath], which is
/// the single choke point used to translate an FTP-supplied path into an
/// absolute path on disk while preventing directory-traversal attacks
/// (e.g. `../../etc/passwd`).
class FileUtils {
  FileUtils._();

  /// Resolves [requestedPath] (which may be absolute or relative to
  /// [currentDir] in FTP terms) against [rootDir] and guarantees the
  /// resulting absolute path can never escape [rootDir].
  ///
  /// Returns `null` if the resulting path would fall outside the root,
  /// which the caller should treat as a permission/validation error.
  static String? resolveSafePath({
    required String rootDir,
    required String currentDir,
    required String requestedPath,
  }) {
    final normalizedRoot = p.normalize(rootDir);

    // Determine the FTP-style virtual path we are targeting.
    String virtualTarget;
    if (requestedPath.startsWith('/')) {
      virtualTarget = requestedPath;
    } else {
      virtualTarget = p.posix.join(currentDir, requestedPath);
    }
    virtualTarget = p.posix.normalize(virtualTarget);
    if (!virtualTarget.startsWith('/')) {
      virtualTarget = '/$virtualTarget';
    }

    // Map the virtual (FTP root-relative) path onto the real filesystem.
    final relative = virtualTarget == '/' ? '' : virtualTarget.substring(1);
    final absolute = p.normalize(p.join(normalizedRoot, relative));

    // Final guard: the resolved absolute path MUST be the root itself or
    // nested inside it. This is what stops `../../../etc/passwd` style
    // attacks regardless of how many traversal segments were supplied.
    if (absolute != normalizedRoot && !p.isWithin(normalizedRoot, absolute)) {
      return null;
    }
    return absolute;
  }

  /// Converts an absolute real path back into the FTP virtual path
  /// (rooted at `/`) that should be reported to clients (e.g. for PWD).
  static String toVirtualPath(String rootDir, String absolutePath) {
    final normalizedRoot = p.normalize(rootDir);
    final normalizedAbs = p.normalize(absolutePath);
    if (normalizedAbs == normalizedRoot) return '/';
    final rel = p.relative(normalizedAbs, from: normalizedRoot);
    final posixRel = rel.split(Platform.pathSeparator).join('/');
    return '/$posixRel';
  }

  /// True if [entityPath]'s basename starts with a dot (Unix "hidden" file
  /// convention), which is what most FTP clients / servers treat as hidden.
  static bool isHidden(String entityPath) {
    final name = p.basename(entityPath);
    return name.startsWith('.');
  }

  /// Human readable file size, e.g. "12.3 MB".
  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    const units = ['KB', 'MB', 'GB', 'TB'];
    double size = bytes / 1024;
    int unitIndex = 0;
    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }
    return '${size.toStringAsFixed(1)} ${units[unitIndex]}';
  }

  /// Human readable transfer speed, e.g. "3.4 MB/s".
  static String formatSpeed(double bytesPerSecond) {
    return '${formatBytes(bytesPerSecond.round())}/s';
  }

  /// Formats a Unix-style `ls -l` line as expected by most FTP clients
  /// (Windows Explorer, FileZilla, WinSCP, CyberDuck all parse this format).
  static String formatListLine(FileSystemEntity entity, FileStat stat) {
    final isDir = stat.type == FileSystemEntityType.directory;
    final permissions = isDir ? 'drwxr-xr-x' : '-rw-r--r--';
    const linkCount = 1;
    const owner = 'ftp';
    const group = 'ftp';
    final size = isDir ? 0 : stat.size;
    final modified = stat.modified;
    final month = _monthAbbrev[modified.month - 1];
    final day = modified.day.toString().padLeft(2, ' ');
    final now = DateTime.now();
    final timeOrYear = (now.year == modified.year)
        ? '${modified.hour.toString().padLeft(2, '0')}:${modified.minute.toString().padLeft(2, '0')}'
        : modified.year.toString().padLeft(5, ' ');
    final name = p.basename(entity.path);
    return '$permissions $linkCount $owner $group ${size.toString().padLeft(13, ' ')} '
        '$month $day $timeOrYear $name';
  }

  static const List<String> _monthAbbrev = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
}
