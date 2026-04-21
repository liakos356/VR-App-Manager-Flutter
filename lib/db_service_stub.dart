import 'package:supabase_flutter/supabase_flutter.dart';

const int kPageSize = 200;

Future<({List<Map<String, dynamic>> apps, int totalCount})> fetchAppsFromDb(
  String smbUrl, {
  void Function(double)? onProgress,
  bool forceRefresh = false,
  int page = 0,
}) async {
  if (onProgress != null) onProgress(0.0);
  final from = page * kPageSize;
  final to = from + kPageSize - 1;
  final res = await Supabase.instance.client
      .from('apps')
      .select()
      .range(from, to)
      .count(CountOption.exact);
  if (onProgress != null) onProgress(1.0);
  return (
    apps: List<Map<String, dynamic>>.from(res.data as List),
    totalCount: res.count,
  );
}
