class VrApp {
  final String id;
  final String title;
  final String description;
  final String genres;
  final String apkPath;
  final String obbDir;
  final bool ovrport;
  final List<String> images;
  final String packageName;
  final String version;

  const VrApp({
    required this.id,
    required this.title,
    required this.description,
    required this.genres,
    required this.apkPath,
    required this.obbDir,
    required this.ovrport,
    required this.images,
    required this.packageName,
    required this.version,
  });

  factory VrApp.fromJson(Map<String, dynamic> json) {
    final apkStr = (json['apk_path'] ?? '').toString().trim();
    final imagesList = <String>[];

    final preview = json['preview_photo']?.toString();
    if (preview != null && preview.isNotEmpty) {
      imagesList.add(preview);
    }

    if (json['screenshots'] != null) {
      final shotsRaw = json['screenshots']
          .toString()
          .replaceAll('[', '')
          .replaceAll(']', '')
          .replaceAll('"', '')
          .split(',');
      for (var s in shotsRaw) {
        if (s.trim().isNotEmpty) {
          imagesList.add(s.trim());
        }
      }
    }

    return VrApp(
      id: (json['id'] ?? '').toString(),
      title: (json['name'] ?? json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      genres: (json['genres'] ?? json['category'] ?? '').toString(),
      apkPath: apkStr,
      obbDir: (json['obb_dir'] ?? '').toString(),
      ovrport:
          json['ovrport'] == 1 ||
          json['ovrport'] == 'true' ||
          json['ovrport'] == true,
      images: imagesList,
      packageName: (json['package_name'] ?? '').toString(),
      version: (json['version'] ?? '').toString(),
    );
  }

  bool get hasApk => apkPath.isNotEmpty;
  bool get hasMultipleImages => images.length > 1;
}
