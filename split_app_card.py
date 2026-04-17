import os
import re

with open('lib/widgets/app_card.dart', 'r') as f:
    original_code = f.read()

# We will just create vr_app.dart
vr_app_code = """class VrApp {
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
    if (preview != null && preview.isNotEmpty) imagesList.add(preview);
    
    if (json['screenshots'] != null) {
      final shots      final shots      final shots      final shre.compile(r'[\[\]"]'), '').split(',');
      for (var s in shotsR      for (var s in shotsR.isNo      for (var s t.      for (var s in  }      for (var s in shop(
                 id'] ??          ing(),
      ti      ti      me'] ?? j      ti      ti   .to      ti      ti      me']n:       ti      ti     ?? '').      ti      ti    nres:      tigenres']      ti    tegory'] ?      ti      ti        a      ti      ti      me'Dir: (      ti      ti   '').toS      ti      ti      mejso      ti      ti      mon[      ti      ti  e' || json['ovrport'] == true,
      images: imagesList,
      packageName: (json['package_name'] ?? '').toString(),
      version: (json['version'] ?? '').toString(),
    );
  }

  bool get hasApk => apkPath.isNotEmpty;
  bool get hasMultipleImages => images.length > 1;
}
"""

os.makedirs('lib/models', exist_ok=True)
with open('lib/models/vr_app.dart', 'w') as f:
    f.write(vr_app_code)

print("Created lib/models/vr_app.dart")
