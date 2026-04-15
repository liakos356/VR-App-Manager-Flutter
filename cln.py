import re

with open('lib/main.dart', 'r') as file:
    content = file.read()

# Fix dict keys
content = content.replace("tr('Ovrport')", "'Ovrport'")
content = content.replace("tr('Delete')", "'Delete'")
content = content.replace("const Map<String, String> translations = {", "final Map<String, String> translations = {")
content = re.sub(r"tr\('([^']+)'\)\s*:", r"'\1':", content)

# Brute force remove ALL 'const' modifiers just for testing compilation, then format.
content = re.sub(r'\bconst\b\s+', '', content)

with open('lib/main.dart', 'w') as file:
    file.write(content)

