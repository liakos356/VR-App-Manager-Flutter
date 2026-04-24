import 'dart:async';

import 'package:flutter/foundation.dart';

import 'download_service.dart';

/// Singleton ChangeNotifier that polls the download server every 3 seconds
/// and notifies listeners when the job list changes.
///
/// Lifecycle:
///   - Call [startPolling] once (e.g. in MainScreen.initState).
///   - Call [stopPolling] in MainScreen.dispose.
class DownloadJobsNotifier extends ChangeNotifier {
  DownloadJobsNotifier._();
  static final DownloadJobsNotifier instance = DownloadJobsNotifier._();

  List<Map<String, dynamic>> jobs = [];
  int activeCount = 0;

  Timer? _timer;

  // Tracks job IDs whose "done" transition has already been notified so we
  // don't fire the "App Ready" snackbar more than once per job.
  final Set<int> _notifiedDoneIds = {};

  // Callback invoked when a job transitions to 'done'.  Assigned by the
  // consumer (MainScreen) so it can show a SnackBar without a BuildContext
  // dependency here.
  void Function(Map<String, dynamic> job)? onJobDone;

  // ── Polling control ────────────────────────────────────────────────────────

  void startPolling() {
    _timer?.cancel();
    _poll(); // immediate first fetch
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _poll());
  }

  void stopPolling() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _poll() async {
    try {
      final fetched = await DownloadService().listJobs();
      _updateJobs(fetched);
    } catch (_) {
      // Silently ignore poll errors – the UI shows stale data until next poll.
    }
  }

  void _updateJobs(List<Map<String, dynamic>> fetched) {
    jobs = fetched;
    activeCount = fetched
        .where((j) => _isActive(j['status']?.toString()))
        .length;

    // Detect "done" transitions and fire the callback once per job.
    for (final job in fetched) {
      final status = job['status']?.toString();
      final id = job['id'] as int?;
      if (status == 'done' && id != null && !_notifiedDoneIds.contains(id)) {
        _notifiedDoneIds.add(id);
        onJobDone?.call(job);
      }
    }

    notifyListeners();
  }

  // ── Query helpers ──────────────────────────────────────────────────────────

  /// Returns the most recent active-or-queued job for the given [appId],
  /// or `null` if none exists.
  Map<String, dynamic>? jobForApp(int appId) {
    for (final job in jobs) {
      final jobAppId = job['app_id'] ?? job['apps']?['id'];
      if (jobAppId == appId) return job;
    }
    return null;
  }

  /// Force an immediate poll (useful after enqueuing a new job).
  Future<void> refresh() => _poll();
}

bool _isActive(String? status) =>
    status == 'queued' ||
    status == 'downloading' ||
    status == 'extracting' ||
    status == 'uploading';
