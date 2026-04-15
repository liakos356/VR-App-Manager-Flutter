import re

with open('lib/main.dart', 'r', encoding='utf-8') as f:
    text = f.read()

replacements = [
    "'Screenshots'", "'Ovrport Only'", "'Cancel'", "'Could not launch trailer'",
    "'Invalid Object: App ID is empty'", "'Watch Trailer'", "'Do you want to send this app to your headset for installation?'",
    "'Done'", "'Installation Completed!'", "'Clear history'", "'Ovrport'"
]

for r in replacements:
    # We want to replace Text( \n 'Screenshots', with Text( \n tr('Screenshots'),
    # So we replace the string itself if it's not already inside a tr()
    text = re.sub(r"(?<!tr\()(" + r + r")", r"tr(\1)", text)

# For interpolated
text = text.replace("'Pico 4 App Manager (${displayedApps.length})'", "tr('Pico 4 App Manager') + ' (${displayedApps.length})'")
text = text.replace("'Install Error: $e'", "tr('Install Error: ') + '$e'")
text = text.replace("'Installation Failed: $e'", "tr('Installation Failed: ') + '$e'")
text = text.replace("'Size: ${_formatBytes(_getAppSize(widget.app))}'", "tr('Size: ') + '${_fortext = text.replace("'Size: ${_formatBytes(_getAppSizeace("'Install ${((widgetext = name'] ?? text = text.replace("'Size: ${_formatBytes(_getAppSize(widget.app))}'", "tr(')")
text = text.replace("'Size: ${_formatBytes(_getAppSize(widget.app))}'", "tr('Size: ') + '${_fortext = text.replace("'Size: ${_metext = text.replace("'Size: ${_formatBytes(_getAppSize(widget.app))}'",      text = text.replac     text = text.replace("'Size: ${_formatBytes(_getAppSize(widget.app))}'", "tr('Si   text = text.replace("'Size: ${_formatBytes(_getAppSize(widget.app)) = tetext = text.replace("'Size: ${_formatBytes(_getAppSize(widgxt(text = text.repla           tr")
text = text.replace("const Text(\n                            tr", "Text(\n                            tr")
text = text = text = text = text = text = text = text = text = text = text = tekBatext = text = text = text = text = text = text = text = text = text = text = te        text = text = text = text = text = text = text = text = text = text = text = tekBatext = text = text = text = text = text = text = text = text = text = text = te        text = text = text = text = text = text = text = text = text = text = text = tekBatext = text = texf.write(text)

