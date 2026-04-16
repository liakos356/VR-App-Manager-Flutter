import re

with open("lib/widgets/app_card.dart", "r") as f:
    content = f.read()

new_check = """
  Future<void> _checkIsInstalled() async {
    try {
      final installedAppsList = await InstalledApps.getInstalledApps(true, true);
      
      bool found = false;
      for (var app in installedAppsList) {
        if (app.packageName != null && app.packageName!.isNotEmpty) {
          // Check if the packageName matches ANY string value in the app map
          for (var value in widget.app.values) {
             if (value != null && value.toString() == app.packageName) {
                found = true;
                break;
             }
          }
        }
        if (found) break;
      }

      if (mounted) {
        setState(() {
          _isInstalled = found;
        });
      }
    } catch (_) {}
  }
"""

content = re.sub(r'Future<void> _checkIsInstalled\(\) async \{.*?\s*\}\s*\}', new_check, content, flags=re.DOTALL)

with open("lib/widgets/app_card.dart",with ops f:
    f.write(content)

