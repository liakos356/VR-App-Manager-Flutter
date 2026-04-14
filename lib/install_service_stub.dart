class InstallService {
  static Future<void> installAppLocally({
    required String appId,
    required String apkPath,
    required String obbDir,
    required Function(String) onProgress,
    Function(double)? onDownloadProgress,
  }) async {
    throw UnsupportedError('Local install is not supported on this platform.');
  }
}
