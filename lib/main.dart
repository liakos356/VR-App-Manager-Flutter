import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const AppManagerApp());
}

class AppManagerApp extends StatelessWidget {
  const AppManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VR App Manager',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF111827),
        cardColor: const Color(0xFF1F2937),
        colorScheme: const ColorScheme.dark(
          primary: Colors.purpleAccent,
          secondary: Colors.pinkAccent,
        ),
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  // Point this to your PC's Python FastAPI local network IP address
  final String _apiUrl = 'http://192.168.1.17:8001/api';

  List<dynamic> _apps = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchApps();
  }

  Future<void> _fetchApps() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(Uri.parse('$_apiUrl/apps'));
      if (response.statusCode == 200) {
        setState(() {
          _apps = json.decode(response.body);
        });
      }
    } catch (e) {
      debugPrint('Error fetching apps: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('VR App Manager', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1F2937),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchApps,
            tooltip: 'Refresh Apps',
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                int crossAxisCount = constraints.maxWidth > 1200 ? 5 : constraints.maxWidth > 800 ? 4 : 2;
                
                return GridView.builder(
                  padding: const EdgeInsets.all(24),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    childAspectRatio: 0.75, // Taller covers
                    crossAxisSpacing: 24,
                    mainAxisSpacing: 24,
                  ),
                  itemCount: _apps.length,
                  itemBuilder: (context, index) {
                    final app = _apps[index];
                    return _AppCard(app: app, apiUrl: _apiUrl);
                  },
                );
              },
            ),
    );
  }
}

class _AppCard extends StatelessWidget {
  final dynamic app;
  final String apiUrl;

  const _AppCard({required this.app, required this.apiUrl});

  void _showDetails(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: const Color(0xFF1F2937),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Container(
            width: 1000,
            height: 700,
            padding: const EdgeInsets.all(40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (app['preview_photo'] != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(
                          app['preview_photo'],
                          width: 400,
                          height: 250,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            width: 400, height: 250, color: Colors.grey[800],
                            child: const Center(child: Icon(Icons.broken_image, size: 50)),
                          ),
                        ),
                      )
                    else
                      Container(width: 400, height: 250, decoration: BoxDecoration(color: Colors.grey[800], borderRadius: BorderRadius.circular(16))),
                    const SizedBox(width: 32),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            app['title'] ?? 'Unknown App',
                            style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.purpleAccent.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              app['category'] ?? 'Category',
                              style: const TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold, fontSize: 18),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              const Icon(Icons.star, color: Colors.yellow, size: 32),
                              const SizedBox(width: 8),
                              Text("${app['metacritic_rating'] ?? 0}/100", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white70)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 40, color: Colors.white54),
                      onPressed: () => Navigator.of(context).pop(),
                    )
                  ],
                ),
                const SizedBox(height: 32),
                Expanded(
                  child: SingleChildScrollView(
                    child: Text(
                      app['description'] ?? 'No description available.',
                      style: const TextStyle(fontSize: 22, color: Colors.white70, height: 1.6),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        icon: const Icon(Icons.download, size: 32, color: Colors.white),
                        label: const Text('Install to Headset', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                        onPressed: () async {
                          // Approach A logic - Push installation via PC ADB network bridge
                          try {
                             final response = await http.post(
                                Uri.parse('$apiUrl/install'),
                                headers: {'Content-Type': 'application/json'},
                                body: json.encode({'app_id': app['id']}),
                             );
                             
                             if (response.statusCode == 200) {
                                if (!context.mounted) return; ScaffoldMessenger.of(context).showSnackBar(
                                   const SnackBar(content: Text('Deployment instruction sent to PC via ADB! Check headset for USB Debugging prompt.', style: TextStyle(fontSize: 18)), backgroundColor: Colors.green),
                                );
                             } else {
                                throw Exception('Server responded with ${response.statusCode}');
                             }
                          } catch (e) {
                             if (!context.mounted) return; ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Installation Trigger Error: $e', style: const TextStyle(fontSize: 18)), backgroundColor: Colors.red),
                             );
                          }
                        },
                      ),
                    ),
                    if (app['trailer_url'] != null) ...[
                      const SizedBox(width: 24),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purple.shade600,
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          icon: const Icon(Icons.play_circle_fill, size: 32, color: Colors.white),
                          label: const Text('Watch Trailer', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                          onPressed: () async {
                            final url = Uri.parse(app['trailer_url']);
                            if (await canLaunchUrl(url)) {
                              await launchUrl(url, mode: LaunchMode.externalApplication);
                            }
                          },
                        ),
                      )
                    ]
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 6,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => _showDetails(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 5,
              child: app['preview_photo'] != null
                  ? Image.network(
                      app['preview_photo'],
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(color: Colors.grey[800]),
                    )
                  : Container(color: Colors.grey[800]),
            ),
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      app['title'] ?? 'Unknown App',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.purpleAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        app['category'] ?? '',
                        style: const TextStyle(color: Colors.purpleAccent, fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
