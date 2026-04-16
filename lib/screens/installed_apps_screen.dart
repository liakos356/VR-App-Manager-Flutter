import 'package:flutter/material.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';

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
        _isLoading = false;
      });
      debugPrint('Error loading installed apps: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_installedApps.isEmpty) {
      return const Center(child: Text("No user installed apps found."));
    }

    return ListView.builder(
      itemCount: _installedApps.length,
      itemBuilder: (context, index) {
        final app = _installedApps[index];
        return ListTile(
          leading: app.icon != null
              ? Image.memory(app.icon!, width: 48, height: 48)
              : const Icon(Icons.android, size: 48),
          title: Text(app.name),
          subtitle: Text("${app.packageName}\nversion: ${app.versionName}"),
          isThreeLine: true,
          trailing: IconButton(
            icon: const Icon(Icons.launch),
            onPressed: () {
              InstalledApps.startApp(app.packageName);
            },
            tooltip: 'Launch App',
          ),
        );
      },
    );
  }
}
