import 'package:supabase_flutter/supabase_flutter.dart';

/// Fetches ALL apps from Supabase in batches of 1000 (the server-side max)
/// and returns them as a single flat list.
Future<List<Map<String, dynamic>>> fetchAppsFromDb(
  String smbUrl, {
  void Function(double)? onProgress,
  bool forceRefresh = false,
}) async {
  if (onProgress != null) onProgress(0.0);
  const int batchSize = 1000;
  final List<Map<String, dynamic>> all = [];
  int from = 0;
  int total = 0;

  do {
    final to = from + batchSize - 1;
    final res = await Supabase.instance.client
        .from('apps')
        .select()
        .range(from, to)
        .count(CountOption.exact);
    final batch = List<Map<String, dynamic>>.from(res.data as List);
    all.addAll(batch);
    total = res.count;
    from += batchSize;
    if (onProgress != null && total > 0) {
      onProgress((all.length / total).clamp(0.0, 1.0));
    }
  } while (all.length < total);

  if (onProgress != null) onProgress(1.0);
  return all;
}
