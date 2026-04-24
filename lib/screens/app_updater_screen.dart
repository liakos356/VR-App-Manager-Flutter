import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/google_drive_service.dart';
import '../utils/build_info.dart';

// ── Helper ─────────────────────────────────────────────────────────────────

/// Parses `kBuildTimestamp` (format `YYYYMMDD_HHMM`) to a [DateTime].
/// Returns [DateTime(0)] if the format is unrecognised.
DateTime _currentBuildDateTime() {
  final match = RegExp(
    r'^(\d{4})(\d{2})(\d{2})_(\d{2})(\d{2})$',
  ).firstMatch(kBuildTimestamp);
  if (match == null) return DateTime(0);
  return DateTime(
    int.parse(match.group(1)!),
    int.parse(match.group(2)!),
    int.parse(match.group(3)!),
    int.parse(match.group(4)!),
    int.parse(match.group(5)!),
  );
}

String _formatTimestamp(DateTime dt) {
  final y = dt.year.toString().padLeft(4, '0');
  final mo = dt.month.toString().padLeft(2, '0');
  final d = dt.day.toString().padLeft(2, '0');
  final h = dt.hour.toString().padLeft(2, '0');
  final mi = dt.minute.toString().padLeft(2, '0');
  return '$d/$mo/$y  $h:$mi';
}

String _formatBytes(int bytes) {
  if (bytes <= 0) return '—';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
}

// ── Screen ─────────────────────────────────────────────────────────────────

class AppUpdaterScreen extends StatefulWidget {
  const AppUpdaterScreen({super.key});

  @override
  State<AppUpdaterScreen> createState() => _AppUpdaterScreenState();
}

class _AppUpdaterScreenState extends State<AppUpdaterScreen> {
  final _drive = GoogleDriveService();
  final _currentBuild = _currentBuildDateTime();

  List<StoreApkEntry>? _apks;
  String? _error;
  bool _loading = true;

  // ── active download state ─────────────────────────────────────────────────
  String? _downloadingFileId;
  double _downloadProgress = 0;
  String _downloadStatus = '';
  bool _cancelled = false;

  @override
  void initState() {
    super.initState();
    _loadApks();
  }

  Future<void> _loadApks() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final apks = await _drive.listStoreApks();
      if (mounted) setState(() => _apks = apks);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Install ───────────────────────────────────────────────────────────────

  Future<void> _install(StoreApkEntry entry) async {
    // Permissions
    await Permission.requestInstallPackages.request();
    if (Platform.isAndroid) {
      if (!await Permission.manageExternalStorage.isGranted) {
        await Permission.manageExternalStorage.request();
      }
    }

    final localPath = '/sdcard/Download/${entry.fileName}';
    final localFile = File(localPath);

    setState(() {
      _downloadingFileId = entry.fileId;
      _downloadProgress = 0;
      _downloadStatus = 'Starting download…';
      _cancelled = false;
    });

    try {
      await _drive.downloadFile(
        fileId: entry.fileId,
        localFile: localFile,
        fileSize: entry.sizeBytes,
        onProgress: (received, total) {
          if (!mounted) return;
          setState(() {
            _downloadProgress = total > 0 ? received / total : 0;
            final mb = received / 1024 / 1024;
            final totalMb = total / 1024 / 1024;
            _downloadStatus =
                '${mb.toStringAsFixed(1)} / ${totalMb.toStringAsFixed(1)} MB';
          });
        },
        isCancelled: () => _cancelled,
      );

      if (_cancelled) {
        await localFile.delete().catchError((_) => localFile);
        if (mounted) {
          setState(() => _downloadingFileId = null);
          _showSnack('Download cancelled.');
        }
        return;
      }

      if (mounted) setState(() => _downloadStatus = 'Installing…');

      const channel = MethodChannelInstall._channel;
      final result = await channel.invokeMethod('installApk', {
        'apkPath': localPath,
      });

      if (result == true) {
        if (mounted) {
          setState(() => _downloadingFileId = null);
          _showSnack('Install started!');
        }
      } else {
        throw Exception('Install intent returned false');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _downloadingFileId = null);
        _showSnack('Error: $e', isError: true);
      }
    }
  }

  void _cancelDownload() => setState(() => _cancelled = true);

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : null,
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('App Updater'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loading ? null : _loadApks,
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Current build banner ────────────────────────────────────────
          Container(
            color: colorScheme.primaryContainer,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                Icon(
                  Icons.verified_outlined,
                  color: colorScheme.onPrimaryContainer,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current build',
                      style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.onPrimaryContainer.withValues(
                          alpha: 0.7,
                        ),
                      ),
                    ),
                    Text(
                      kBuildTimestamp == '00000000_0000'
                          ? 'Unknown'
                          : _formatTimestamp(_currentBuild),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Download progress overlay ───────────────────────────────────
          if (_downloadingFileId != null)
            Container(
              color: colorScheme.surfaceContainerHighest,
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _downloadStatus,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      TextButton(
                        onPressed: _cancelDownload,
                        child: const Text('Cancel'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(value: _downloadProgress),
                  const SizedBox(height: 2),
                  Text(
                    '${(_downloadProgress * 100).toStringAsFixed(1)}%',
                    style: const TextStyle(fontSize: 11),
                    textAlign: TextAlign.end,
                  ),
                ],
              ),
            ),

          // ── APK list ────────────────────────────────────────────────────
          Expanded(child: _buildBody(colorScheme)),
        ],
      ),
    );
  }

  Widget _buildBody(ColorScheme colorScheme) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadApks,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    final apks = _apks ?? [];
    if (apks.isEmpty) {
      return const Center(child: Text('No releases found in Google Drive.'));
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: apks.length,
      separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
      itemBuilder: (context, i) => _ApkTile(
        entry: apks[i],
        currentBuild: _currentBuild,
        isDownloading: _downloadingFileId == apks[i].fileId,
        downloadProgress: _downloadingFileId == apks[i].fileId
            ? _downloadProgress
            : 0,
        onInstall: _downloadingFileId == null ? () => _install(apks[i]) : null,
      ),
    );
  }
}

