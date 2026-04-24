import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../services/download_service.dart';
import '../utils/localization.dart';

// Active statuses — jobs still in flight.
const _kActiveStatuses = {'queued', 'downloading', 'extracting', 'uploading'};

Color _statusColor(String? status) {
  switch (status) {
    case 'downloading':
      return const Color(0xFF229ED9);
    case 'extracting':
      return const Color(0xFFF0A500);
    case 'uploading':
      return const Color(0xFFBC8CFF);
    case 'queued':
    default:
      return Colors.grey;
  }
}

/// Full-screen download queue showing active jobs and history.
class DownloadQueueScreen extends StatefulWidget {
  const DownloadQueueScreen({super.key});

  @override
  State<DownloadQueueScreen> createState() => _DownloadQueueScreenState();
}

class _DownloadQueueScreenState extends State<DownloadQueueScreen> {
  List<Map<String, dynamic>> _jobs = [];
  Timer? _timer;
  bool _historyExpanded = true;

  // Speed-meter: per-job rolling sample lists.
  // Map<jobId, List<{progress: double, ts: DateTime}>>
  final Map<int, List<_ProgressSample>> _samples = {};

  @override
  void initState() {
    super.initState();
    _loadJobs();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _loadJobs());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadJobs() async {
    try {
      final jobs = await DownloadService().listJobs();
      if (!mounted) return;
      // Update speed-meter samples.
      final now = DateTime.now();
      for (final job in jobs) {
        final id = job['id'] as int?;
        if (id == null) continue;
        final progress = (job['progress'] as num?)?.toDouble() ?? 0.0;
        final list = _samples.putIfAbsent(id, () => []);
        list.add(_ProgressSample(progress: progress, ts: now));
        if (list.length > 12) list.removeAt(0);
      }
      setState(() => _jobs = jobs);
    } catch (_) {
      // silently ignore
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _cancelOrDelete(int jobId) async {
    try {
      await DownloadService().cancelOrDelete(jobId);
      _samples.remove(jobId);
      await _loadJobs();
    } catch (e) {
      _snack('${tr('Error')}: $e');
    }
  }

  Future<void> _clearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Clear History')),
        content: Text(tr('Remove all finished download records?')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr('Clear All')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await DownloadService().clearHistory();
      await _loadJobs();
    } catch (e) {
      _snack('${tr('Error')}: $e');
    }
  }

  // ── Speed / ETA helpers ───────────────────────────────────────────────────

  _SpeedEta _computeSpeedEta(int jobId, double currentProgress) {
    final list = _samples[jobId] ?? [];
    if (list.length < 2) return const _SpeedEta(null, null);
    final oldest = list.first;
    final newest = list.last;
    final deltaT = newest.ts.difference(oldest.ts).inMilliseconds / 1000.0;
    if (deltaT <= 0) return const _SpeedEta(null, null);
    final deltaP = newest.progress - oldest.progress;
    final speedPps = deltaP / deltaT; // percent per second
    if (speedPps <= 0) return _SpeedEta(speedPps, null);
    final remaining = 100.0 - currentProgress;
    final etaSec = remaining / speedPps;
    return _SpeedEta(speedPps, etaSec);
  }

  String _formatEta(double etaSec) {
    final s = etaSec.round();
    if (s < 60) return '${s}s';
    final m = s ~/ 60;
    final rem = s % 60;
    return rem == 0 ? '${m}m' : '${m}m ${rem}s';
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final active = _jobs
        .where((j) => _kActiveStatuses.contains(j['status']?.toString()))
        .toList();
    final finished = _jobs
        .where((j) => !_kActiveStatuses.contains(j['status']?.toString()))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Download Queue')),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: tr('Refresh'),
            onPressed: _loadJobs,
          ),
        ],
      ),
      body: _jobs.isEmpty
          ? Center(child: Text(tr('No download jobs')))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (active.isNotEmpty) ...[
                  _SectionHeader(title: tr('Active')),
                  const SizedBox(height: 8),
                  ...active.map(
                    (job) => _ActiveJobCard(
                      job: job,
                      speedEta: _computeSpeedEta(
                        job['id'] as int,
                        (job['progress'] as num?)?.toDouble() ?? 0.0,
                      ),
                      formatEta: _formatEta,
                      onCancel: () => _cancelOrDelete(job['id'] as int),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (finished.isNotEmpty) ...[
                  _HistorySectionHeader(
                    isExpanded: _historyExpanded,
                    onToggle: () =>
                        setState(() => _historyExpanded = !_historyExpanded),
                    onClearAll: _clearHistory,
                  ),
                  if (_historyExpanded) ...[
                    const SizedBox(height: 8),
                    ...finished.map(
                      (job) => _HistoryJobCard(
                        job: job,
                        onDelete: () => _cancelOrDelete(job['id'] as int),
                      ),
                    ),
                  ],
                ],
              ],
            ),
    );
  }
}

// ── Section headers ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    );
  }
}

class _HistorySectionHeader extends StatelessWidget {
  final bool isExpanded;
  final VoidCallback onToggle;
  final VoidCallback onClearAll;

