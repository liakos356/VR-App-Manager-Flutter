import re

with open('lib/screens/main_screen.dart', 'r') as f:
    content = f.read()

# I want to inject the hasApk check just before return ListTile( in _buildMasterList
injection = """
          final bool hasApk = (app['apk_path']?.toString() ?? '').trim().isNotEmpty;

          return Opacity(
            opacity: hasApk ? 1.0 : 0.5,
            child: ListTile(
"""

content = content.replace("          return ListTile(", injection)

# I should add the trailing chip. I will look for subtitle and inject trailing after it.
trailing_injection = """
            subtitle: Text(
              desc,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13),
            ),
            trailing: hasApk ? null : Chip(
              label: Text('Unavailable', style: TextStyle(fontSize: 10)),
              padding: EdgeInsets.zero,
            ),
"""

content = content.replace("""            subtitle: Text(
                                              
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 1              style: TextStyle(fontSize: 1              style: TextStyle(fontSize: ',          :
    f.write(content)
