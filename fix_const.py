import re

with open('lib/main.dart', 'r') as file:
    content = file.read()

# Try to find specific const issues and remove just the const
content = re.sub(r'const\s+(Text\(tr\([^)]+\)\))', r'\1', content)
content = re.sub(r'const\s+(EdgeInsetsGeometry)', r'\1', content)
content = re.sub(r'const\s+(\[.*?tr\(.*?\])', r'\1', content, flags=re.DOTALL)


with open('lib/main.dart', 'w') as file:
    file.write(content)

