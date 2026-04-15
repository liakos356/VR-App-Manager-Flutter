
double parseRating(dynamic rating) {
  if (rating == null) return 0.0;
  double r = 0.0;
  if (rating is num) {
    r = rating.toDouble();
  } else {
    r = double.tryParse(rating.toString()) ?? 0.0;
  }
  if (r > 10) return r / 20.0; // out of 100 -> out of 5
  if (r > 5) return r / 2.0; // out of 10 -> out of 5
  return r;
}

String formatBytes(dynamic bytes) {
  if (bytes == null) return 'Unknown Size';
  int bytesInt = 0;
  if (bytes is num) {
    bytesInt = bytes.toInt();
  } else {
    bytesInt = int.tryParse(bytes.toString()) ?? 0;
  }
  if (bytesInt <= 0) return 'Unknown Size';

  if (bytesInt < 1024 * 1024) {
    return '${(bytesInt / 1024).toStringAsFixed(1)} KB';
  } else if (bytesInt < 1024 * 1024 * 1024) {
    return '${(bytesInt / (1024 * 1024)).toStringAsFixed(1)} MB';
  } else {
    return '${(bytesInt / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

int getAppSize(dynamic app) {
  if (app == null) return 0;
  int sizeApk = getApkSize(app);
  int sizeObb = getObbSize(app);

  int total = sizeApk + sizeObb;
  if (total == 0 && app['size_bytes'] != null) {
    total = int.tryParse(app['size_bytes'].toString()) ?? 0;
  }
  return total;
}

int getApkSize(dynamic app) {
  if (app == null || app['size_bytes_apk'] == null) return 0;
  return int.tryParse(app['size_bytes_apk'].toString()) ?? 0;
}

int getObbSize(dynamic app) {
  if (app == null || app['size_bytes_obb'] == null) return 0;
  return int.tryParse(app['size_bytes_obb'].toString()) ?? 0;
}
