import 'dart:convert';

import 'package:http/http.dart' as http;

const String kDownloadServerBaseUrl = 'http://100.95.32.89:8100/api';

/// Singleton that communicates with the Telegram → Google Drive download server.
class DownloadService {
  DownloadService._();
  static final DownloadService _instance = DownloadService._();
  factory DownloadService() => _instance;

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Throws a [DownloadServiceException] for non-2xx responses, extracting the
  /// `detail` field from the JSON body when present.
  void _checkResponse(http.Response res, String url) {
    if (res.statusCode >= 200 && res.statusCode < 300) return;
    String detail = 'HTTP ${res.statusCode} @ $url — body: ${res.body}';
    try {
      final body = jsonDecode(res.body);
      if (body is Map && body['detail'] != null) {
        detail = '${body['detail']} (HTTP ${res.statusCode} @ $url)';
      }
    } catch (_) {}
    throw DownloadServiceException(detail);
  }

  // ── Public API ────────────────────────────────────────────────────────────

  /// POST /downloads — enqueues a download job for [appId].
  /// Returns the created job row as a Map.
  Future<Map<String, dynamic>> enqueue(int appId) async {
    final url = '$kDownloadServerBaseUrl/downloads';
    final res = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'app_id': appId}),
    );
    _checkResponse(res, url);
    return (jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// GET /downloads — returns all jobs (newest first), each with joined `apps`.
  Future<List<Map<String, dynamic>>> listJobs() async {
    final url = '$kDownloadServerBaseUrl/downloads';
    final res = await http.get(Uri.parse(url));
    _checkResponse(res, url);
    final decoded = jsonDecode(res.body);
    return (decoded as List).cast<Map<String, dynamic>>();
  }

  /// DELETE /downloads/{jobId} — cancels an active job or removes a finished one.
  Future<void> cancelOrDelete(int jobId) async {
    final url = '$kDownloadServerBaseUrl/downloads/$jobId';
    final res = await http.delete(Uri.parse(url));
    _checkResponse(res, url);
  }

  /// DELETE /downloads/history — bulk-deletes all finished jobs.
  Future<void> clearHistory() async {
    final url = '$kDownloadServerBaseUrl/downloads/history';
    final res = await http.delete(Uri.parse(url));
    _checkResponse(res, url);
  }
}

class DownloadServiceException implements Exception {
  final String message;
  const DownloadServiceException(this.message);

  @override
  String toString() => 'DownloadServiceException: $message';
}