  const _HistorySectionHeader({
    required this.isExpanded,
    required this.onToggle,
    required this.onClearAll,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(8),
            child: Row(
              children: [
                Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
                const SizedBox(width: 4),
                Text(
                  tr('History'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.delete_sweep),
          tooltip: tr('Clear All'),
          onPressed: onClearAll,
        ),
      ],
    );
  }
}

// ── Active job card ───────────────────────────────────────────────────────────

class _ActiveJobCard extends StatelessWidget {
  final Map<String, dynamic> job;
  final _SpeedEta speedEta;
  final String Function(double) formatEta;
  final VoidCallback onCancel;

  const _ActiveJobCard({
    required this.job,
    required this.speedEta,
    required this.formatEta,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final app = job['apps'] as Map<String, dynamic>?;
    final String appName =
        app?['name'] ?? app?['title'] ?? 'App #${job['app_id']}';
    final String? thumbUrl =
        app?['preview_photo']?.toString() ?? app?['thumbnail_url']?.toString();
    final double progress = (job['progress'] as num?)?.toDouble() ?? 0.0;
    final String status = job['status']?.toString() ?? '';
    final String step = job['step']?.toString() ?? '';

    String captionParts = '$progress%';
    if (job['elapsed'] != null) captionParts += ' · ${job['elapsed']}';
    String? speedLabel;
    if (speedEta.speedPps != null && speedEta.speedPps! > 0) {
      speedLabel = '${speedEta.speedPps!.toStringAsFixed(1)}%/s';
      if (speedEta.etaSec != null) {
        speedLabel += ' · ETA ${formatEta(speedEta.etaSec!)}';
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: thumbUrl != null && thumbUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: thumbUrl,
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) => _PlaceholderThumb(),
                    )
                  : _PlaceholderThumb(),
            ),
            const SizedBox(width: 12),
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          appName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      _StatusChip(status: status),
                    ],
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: progress / 100.0,
                    backgroundColor: Colors.grey.shade700,
                    color: _statusColor(status),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    step.isNotEmpty ? '$step · $captionParts' : captionParts,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  if (speedLabel != null)
                    Text(
                      speedLabel,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                ],
              ),
            ),
            // Cancel
            IconButton(
              icon: const Icon(Icons.cancel_outlined),
              tooltip: tr('Cancel'),
              onPressed: onCancel,
            ),
          ],
        ),
      ),
    );
  }
}

// ── History job card ──────────────────────────────────────────────────────────

class _HistoryJobCard extends StatelessWidget {
  final Map<String, dynamic> job;
  final VoidCallback onDelete;

  const _HistoryJobCard({required this.job, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final app = job['apps'] as Map<String, dynamic>?;
    final String appName =
        app?['name'] ?? app?['title'] ?? 'App #${job['app_id']}';
    final String? thumbUrl =
        app?['preview_photo']?.toString() ?? app?['thumbnail_url']?.toString();
    final String status = job['status']?.toString() ?? '';
    final String? finishedAt =
        job['finished_at']?.toString() ?? job['updated_at']?.toString();

    Color statusColor;
    switch (status) {
      case 'done':
        statusColor = Colors.green;
        break;
      case 'error':
        statusColor = Colors.red;
        break;
      case 'cancelled':
        statusColor = Colors.orange;
        break;
      default:
        statusColor = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: thumbUrl != null && thumbUrl.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: thumbUrl,
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  errorWidget: (_, _, _) => _PlaceholderThumb(size: 48),
                )
              : _PlaceholderThumb(size: 48),
        ),
        title: Text(appName, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: finishedAt != null
            ? Text(
                _shortDateTime(finishedAt),
                style: const TextStyle(fontSize: 11),
              )
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _StatusChip(status: status, color: statusColor),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: tr('Delete'),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }

  String _shortDateTime(String raw) {
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    return '${dt.year}-${_p(dt.month)}-${_p(dt.day)}  ${_p(dt.hour)}:${_p(dt.minute)}';
  }

  String _p(int v) => v.toString().padLeft(2, '0');
}

// ── Small reusables ───────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  final String status;
  final Color? color;
  const _StatusChip({required this.status, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.withValues(alpha: 0.6)),
      ),
      child: Text(
        status,
        style: TextStyle(fontSize: 11, color: c, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _PlaceholderThumb extends StatelessWidget {
  final double size;
  const _PlaceholderThumb({this.size = 64});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      color: Colors.grey.shade800,
      child: const Icon(Icons.vrpano, color: Colors.white38),
    );
  }
}

// ── Speed / ETA data class ────────────────────────────────────────────────────

class _ProgressSample {
  final double progress;
  final DateTime ts;
  const _ProgressSample({required this.progress, required this.ts});
}

class _SpeedEta {
  final double? speedPps;
  final double? etaSec;
  const _SpeedEta(this.speedPps, this.etaSec);
}

// ── Public badge widget used by MainScreen ────────────────────────────────────

/// A small colored circle badge overlaid on top of a child widget.
/// Shows [count] when > 0.
class DownloadQueueBadge extends StatelessWidget {
  final Widget child;
  final int count;
  const DownloadQueueBadge({
    super.key,
    required this.child,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return child;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          right: -4,
          top: -4,
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(
              color: Color(0xFF229ED9),
              shape: BoxShape.circle,
            ),
            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
            child: Text(
              count > 9 ? '9+' : '$count',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }
}
