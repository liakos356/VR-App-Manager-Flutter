import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../screens/oauth_webview_screen.dart';

// ── OAuth constants ───────────────────────────────────────────────────────────

const _kClientId =
    '1012473018198-r4fbunv4mq4mo0fegafkmqeoorllqr1v.apps.googleusercontent.com';
const _kRedirectUri =
    'com.googleusercontent.apps.1012473018198-r4fbunv4mq4mo0fegafkmqeoorllqr1v:/oauth2redirect';
const _kScopes = 'email profile https://www.googleapis.com/auth/drive.readonly';

// ── SharedPreferences keys ────────────────────────────────────────────────────

const _spAccessToken = 'gdrive_access_token';
const _spRefreshToken = 'gdrive_refresh_token';
const _spTokenExpiry = 'gdrive_token_expiry';
const _spUserEmail = 'gdrive_user_email';
const _spUserName = 'gdrive_user_name';
const _spUserPhoto = 'gdrive_user_photo';

// ── Data classes ──────────────────────────────────────────────────────────────

/// Minimal user info returned after authentication.
class GoogleUserInfo {
  final String email;
  final String? displayName;
  final String? photoUrl;

  const GoogleUserInfo({required this.email, this.displayName, this.photoUrl});
}

/// A single `YYYYMMDD_HHMM_store.apk` entry found on Google Drive.
class StoreApkEntry {
  final String fileId;
  final String fileName;
  final DateTime timestamp;
  final int sizeBytes;

  /// The changelog stored as the Drive file's description field.
  /// Null when no description has been set for this release.
  final String? changelog;

  const StoreApkEntry({
    required this.fileId,
    required this.fileName,
    required this.timestamp,
    required this.sizeBytes,
    this.changelog,
  });

  /// The `YYYYMMDD_HHMM` portion used as a human-readable build identifier.
  String get buildId {
    final y = timestamp.year.toString().padLeft(4, '0');
    final mo = timestamp.month.toString().padLeft(2, '0');
    final d = timestamp.day.toString().padLeft(2, '0');
    final h = timestamp.hour.toString().padLeft(2, '0');
    final mi = timestamp.minute.toString().padLeft(2, '0');
    return '$y$mo${d}_$h$mi';
  }
}

// ── Service ───────────────────────────────────────────────────────────────────

/// Singleton that manages Google OAuth 2.0 tokens and Drive file access.
///
/// Uses a PKCE-based web OAuth flow via an embedded [OAuthWebViewScreen],
/// which works on all platforms including Android devices without Google Play
/// Services (e.g. Pico 4).
class GoogleDriveService {
  GoogleDriveService._();
  static final GoogleDriveService _instance = GoogleDriveService._();
  factory GoogleDriveService() => _instance;

  static const String _prefix = 'google_drive/';

  /// Notifier for the currently signed-in user (null when signed out).
  final ValueNotifier<GoogleUserInfo?> userNotifier = ValueNotifier(null);

  bool get isSignedIn => userNotifier.value != null;

  String? _accessToken;
  DateTime? _tokenExpiry;

  // ── Auth ────────────────────────────────────────────────────────────────────

