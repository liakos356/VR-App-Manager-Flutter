class InstallService {
  static Future<void> installAppLocally(String appId, Function(String) onProgress) async {
    throw UnsupportedError('Local install is not supported on this platform.');
  }
}
