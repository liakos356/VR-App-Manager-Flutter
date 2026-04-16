import re
import os

with open("lib/widgets/app_card.dart", "r") as f:
    content = f.read()

# Add import if missing
if "package:installed_apps/installed_apps.dart" not in content:
    content = content.replace("import 'package:provider/provider.dart';", "import 'package:provider/provider.dart';\nimport 'package:installed_apps/installed_apps.dart';")

# Add state variables
state_vars = """
  bool _isInstalling = false;
  double _installProgress = 0.0;
  String _installStatusStr = 'Starting...';

  bool _isInstalled = false;

  @override
  void initState() {
    super.initState();
    _checkIsInstalled();
  }

  Future<void> _checkIsInstalled() async {
    final String appId = widget.app['id']?.toString() ?? widget.app['package_name']?.toString() ?? '';
    if (appId.isNotEmpty) {
      try {
        final isInstalled = await InstalledApps.isAppInstalled(appId);
        if (mounted) {
          setState(() {
            _isInstalled = isInstalled ?? false;
          });
                                    
  }
"""

cococococore.sub(r'bool _isInstalling = false;\s*double _instalcococococore.sub(r'botricococococore.sub(rtr = \cococococore.sub(r'bool _isInstalling = false;\s*double install cococococore.sub(r'bool _isInstalling = false;\s*double _instalcococococore.sub(r'botricococococore.sub(rtr = \cococococore.sub(r'bool _isInstalling = false;\s*double inIconcococococore.s        cococns.download,cococococore.sub(r'bool olor: Theme.of(context).primaryColor,
                                           label: Text(
                       r('Instal                                       tyle(
                        color                        color                                      color                        color                                      color             side: BorderSide(
                        color: Theme.of(context).primaryColor,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.                        borderRadiu )                      ),
                  ),"""

install_btn_grid_new = """                  child: _isInstalled
                      ? OutlinedButton.icon(
                          onPressed: () async {
                              final String appId = widget.app['id']?.toString() ?? widget.app['package_name']?.toString() ?? '';
                              if (appId.isNotEmpty) {
                                await InstalledApps.uninstallApp(appId);
                                _checkIsInstalled()                                _checkIsInstalled()                                      icon: Icon(
                            Icons.delete,
                            color: Colors.red,
                          ),
                          label: Text(
                                                                                    St                                                                                  ),
                          ),
                          style: OutlinedButton.styleFrom(
                                       rSide(
                              color: Colors.red,
                                                                                                                                                                                                                                                                                              icon(
                          onPressed: _showInstallBottomSheet,
                                                                                                                                                                                                            label: Text(
                            tr('Install'),
                            style: TextStyle(
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                                                                               or: Theme.of(context).primaryColor,
                                                           sh                                                           sh                                                           sh                                                           sh                                                           sh                                              "                                                                                                                          sh                                                           sh                                                           sh                             levat                                                    padding: const EdgeInsets.symmetric(
                                  horizontal: 48,
                                  vertical: 16,
                                ),
                                textStyle: const TextSt                                textStyle: const TextSt                                textStyle: const TextSt old,
                                ),
                              ),
                            ),"""

install_btn_detail_new = """                            _isInstalled
                                ? ElevatedButton.icon(
                                    onPressed: () async {
                                        final String appId = widget.app['id']?.toString() ?? widget.app['package_name']?.toString() ?? '';
                                        if (appId.isNotEmpty) {
                                          await InstalledApps.uninstallApp(appId);
                                          _checkIsInstalled();
                                        }
                                    },
                                                  on(Ic                                                                                                                                     on(Ic                                                                                                                   f                            ,
                                                                      ric                                                                                                                                                                                                                                                            ric                                                              Weight: FontWeight.bold,
                                      ),
                                    ),
                                  )
                                : ElevatedButton.icon(
                                    onPressed: _showInstallB                                    o           icon: const Icon(Icons.download),
                                    label: Text(tr('Install')),
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 48,
                                                                                                                                                                                                                                                                                                                                                                                                                                                        ontent                           btn_detail_old,                                 en("li                            ") as f:
    f.write(content)

