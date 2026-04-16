// ignore_for_file: avoid_print
import 'dart:io';

void main() {
  final file = File('lib/install_service_io.dart');
  var text = file.readAsStringSync();
  
  if (!text.contains("if (relativeApkPath.startsWith('ssd_internal/'))")) {
    text = text.replaceAll(
      "      } else if (relativeApkPath.startsWith('/')) {\n"
      "        relativeApkPath = relativeApkPath.substring(1);\n"
      "      }",
      "      } else if (relativeApkPath.startsWith('/')) {\n"
      "        relativeApkPath = relativeApkPath.substring(1);\n"
      "      }\n"
      "      if (relativeApkPath.startsWith('ssd_internal/')) {\n"
      "        relativeApkPath = relativeApkPath.substring('ssd_internal/'.length);\n"
      "      }"
    );
  }
  
  file.writeAsStringSync(text);
  print('Done fixing path filter.');
}
