with open("lib/widgets/app_card.dart", "r") as f:
    text = f.read()

import re

# Insert variable
text = text.replace("        double installProgressLocal = 0.0;", "        double installProgressLocal = 0.0;\n        String installStatusLocal = 'Starting...';")

# Find and replace the onTap body's first block
old_block1 = """                                        setModalState(() {
                                          isInstallingLocal = true;
                                          installProgressLocal = 0.0;
                                        });"""
new_block1 = """                                        setModalState(() {
                                          isInstallingLocal = true;
                                          installProgressLocal = 0.0;
                                          installStatusLocal = 'Starting...';
                                        });"""
text = text.replace(old_block1, new_block1)

# Find and replace empty onProgress:
old_block2 = """               old_block2 = """               old_block2 = """ ssold_block2 = """     old_       old_block2 = """  old_block2 = """               old_block2 = """               old_block2 = """ ssold_block2 = """     old_       old_block2 = """  old_block2 = """               ss:old_block2 = """               old_block2 = "   old_block2 = """               old_block2 = """               old_block2   old_block2 = """               old_block2 = """               o     old_block2 = """               old_block2 = """               old_blexold_block2 = """               old_block2 = "ixold_block2 = """               old_block2 = """               old_block2 stold_block2 = """               old_block2 = """            alling ($old_block2 = """               old_block2 = """               old                 : 'Install',"""
new_block3 = """                                    isInstallingLocal
                                        ? installProgressLocal > 0.0 &&                                                                        ? '${(installProgressLocal * 100).toInt()}%'
                                            : installStatusLocal
                                        : 'Install',"""
text = text.replace(old_block3, new_block3)

with open("lib/widgets/app_card.dart", "w") as f:
    f.write(text)

print("done")
