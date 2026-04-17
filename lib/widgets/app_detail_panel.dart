import 'package:flutter/material.dart';

import '../utils/localization.dart';
import 'app_detail_view.dart';

class AppDetailPanel extends StatelessWidget {
  final dynamic app;
  final String apiUrl;

  const AppDetailPanel({super.key, required this.app, required this.apiUrl});

  @override
  Widget build(BuildContext context) {
    if (app == null) {
      return Center(child: Text(tr('Select an app to see details')));
    }

    return AppDetailView(app: app, apiUrl: apiUrl, showAsPage: false);
  }
}