// ── Tile widget ────────────────────────────────────────────────────────────

String _changelogPreview(String changelog) {
  final firstLine = changelog
      .split('\n')
      .firstWhere((l) => l.trim().isNotEmpty, orElse: () => '')
      .trim();
  if (firstLine.isEmpty) return '';
  return firstLine.length <= 80 ? firstLine : '${firstLine.substring(0, 77)}…';
}

void _showChangelogDialog(
  BuildContext context,
  StoreApkEntry entry,
  VoidCallback? onInstall,
) {
  showDialog<void>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text('Changelog · ${_formatTimestamp(entry.timestamp)}'),
      content: SingleChildScrollView(
        child: Text(
          entry.changelog!,
          style: const TextStyle(fontSize: 13, height: 1.55),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        if (onInstall != null)
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(context);
              onInstall();
            },
            icon: const Icon(Icons.download_outlined),
            label: const Text('Install'),
          ),
      ],
    ),
  );
}

class _ApkTile extends StatelessWidget {
  final StoreApkEntry entry;
  final DateTime currentBuild;
  final bool isDownloading;
  final double downloadProgress;
  final VoidCallback? onInstall;

  const _ApkTile({
    required this.entry,
    required this.currentBuild,
    required this.isDownloading,
    required this.downloadProgress,
    required this.onInstall,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isCurrent = entry.buildId == kBuildTimestamp;
    final isNewer = entry.timestamp.isAfter(currentBuild);

    Color leadingColor;
    IconData leadingIcon;
    String chipLabel;

    if (isCurrent) {
      leadingColor = colorScheme.primary;
      leadingIcon = Icons.check_circle_outline;
      chipLabel = 'Installed';
    } else if (isNewer) {
      leadingColor = Colors.green;
      leadingIcon = Icons.arrow_circle_up_outlined;
      chipLabel = 'Newer';
    } else {
      leadingColor = colorScheme.onSurface.withValues(alpha: 0.35);
      leadingIcon = Icons.history;
      chipLabel = 'Older';
    }

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: leadingColor.withValues(alpha: 0.15),
        child: Icon(leadingIcon, color: leadingColor),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              _formatTimestamp(entry.timestamp),
              style: TextStyle(
                fontWeight: isCurrent || isNewer
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
          ),
          const SizedBox(width: 8),
          _Chip(label: chipLabel, color: leadingColor),
        ],
      ),
      subtitle: isDownloading
          ? Padding(
              padding: const EdgeInsets.only(top: 4),
              child: LinearProgressIndicator(value: downloadProgress),
            )
          : entry.changelog != null
          ? Text(
              '${_changelogPreview(entry.changelog!)}  •  ${_formatBytes(entry.sizeBytes)}',
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            )
          : Text(
              '${entry.fileName}  •  ${_formatBytes(entry.sizeBytes)}',
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
      trailing: isCurrent
          ? null
          : isDownloading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : IconButton(
              icon: const Icon(Icons.download_outlined),
              tooltip: isNewer
                  ? 'Update to this version'
                  : 'Install this version',
              onPressed: onInstall,
            ),
      onTap: entry.changelog != null
          ? () => _showChangelogDialog(
              context,
              entry,
              isCurrent ? null : onInstall,
            )
          : isCurrent || onInstall == null
          ? null
          : onInstall,
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}

// ── Thin shim to reach the existing MethodChannel ─────────────────────────
// (mirrors the channel name used in InstallService)

class MethodChannelInstall {
  static const _channel = MethodChannel('com.vr.appmanager/install');

  const MethodChannelInstall._();
}
