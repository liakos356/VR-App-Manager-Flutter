import re

with open('lib/main.dart', 'r', encoding='utf-8') as f:
    text = f.read()

replacements = [
    "'Screenshots'", 
    "'Ovrport Only'", 
    "'Cancel'", 
    "'Could not launch trailer'",
    "'Invalid Object: App ID is empty'", 
    "'Watch Trailer'", 
    "'Do you want to send this app to your headset for installation?'",
    "'Done'", 
    "'Installation Completed!'", 
    "'Clear history'", 
    "'Ovrport'",
    "'Install Error: '",
    "'Installation Failed: '",
    "'Size: '",
    "'Pico 4 App Manager '"
]

for r in replacements:
    text = re.sub(r"(?<!tr\()(" + re.escape(r) + r")", r"tr(\1)", text)

text = text.replace("tr('Pico 4 App Manager ')(${displayedApps.length})'", "tr('Pico 4 App Manager') + ' (${displayedApps.length})'")

# Custom fixes for interpolated strings that might have been messed up:
text = text.replace("'tr('Install Error: ')$e'", "tr('Install Error: ') + '$e'")
text = text.replace("'tr('Installation Failed: ')$e'", "tr('Installation Failed: ') text = textxt = text.replace("'tr('text = text.replace("'tr('Installation Failed: ')$e'"tr(text = te + '${_formatext = text.rpSiztext = text.replace(extext = text.rece("'Insttext = (widget.aptext = text.replace("'tr('Inse']) text = text.replace("'tr('Installation Fr(text = text.replace("t =text = text.replace("'tr('Installation Failed: ')$e'", "tr('Installatiictext = textagertext = text.replace("'tr('Insh})'"text = text.rep.replace(text = text.rep  text = text.replace("'t  text = text.replace("'tr('Ins  text = t      trtext = text.replace("'tr('nst Ttext = text.repla      text = text.replace("'tr('Installation Failed: ')$e'", "tr('Installati= ttext = text.replace("'tr('Installation Failed: ')$e'", "tr('Installation Failed: ') text = textxt = text.replace("'tr('text = text.                           tr", "Text(\n                            tr")
text = text.replace("const Text(tr", "Text(tr")
text = text.replace("const SnackBar(", "SnackBar(")
text = text.replace("const Text(\n                                          tr", "Text(\n                                          tr")
text = text.replace("const Text(\n                                            tr", "Text(\n                                            tr")

with open('lib/main.dart', 'w', encoding='utf-8') as f:
    f.write(text)
print("SAVED MAIN.DART")

