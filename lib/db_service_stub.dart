Future<List<Map<String, dynamic>>> fetchAppsFromDb(
  String smbUrl, {
  void Function(double)? onProgress,
  bool forceRefresh = false,
}) async {
  throw UnimplementedError(
    'SMB Database fetch is not supported on this platform.',
  );
}
