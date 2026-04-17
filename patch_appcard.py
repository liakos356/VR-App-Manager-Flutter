import re

with open('lib/widgets/app_card.dart', 'r') as f:
    content = f.read()

# Disable install buttons if not available.
# We have a bool in _buildDetailView:
apk_path_injection = """
    final String apkPath = widget.app['apk_path']?.toString() ?? '';
    final bool hasApk = apkPath.trim().isNotEmpty;
"""

# Find _buildDetailView beginning
content = content.replace("  Widget _buildDetailView(BuildContext context, {bool showBackButton = true}) {", 
                          "  Widget _buildDetailView(BuildContext context, {bool showBackButton = true}) {" + apk_path_injection)

# Check the button in _buildDetailView. In lines 674, where onTap is:
# onTap: _isInstalling ? () { ... } : () async { ...
# we can just disable it by making onTap null if !hasApk
content = content.replace("onTap: _isInstalling\n", "onTap: !hasApk ? null : _isInstalling\n")

# We should also change the text "Install" to "Unavailable" if !hasApk
content = content.replace(": _isInstalled\n         content = content.replace(": _i  content     ? tr('Uninstall')\n                              content = content.rep   content = content.replace(": _isInstall     content = content.replace(": _is: (_iscontent = content.repla  content = content.replace(": _isInstalled\n         content = cont   content = content.replace(": _isInstalled\n      'Instalcontent = content.replace(": _isBocontent = content.replace(": _isInstalled\n         content = content.replace(": _i  content     ? tr('Uninsllcontent = content.replace(": _isInstalled\n         content = content.replace(": _i  content     ? tr('Uninstall')\n            if content = content.replace(": _isInstalled\n         content = conte vicontent = content.replace(": _isInstalled\n        a content = content.replace(": _isInstalled\n              content = content.replace(": _isInstalled\n         content = content.replace(": _i  content                        right: 8,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Unavailable',
                            style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
"""
content = content.replace("final hasMultipleImages = images.length > 1;", "final hasMultipleImages = images.length > 1;\n    final bool hasApk = (widget.app['apk_path']?.toString() ?? '').trim().isNotEmpty;")
# I need to place the chip over the image, but before the play icon.
# Let's search for "if (hasMultipleImages)" inside "children: [" under the Stack
content = content.replace("if (hasMultipleImagcontent = content.replace("if (hasMult", gcontent = content.replace("if (hasMultipleImagcontent = content.replace("if (hasMuloscontent = content.replace("if (hasMultipleImagrt', 'w') as f:
    f.write(content)
