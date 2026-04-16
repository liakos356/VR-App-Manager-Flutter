content = """import 'package:flutter/material.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:installed_apps/app_info.dart';

class InstalledAppsScreen extends StatefulWidget {
  const InstalledAppsScreen({super.key});

  @override
  State<InstalledAppsScreen> createState() => _InstalledAppsScreenState();
}

class _InstalledAppsScreenState extends State<InstalledAppsScreen> {
  List<AppInfo> _installedApps = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInstalledApps();
  }

  Future<void> _loadInstalledApps() async {
    setState(() {
      _isLoading = true;
    });
    try {
      List<AppInfo> apps = await InstalledApps.getInstalledApps(
        excludeSystemApps: true, 
        withIcon: true,
      );
      
      setState(() {
        _installedApps = apps;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;        _isLoading = false;        _isLoading = false;        _isL          _isLoading = false;        _isLoading t conte        _isLoading = false;        _isLoading = fnter        _isLoading = false;        _isLoading           _isLoading = false;        _isLoading = t Center(child: Text("No user installed apps f      ));
    }

    return ListView.builder(
      itemCount: _installedApps.length,
                                                                   dApps[                                                             !=                                or                    48,                           : co                                             title: Text(app.name ?? "Unknown App"),
                  :                   :                   :                   :                        :             trailing: IconButton(
            icon: const Icon(Icons.launch),
            onPressed: () {
              if (app.packageName != null) {
                InstalledApps.startApp(app.packageName!);
              }
            },
            tooltip: 'Launch App',
          ),
        );
      },
    );
  }
}
"""
with open("lib/screens/installed_apps_screen.dart", "w") as f:
    f.write(content)
