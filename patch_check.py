import re

with open("lib/widgets/app_card.dart", "r") as f:
    text = f.read()

new_check = """  Future<void> _checkIsInstalled() async {
    try {
      final installedAppsList = await InstalledApps.getInstalledApps(
        excludeSystemApps: false,
        excludeNonLaunchableApps: false,
      );
      bool found = false;
      String foundPackage = '';
      
      final String apkPath = widget.app['file_path_apk']?.toString().toLowerCase() ?? '';
      final String subtitle = widget.app['title']?.toString().toLowerCase() ?? '';
      final String name = widget.app['name']?.toString().toLowerCase() ?? '';
      final String id = widget.app['id']?.toString().toLowerCase() ?? '';
      final String package = widget.app['package_name']?.toString().toLowerCase() ?? '';
      
      final String titleToUse = name.isNotEmpty ? name : subtitle;
      final titleWords = titleToUse.replaceAll(RegExp(r'[^a-zA-Z0-9]'), ' ').split(' ').where((w) => w.length > 3).toList();

      for       for       for       for{
      foif       foif       foif       foif       foif     in      foif       fage      foif       foif       foif       foif       foiisMat      fose      foif       foif       foif       foif       foif     in      fel      foif       foif       foifs(      foif       foif       foif       s(pkgName)       foif       foif    p      foif       foif     {
                                                                                                   fo                                                                            widget.                                                                            rC                                                                    > 5 && (strVal == pkgName || strVal.contains(pkgName))) {
                    isMatch = true;
                                                                                  
          // 3. Fuzzy match: Check if the package name contains significant words from the title
          if (!isMatch && titleWords.isNotEmpty) {
                                                                                                                                                                                                                                                                                                                                                                            ctTit                                                                                                                                                                                                                                                                                                                                                                            ctTit               tate(() {
          _isInstalled = found          _isInstalled = found          _isInstalled = found          _isInstalleun          _isInstalled = found          _isInstalled = found          _isInstalled = found     oid> _checkIsInstalled\(\) async \{[\s\S]*?\} catch \(\_\) \{\}\n  \}', new_check, text)

with open("lib/widgets/app_card.dart", "w") as f:
    f.write(text)

