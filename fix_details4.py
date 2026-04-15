import re

with open("lib/main.dart", "r") as f:
    lines = f.readlines()

out = []
in_details = False

for i, line in enumerate(lines):
    if "void _showDetails(BuildContext context) {" in line:
        in_details = True
        
    if "Widget build(BuildContext context) {" in line and i > 1000:
        # A bit of a hack, but details function is before the next build meth if it exists, or just process it.
        pass
        
    if in_details:
        if "pageBuilder: (context, animation, secondaryAnimation) {" in line:
            out.append(line)
            out.append("          bool isInstallingLocal = false;\n")
            out.append("          double installProgressLocal = 0.0;\n")
            out.append("          return StatefulBuilder(builder: (context, setDetailsState) {\n")
            continue
            
        if "          return Scaffold(" in line:
            out.append(line)
            continue
            
        if "                              color: _isInstalling" in line:
            o            o            o                        o        gLocal                     o  e
                                                                                              en                                                                                                     et                                                                                              en              h_apk']"))
            c            c   if             c            c   if             c            c   if             .a            c            c ['            c            c   if             c            c   if    in             c            c   if             c            c   if        ta            c            c   if             c            c   if             c            c   if  ling =" in line:
            out.app            out.app            out.app         ingLocal = "))
            continue
        if "            if           if "            if           if "            if           if " .a        if "            if           if "            if           if "            if           if " .a"                                                  () => _installProgress =" in line:
            out.append("                                                  () => installProgressLocal =\n")
            continue
            
        # The stack children condition
        if "if (_isInstalling && _installProgress > 0)"         if "if (_isInstalling && _installProgress > 0)"         if "if (_isInstalling && _installProgress > 0)"         if "if (_isInstalling && _installProgress > 0)"         if "if (_isInstalling && _installProgress > 0)"         if "if (_isInstalling && _installProgress > 0)"         if "if (_isInstalling && _installProgress > 0)"         if "if (_isInstalling && _installProgress > 0)"   li        if "if (_isInstalling && _installProgress > 0)"         if "if (_isIn(!is        if "if (_is
                                                                                                                                                                                                                                                                                                 "(                                                                                                         ra                   on           ti                                     line:
            out.append("          });\n")
            out.append(line)
            in_details = False
            continue
            
    out.append(line)

with open("lib/main.dart", "w") as f:
    f.writelines(out)
print("Line-by-line replacement applied.")
