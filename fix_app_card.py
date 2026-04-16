import re

with open("lib/widgets/app_card.dart", "r") as f:
    text = f.read()

# Update checkIsInstalled
target_search = "  Future<void> _checkIsInstalled() async {"

if target_search in text:
    start_idx = text.find(target_search)
    end_idx = text.find("  List<String> get _allImages {")
    if end_idx != -1:
        text = text[:start_idx] + """  Future<void> _checkIsInstalled() async {
    try {
      final installedAppsList = await InstalledApps.getInstalledApps(
        excludeSystemApps: false,
        excludeNonLaunchableApps: false,
      );
      bool found = false;
      String foundPackage = '';
      for (var a in installedAppsList) {
        if (a.packageName != null && a.packageName!.isNotEmpty) {
          for (var value in widget.app.values) {
            if (value != null && value.toString().trim().toLowerCase() == a.packageName!.trim().toLowerCase()) {
              found = true;
              foundPackage = a.packageName!.trim();
              break;
                                  }
        i        i        i        i        i         {
                (() {
           isInstalled = fou           isInstalled = fou           isInstalled = fou   n
                    ackage.                    ackage.           ['f                    ackage.                    ackage });
                     _)                     _)                     _)                     _)          f:
    f.write(text)

