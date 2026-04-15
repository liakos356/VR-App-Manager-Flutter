import re
with open("lib/main.dart", "r") as f:
    text = f.read()

# Fix constant evaluation method invocations
lines_to_fix = [76, 79, 89, 91, 94, 96, 97, 104, 105, 107, 488, 617, 906, 925, 1223, 1479, 1831]

lines = text.split('\n')
for line_num in lines_to_fix:
    idx = line_num - 1
    if 0 <= idx < len(lines):
        # We know these lines have an error because tr() is called inside a const context.
        # usually it is a parent `const` that is causing the issue.
        # But wait, python script is easier... let's just use regex to remove 'const ' if followed by Text(tr, or similar
        pass

# actually regex is better
text = re.sub(r'const\s+(Text\(tr\()', r'\1', text)
text = re.sub(r'const\s+(EdgeInsetsGeometry)', r'\1', text)
text = re.sub(r'const\s+\[([^\]]+tr\([^\]]+)\]', r'[\1]', text)
text = re.sub(r'const\s+(SnackBar\(content:\s*Text\(tr\()', r'\1', text)

with open("lib/main.dart", "w") as f:
    f.write(text)

