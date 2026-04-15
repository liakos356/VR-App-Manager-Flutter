import re

with open('lib/main.dart', 'r', encoding='utf-8') as f:
    text = f.read()

# Exact literal string replacements matching flutter Text construction styles:
replacements = [
    (r"Text\(\s*'Screenshots'\s*\)", r"Text(tr('Screenshots'))"),
    (r"Text\(\s*'Ovrport Only'\s*\)", r"Text(tr('Ovrport Only'))"),
    (r"Text\(\s*'Cancel'\s*\)", r"Text(tr('Cancel'))"),
    (r"Text\(\s*'Could not launch trailer'\s*\)", r"Text(tr('Could not launch trailer'))"),
    (r"Text\(\s*'Invalid Object: App ID is empty'\s*\)", r"Text(tr('Invalid Object: App ID is empty'))"),
    (r"Text\(\s*'Watch Trailer'\s*\)", r"Text(tr('Watch Trailer'))"),
    (r"Text\(\s*'Do you want to send this app to your headset for installation\?'\s*\)", r"Text(tr('Do you want to send this app to your headset for installation?'))"),
    (r"Text\(\s*'Done'\s*\)", r"Text(tr('Done'))"),
    (r"Text\(\s*'Installation Completed!'\s*\)", r"Text(tr('Installation Completed!'))"),
    (r"Text\(\s*'Clear history'\s*\)", r    (r"Text\(\s*'Clear histor
    (r"Text\(\s*'Ovrport'\s*\)", r"Text(tr('Ovrport'))"),
]
for old_for old_for old_foplafor old_for old_for old_foplafor old_for old_for old_foplafor old_for old_forerpolated literal rfor old_for old_for old_foplafor old_for old_for old_foplafor olisfor old_for old_for old_foplafor old_for old_for old_foplafor old} (${displayedApps.length})')", text)
text = re.sub(r"Text\text = re.sub(r"Text\text = re.sub(r"Text\text = re.sub(r"Text\text = re.sub(r"Text\texsub(rtext = re.sub(r"Text\text = re.sub(r"Text\text = re.sub(r"Text\text = re.sub(r"Text\text = re.sub(r"Text.stext = re.sub(r"Text\text = re.sub(r"Text\text = re.sub(r"Text\tex\)\\text = re.sub(r"Text\text = re.sub(r"Text\text = re.sub(r"Text\text = re.sub(r"Text\text = re.sub(r"Text\texsub(rtext = re.sub(r"Text\text = re.sub(r"Text\text = re.setttext = re.sub(r"Text\text = re.sub(r"Text\text = rde the Text widget where it occurs
text = re.sub(r"'Install \$\{\(\(widget\.app\['name'\] \?text = re.sub(r"'Install \$\{\(\(widget\.app\['name'\] \?text = re.s\}text = re.sub(r"'Install \$\{\(\(widget\.app\['name'\] \ith open('lib/main.dart', 'w', encoding='utf-8') as f:
    f.write(text)

