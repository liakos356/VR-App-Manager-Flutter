import 'package:flutter/material.dart';

import '../utils/localization.dart';
import 'app_card.dart';

class AppDetailPanel extends StatelessWidget {
  final dynamic app;
  final String apiUrl;

  const AppDetailPanel({super.key, required this.app, required this.apiUrl});

  @override
  Widget build(BuildContext context) {
    if (app == null) {
      return Center(child: Text(tr('Select an app to see details')));
    }

    return AppCard(app: app, apiUrl: apiUrl, isDetailView: true);
  }
}
