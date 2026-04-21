import 'package:supabase_flutter/supabase_flutter.dart';

Future<List<Map<String, dynamic>>> fetchAppsFromDb(
  String smbUrl, {
  void Function(double)? onProgress,
  bool forceRefresh = false,
}) async {
  if (onProgress != null) onProgress(0.0);
  final response = await Supabase.instance.client.from('apps').select();
  if (onProgress != null) onProgress(1.0);
  return List<Map<String, dynamic>>.from(response);
}