  /// Restores a previous session using a stored refresh token — no UI shown.
  Future<void> signInSilently() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final refreshToken = prefs.getString(_spRefreshToken);
      if (refreshToken == null) return;
      await _refreshAccessToken(refreshToken);
      await _loadUserInfoFromPrefs();
    } catch (e) {
      debugPrint('[GoogleDriveService] Silent sign-in failed: $e');
    }
  }

  /// Opens the Google OAuth WebView. Returns `true` on success.
  Future<bool> startOAuthFlow(BuildContext context) async {
    final codeVerifier = _generateCodeVerifier();
    final authUrl = _buildAuthUrl(codeVerifier);
    debugPrint('[GoogleDriveService] Opening OAuth URL: $authUrl');

    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => OAuthWebViewScreen(authUrl: authUrl),
        fullscreenDialog: true,
      ),
    );

    debugPrint(
      '[GoogleDriveService] OAuth returned code: ${code != null ? 'YES (length=${code.length})' : 'NULL'}',
    );
    if (code == null) return false;

    await _exchangeCode(code, codeVerifier);
    await _fetchAndSaveUserInfo();
    return true;
  }

  /// Clears all tokens and signs out.
  Future<void> signOut() async {
    _accessToken = null;
    _tokenExpiry = null;
    _folderIdCache.clear();
    userNotifier.value = null;
    final prefs = await SharedPreferences.getInstance();
    for (final key in [
      _spAccessToken,
      _spRefreshToken,
      _spTokenExpiry,
      _spUserEmail,
      _spUserName,
      _spUserPhoto,
    ]) {
      await prefs.remove(key);
    }
  }

  // ── PKCE OAuth helpers ───────────────────────────────────────────────────────

  String _generateCodeVerifier() {
    final rng = Random.secure();
    final bytes = List<int>.generate(32, (_) => rng.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  String _buildAuthUrl(String codeVerifier) {
    return Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
      'client_id': _kClientId,
      'redirect_uri': _kRedirectUri,
      'response_type': 'code',
      'scope': _kScopes,
      'access_type': 'offline',
      'code_challenge': codeVerifier, // plain PKCE — no crypto dep needed
      'code_challenge_method': 'plain',
      'prompt': 'select_account',
    }).toString();
  }

  Future<void> _exchangeCode(String code, String codeVerifier) async {
    final response = await http.post(
      Uri.parse('https://oauth2.googleapis.com/token'),
      body: {
        'grant_type': 'authorization_code',
        'code': code,
        'client_id': _kClientId,
        'redirect_uri': _kRedirectUri,
        'code_verifier': codeVerifier,
      },
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Token exchange failed (${response.statusCode}): ${response.body}',
      );
    }
    await _saveTokenResponse(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> _refreshAccessToken(String refreshToken) async {
    final response = await http.post(
      Uri.parse('https://oauth2.googleapis.com/token'),
      body: {
        'grant_type': 'refresh_token',
        'refresh_token': refreshToken,
        'client_id': _kClientId,
      },
    );
    if (response.statusCode != 200) {
      throw Exception('Token refresh failed: ${response.body}');
    }
    await _saveTokenResponse(
      jsonDecode(response.body) as Map<String, dynamic>,
      keepRefreshToken: true,
    );
  }

  Future<void> _saveTokenResponse(
    Map<String, dynamic> json, {
    bool keepRefreshToken = false,
  }) async {
    _accessToken = json['access_token'] as String?;
    final expiresIn = (json['expires_in'] as num?)?.toInt() ?? 3600;
    _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn - 60));

    final prefs = await SharedPreferences.getInstance();
    if (_accessToken != null) {
      await prefs.setString(_spAccessToken, _accessToken!);
    }
    await prefs.setInt(_spTokenExpiry, _tokenExpiry!.millisecondsSinceEpoch);

    if (!keepRefreshToken) {
      final refreshToken = json['refresh_token'] as String?;
      if (refreshToken != null) {
        await prefs.setString(_spRefreshToken, refreshToken);
      }
    }
  }

  Future<void> _fetchAndSaveUserInfo() async {
    try {
      final token = await _getValidToken();
      final response = await http.get(
        Uri.parse('https://www.googleapis.com/oauth2/v1/userinfo?alt=json'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final email = (json['email'] as String?) ?? '';
        final name = json['name'] as String?;
        final photo = json['picture'] as String?;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_spUserEmail, email);
        if (name != null) await prefs.setString(_spUserName, name);
        if (photo != null) await prefs.setString(_spUserPhoto, photo);

        userNotifier.value = GoogleUserInfo(
          email: email,
          displayName: name,
          photoUrl: photo,
        );
      }
    } catch (e) {
      debugPrint('[GoogleDriveService] fetchUserInfo error: $e');
    }
  }

  Future<void> _loadUserInfoFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString(_spUserEmail);
    if (email != null && email.isNotEmpty) {
      userNotifier.value = GoogleUserInfo(
        email: email,
        displayName: prefs.getString(_spUserName),
        photoUrl: prefs.getString(_spUserPhoto),
      );
    }
  }

  Future<String> _getValidToken() async {
    if (_accessToken != null &&
        _tokenExpiry != null &&
        DateTime.now().isBefore(_tokenExpiry!)) {
      return _accessToken!;
    }
    final prefs = await SharedPreferences.getInstance();
    final refreshToken = prefs.getString(_spRefreshToken);
    if (refreshToken != null) {
      await _refreshAccessToken(refreshToken);
      if (_accessToken != null) return _accessToken!;
    }
    throw Exception('Not signed in. Please sign in to Google Drive.');
  }

  // ── Drive API helpers ────────────────────────────────────────────────────────

  Future<drive.DriveApi> _api() async {
    final token = await _getValidToken();
    return drive.DriveApi(_BearerClient(token));
  }

  final Map<String, String> _folderIdCache = {};

  Future<String?> _traverseFolders(
    drive.DriveApi api,
    List<String> names,
  ) async {
    String parentId = 'root';
    for (final name in names) {
      final key = '$parentId/$name';
      if (_folderIdCache.containsKey(key)) {
        parentId = _folderIdCache[key]!;
        continue;
      }
      final escaped = name.replaceAll("'", r"\'");
      final result = await api.files.list(
        q:
            "mimeType='application/vnd.google-apps.folder' "
            "and name='$escaped' "
            "and '$parentId' in parents "
            "and trashed=false",
        spaces: 'drive',
        $fields: 'files(id)',
      );
      if (result.files == null || result.files!.isEmpty) return null;
      final id = result.files!.first.id!;
      _folderIdCache[key] = id;
      parentId = id;
    }
    return parentId;
  }

  // ── Public Drive operations ──────────────────────────────────────────────────

  /// Returns `true` if [path] uses the `google_drive/` scheme.
  static bool isDrivePath(String path) => path.startsWith(_prefix);

  /// Resolves a `google_drive/…` path to a Drive file ID.
  Future<String?> resolveFileId(String drivePath) async {
    if (!drivePath.startsWith(_prefix)) return null;
    final parts = drivePath
        .substring(_prefix.length)
        .split('/')
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return null;

    final fileName = parts.last;
    final folderNames = parts.sublist(0, parts.length - 1);

    final api = await _api();
    final parentId = folderNames.isEmpty
        ? 'root'
        : await _traverseFolders(api, folderNames);
    if (parentId == null) return null;

    final escaped = fileName.replaceAll("'", r"\'");
    final result = await api.files.list(
      q: "name='$escaped' and '$parentId' in parents and trashed=false",
      spaces: 'drive',
      $fields: 'files(id)',
    );
    if (result.files == null || result.files!.isEmpty) return null;
    return result.files!.first.id;
  }

  /// Returns the byte size of a Drive file.
  Future<int> getFileSize(String fileId) async {
    final api = await _api();
    final meta = await api.files.get(fileId, $fields: 'size') as drive.File;
    return int.tryParse(meta.size ?? '0') ?? 0;
  }

  /// Lists all files directly inside a `google_drive/…` folder path.
  Future<List<drive.File>> listFiles(String driveFolderPath) async {
    if (!driveFolderPath.startsWith(_prefix)) return const [];
    final parts = driveFolderPath
        .substring(_prefix.length)
        .split('/')
        .where((p) => p.isNotEmpty)
        .toList();

    final api = await _api();
    final parentId = parts.isEmpty
        ? 'root'
        : await _traverseFolders(api, parts);
    if (parentId == null) return const [];

    final result = await api.files.list(
      q: "'$parentId' in parents and trashed=false",
      spaces: 'drive',
      $fields: 'files(id,name,size,mimeType,description)',
    );
    return result.files ?? const [];
  }

  /// Searches all of Drive for a file with exactly [name].
  /// Returns the first match (with id and size), or null if not found.
  Future<drive.File?> findFileByName(String name) async {
    final api = await _api();
    final escaped = name.replaceAll("'", r"\'");
    final result = await api.files.list(
      q: "name='$escaped' and trashed=false and mimeType!='application/vnd.google-apps.folder'",
      spaces: 'drive',
      $fields: 'files(id,name,size)',
      pageSize: 1,
    );
    final files = result.files;
    if (files == null || files.isEmpty) return null;
    return files.first;
  }

  // ── Store APK helpers ────────────────────────────────────────────────────────

  static const String _kStoreFolder = 'google_drive/pico4/store';

  /// Parses `YYYYMMDD_HHMM_store.apk` → [DateTime], returns null on mismatch.
  static DateTime? parseApkTimestamp(String fileName) {
    final match = RegExp(
      r'^(\d{4})(\d{2})(\d{2})_(\d{2})(\d{2})_store\.apk$',
    ).firstMatch(fileName);
    if (match == null) return null;
    return DateTime(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
      int.parse(match.group(4)!),
      int.parse(match.group(5)!),
    );
  }

  /// Lists all `*_store.apk` files in the `pico4/store` Drive folder,
  /// sorted newest-first.
  Future<List<StoreApkEntry>> listStoreApks() async {
    final files = await listFiles(_kStoreFolder);
    final entries = <StoreApkEntry>[];
    for (final f in files) {
      if (f.name == null) continue;
      final ts = parseApkTimestamp(f.name!);
      if (ts == null) continue;
      entries.add(
        StoreApkEntry(
          fileId: f.id ?? '',
          fileName: f.name!,
          timestamp: ts,
          sizeBytes: int.tryParse(f.size ?? '0') ?? 0,
          changelog: f.description?.isNotEmpty == true ? f.description : null,
        ),
      );
    }
    entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return entries;
  }

  /// Returns the latest `StoreApkEntry`, or null if none are found.
  Future<StoreApkEntry?> latestStoreApk() async {
    final list = await listStoreApks();
    return list.isEmpty ? null : list.first;
  }

  /// Downloads a Drive file to [localFile] with progress callbacks.
  Future<void> downloadFile({
    required String fileId,
    required File localFile,
    required int fileSize,
    void Function(int received, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final token = await _getValidToken();
    final client = http.Client();
    try {
      final request = http.Request(
        'GET',
        Uri.parse(
          'https://www.googleapis.com/drive/v3/files/$fileId?alt=media',
        ),
      );
      request.headers['Authorization'] = 'Bearer $token';
      final streamed = await client.send(request);

      if (streamed.statusCode != 200) {
        throw Exception('Drive download failed: HTTP ${streamed.statusCode}');
      }

      final sink = localFile.openWrite();
      int received = 0;
      try {
        await for (final chunk in streamed.stream) {
          if (isCancelled != null && isCancelled()) {
            throw Exception('Download cancelled by user');
          }
          sink.add(chunk);
          received += chunk.length;
          onProgress?.call(received, fileSize);
        }
      } finally {
        await sink.flush();
        await sink.close();
      }
      debugPrint(
        '[GoogleDriveService] Downloaded $received bytes → ${localFile.path}',
      );
    } finally {
      client.close();
    }
  }
}

// ── HTTP client with Bearer auth ──────────────────────────────────────────────

class _BearerClient extends http.BaseClient {
  final String _token;
  final http.Client _inner = http.Client();

  _BearerClient(this._token);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['Authorization'] = 'Bearer $_token';
    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}
