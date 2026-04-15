import re

with open('lib/main.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# All texts that need replacing exactly as they appear in the file.
replace_map = {
    "Text('Screenshots'": "Text(tr('Screenshots')'",
    "Text('Clear history'": "Text(tr('Clear history')'",
    "Text('Ovrport Only'": "Text(tr('Ovrport Only')'",
    "Text('Cancel'": "Text(tr('Cancel')'",
    "Text('Done'": "Text(tr('Done')'",
    "Text('Watch Trailer'": "Text(tr('Watch Trailer')'",
    "Text('Installation Completed!'": "Text(tr('Installation Completed!')'",
    "Text('Ovrport'": "Text(tr('Ovrport')'",
    "Text('Do you want to send this app to your headset for installation?'": "Text(tr('Do you want to send this app to your headset for installation?')'",
    "Text('Could not launch trailer'": "Text(tr('Could not launch trailer')'",
    "Text('Invalid Object: App ID is empty'": "Text(tr('Invalid Object: App ID is empty')'",
}

for k, v in replace_map.items():
    content = content.re    content = content.re    contenfor interpola    content = content.re    content = content.re    laye    content = contentnt     content = content.re    content = content.re    contenfor inte\)    conten          content = content.re    content = content.resplay    content = content.re    content = content.re    conte    content = content.re    content = c'\)",
                                                   ')                                     $e                                                   ')\)",
                 r"Text(tr('Installation Failed: ') + '$e')", content)

# 'S# 'S# 'S# 'S# 'S# 'S# 'S# 'S# 'S# 'S# 'S# ')}# 'S# 'S# 'S# 'S# 'S# 'S# 'S# 'S# 'S# 'S# 'S# ')}# 'S# 'S# 'S# 'S# 'S# 'S# 'S# 'S# 'S# 'S# 'S# ')}# 'S# 'S# 'S# 'S# 'S# 'S# 'S# 'S# 'S# 'S# 'S# ')}# 'S#Siz# 'S# 'S# 'S# 'S# 'S# 'S# 'S# 'S# 'S# 'S# 'S# ')}# 'S# 'S# 'S# 'S# 'S# 'S# 'S['title']) ?? widget.app['title']) ?? 'App'}?'
# Actually, the string in the file is: 'Install ${...}?'
content = content.replace("'Install ${((widget.app['name'] ?? widget.app['title']) ?? widget.app['title']) ?? 'App'}?'",
                          "tr('Install App?')")

with open('lib/main.dart', 'w', encoding='utf-8') as f:
    f.write(content)

