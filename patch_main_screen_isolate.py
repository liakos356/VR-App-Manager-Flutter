import re

with open('lib/screens/main_screen.dart', 'r') as f:
    text = f.read()

# Add the isolate import
if "import 'dart:isolate';" not in text:
    text = text.replace("import 'package:flutter/material.dart';", "import 'dart:isolate';\nimport 'package:flutter/material.dart';")

# Add the VrApp import
if "import '../models/vr_app.dart';" not in text:
    text = text.replace("import '../utils/formatters.dart';", "import '../utils/formatters.dart';\nimport '../models/vr_app.dart';")

# Update state variables
text = text.replace("  List<dynamic> _apps = [];\n  bool _isLoading = false;\n  double _downloadProgress = -1.0;",
                    "  List<dynamic> _apps = [];\n  bool _isLoading = false;\n  String? _errorMessage;\n  double _downloadProgress = -1.0;")

# We'll use a regex to replace _fetchApps method completely!
fetch_pattern = r"  Future<void> _fetchApps\(\{bool forceRefresh = false\}\) async \{[\s\S]*?    \}\n  \}"

optimized_fetch = """  // Backgrounoptimized_fetch = """  // BackgrounoptimizeessAppsData(Loptimized_fetch = """  // Backgrounoptimized_fetcawDaoptimized_fetch data) => VrApp.fromJson(data))optimized_fetch = """  // BackgrounchApps({bool forceRefresh = false, int attempt = 0}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _do      _do      _do   ;
      _do      _do      _do   ;
ounoptimized_fett ounoptimized_fett ounoptimized_fett ounoptimized_fett ounoptimized_fett ounoptimized_fett ounoptimized_fett ounoptimized_fett ounop  oounoptimized_fett ou) => ounoptimized_fett ounoptimized_fett ounoptimized_fett ounoptimized_fett ounoptimized_fett ounoptimized_fett ouno> _processAppsData(rawAppsList.cast<Map<String, dynamic>>()));
      
      setState(() {
        _apps = rawAppsList; // We keep dynamic in _apps for backward compatibility with the rest of UI
        _isL        _isL        _isL        _isL        _isL        _isL        _isL        _isL        _isL        _ (attempt < 2) {
        await Future.delayed(const Duration(seconds: 2));
        _fetchApps(forceRefresh: forceRefresh, attempt: attempt + 1);
      } else {
        setState(() {
          _errorMessage = "Failed to load apps. Please check your connection.";
          _isLoading = fals          _isL
                                                      ow                              ;
                      e.sub(fetch_pattern, optimized_fetch, text)

with open('lib/screens/main_screen.dart', 'w') as f:
    f.write(text)

