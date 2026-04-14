import 'dart:convert';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import 'db_service.dart';

double _parseRating(dynamic rating) {
  if (rating == null) return 0.0;
  double r = 0.0;
  if (rating is num) {
    r = rating.toDouble();
  } else {
    r = double.tryParse(rating.toString()) ?? 0.0;
  }
  if (r > 10) return r / 20.0; // out of 100 -> out of 5
  if (r > 5) return r / 2.0;   // out of 10 -> out of 5
  return r;
}

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.system);

void main() {
  runApp(const AppManagerApp());
}

class AppManagerApp extends StatelessWidget {
  const AppManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, ThemeMode currentMode, _) {
        return MaterialApp(
          title: 'VR App Manager',
          themeMode: currentMode,
          theme: ThemeData.light().copyWith(
            scaffoldBackgroundColor: const Color(0xFFF3F4F6),
            cardColor: Colors.white,
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
            ),
            colorScheme: const ColorScheme.light(
              primary: Colors.purple,
              secondary: Colors.pink,
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          darkTheme: ThemeData.dark().copyWith(
            scaffoldBackgroundColor: const Color(0xFF111827),
            cardColor: const Color(0xFF1F2937),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF1F2937),
              foregroundColor: Colors.white,
            ),
            colorScheme: const ColorScheme.dark(
              primary: Colors.purpleAccent,
              secondary: Colors.pinkAccent,
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: const Color(0xFF1F2937),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          home: const MainScreen(),
        );
      },
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

  String _searchQuery = '';
  String _sortOption = 'Name (A-Z)';
  String _categoryFilter = 'All Categories';

  @override
  void initState() {
    super.initState();
    _fetchApps();
  }

  Future<void> _fetchApps() async {
    setState(() => _isLoading = true);
    try {
      final smbApps = await fetchAppsFromDb(
        "smb://100.95.32.89/ssd_internal/downloads/pico4/apps/apps.db",
      );
      setState(() {
        _apps = smbApps;
      });
    } catch (e) {
      debugPrint('Error fetching apps from DB: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  List<String> get _availableCategories {
    final Set<String> categories = {'All Categories'};
    for (var app in _apps) {
      final catString = (app['categories'] ?? '').toString();
      if (catString.isNotEmpty) {
        final splits = catString.split(',');
        for (var c in splits) {
          final trimmed = c.trim();
          if (trimmed.isNotEmpty) {
            categories.add(trimmed);
          }
        }
      }
    }
    final sortedList = categories.toList();
    sortedList.sort((a, b) {
      if (a == 'All Categories') return -1;
      if (b == 'All Categories') return 1;
      return a.compareTo(b);
    });
    return sortedList;
  }

  List<dynamic> get _filteredAndSortedApps {
    List<dynamic> filtered = _apps.where((app) {
      final name = (app['name'] ?? '').toString().toLowerCase();
      final category = (app['categories'] ?? '').toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      final matchesSearch = name.contains(query) || category.contains(query);

      final matchesCategory =
          _categoryFilter == 'All Categories' ||
          category.contains(_categoryFilter.toLowerCase());

      return matchesSearch && matchesCategory;
    }).toList();

    filtered.sort((a, b) {
      if (_sortOption == 'Name (A-Z)') {
        return (a['name'] ?? '').toString().compareTo(
          (b['name'] ?? '').toString(),
        );
      } else if (_sortOption == 'Name (Z-A)') {
        return (b['name'] ?? '').toString().compareTo(
          (a['name'] ?? '').toString(),
        );
      } else if (_sortOption == 'Rating (High to Low)') {
        final scoreA = _parseRating(a['user_rating']);
        final scoreB = _parseRating(b['user_rating']);
        return scoreB.compareTo(scoreA);
      } else if (_sortOption == 'Rating (Low to High)') {
        final scoreA = _parseRating(a['user_rating']);
        final scoreB = _parseRating(b['user_rating']);
        return scoreA.compareTo(scoreB);
      }
      return 0;
    });

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text(
              'Pico 4 App Manager',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
            ),
            const Spacer(),
            Flexible(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 300),
                height: 40,
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search apps...',
                    prefixIcon: Icon(Icons.search, size: 20),
                    contentPadding: EdgeInsets.symmetric(
                      vertical: 0,
                      horizontal: 16,
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(width: 16),
            Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color:
                    Theme.of(context).inputDecorationTheme.fillColor ??
                    Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _categoryFilter,
                  icon: const Icon(Icons.category, size: 20),
                  items: _availableCategories.map((String category) {
                    return DropdownMenuItem<String>(
                      value: category,
                      child: Text(category),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _categoryFilter = value;
                      });
                    }
                  },
                ),
              ),
            ),
            const SizedBox(width: 16),
            Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color:
                    Theme.of(context).inputDecorationTheme.fillColor ??
                    Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _sortOption,
                  icon: const Icon(Icons.sort, size: 20),
                  items: const [
                    DropdownMenuItem(
                      value: 'Name (A-Z)',
                      child: Text('Name (A-Z)'),
                    ),
                    DropdownMenuItem(
                      value: 'Name (Z-A)',
                      child: Text('Name (Z-A)'),
                    ),
                    DropdownMenuItem(
                      value: 'Rating (High to Low)',
                      child: Text('Rating (High to Low)'),
                    ),
                    DropdownMenuItem(
                      value: 'Rating (Low to High)',
                      child: Text('Rating (Low to High)'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _sortOption = value;
                      });
                    }
                  },
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: () {
              themeNotifier.value = isDarkMode
                  ? ThemeMode.light
                  : ThemeMode.dark;
            },
            tooltip: 'Toggle Theme',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchApps,
            tooltip: 'Refresh Apps',
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                int crossAxisCount = constraints.maxWidth > 1200
                    ? 5
                    : constraints.maxWidth > 800
                    ? 4
                    : 2;
                final displayedApps = _filteredAndSortedApps;

                return GridView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 24,
                  ),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    childAspectRatio: 0.75, // Taller covers
                    crossAxisSpacing: 24,
                    mainAxisSpacing: 24,
                  ),
                  itemCount: displayedApps.length,
                  itemBuilder: (context, index) {
                    final app = displayedApps[index];
                    return _AppCard(app: app, apiUrl: _apiUrl);
                  },
                );
              },
            ),
    );
  }
}

class _StarRating extends StatelessWidget {
  final double score;
  final double iconSize;

  const _StarRating({required this.score, this.iconSize = 24.0});

  @override
  Widget build(BuildContext context) {
    final starCount = score;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        IconData icon;
        if (starCount >= index + 0.75) {
          icon = Icons.star;
        } else if (starCount >= index + 0.25) {
          icon = Icons.star_half;
        } else {
          icon = Icons.star_border;
        }
        return Icon(icon, color: Colors.yellow, size: iconSize);
      }),
    );
  }
}

class _AppCard extends StatefulWidget {
  final dynamic app;
  final String apiUrl;

  const _AppCard({required this.app, required this.apiUrl});

  @override
  State<_AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<_AppCard> {
  bool _isHovered = false;
  int _currentImageIndex = 0;

  List<String> get _allImages {
    final images = <String>[];
    if (widget.app['thumbnail_url'] != null && widget.app['thumbnail_url'].toString().isNotEmpty) {
      images.add(widget.app['thumbnail_url']);
    }
    if (widget.app['screenshots'] != null) {
      try {
        final decoded = jsonDecode(widget.app['screenshots']);
        if (decoded is List) {
          images.addAll(decoded.map((e) => e.toString()).where((e) => e.isNotEmpty));
        }
      } catch (_) {}
    }
    return images;
  }

  void _showInstallBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Install ${widget.app['name'] ?? 'App'}?',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'Do you want to send this app to your headset for installation?',
                style: TextStyle(fontSize: 18),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    ),
                    child: const Text('Cancel', style: TextStyle(fontSize: 18)),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      Navigator.of(context).pop(); // Close the bottom sheet first
                      
                      try {
                        final response = await http.post(
                          Uri.parse('${widget.apiUrl}/install'),
                          headers: {
                            'Content-Type': 'application/json',
                          },
                          body: json.encode({'app_id': widget.app['id']}),
                        );

                        if (response.statusCode == 200) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Deployment instruction sent to PC via ADB! Check headset for USB Debugging prompt.',
                                style: TextStyle(fontSize: 16),
                              ),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } else {
                          throw Exception(
                            'Server responded with ${response.statusCode}',
                          );
                        }
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Installation Trigger Error: $e',
                              style: const TextStyle(fontSize: 16),
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    ),
                    child: const Text(
                      'Install',
                      style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDetails(BuildContext context) {
    List<String> screenshots = [];
    if (widget.app['screenshots'] != null) {
      try {
        final decoded = jsonDecode(widget.app['screenshots']);
        if (decoded is List) {
          screenshots = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {}
    }

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Theme.of(context).cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
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
                    if (_allImages.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(
                          _allImages.first,
                          width: 400,
                          height: 250,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            width: 400,
                            height: 250,
                            color: Colors.grey[800],
                            child: const Center(
                              child: Icon(Icons.vrpano, size: 80, color: Colors.white54),
                            ),
                          ),
                        ),
                      )
                    else
                      Container(
                        width: 400,
                        height: 250,
                        decoration: BoxDecoration(
                          color: Colors.grey[800],
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Center(
                          child: Icon(Icons.vrpano, size: 80, color: Colors.white54),
                        ),
                      ),
                    const SizedBox(width: 32),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.app['name'] ?? 'Unknown App',
                            style: const TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              widget.app['categories'] ?? 'Category',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              _StarRating(
                                score: _parseRating(widget.app['user_rating']),
                                iconSize: 32,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "${_parseRating(widget.app['user_rating']).toStringAsFixed(1).replaceAll('.0', '')}/5",
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.color
                                      ?.withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close,
                        size: 40,
                        color: Colors.grey,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (screenshots.isNotEmpty) ...[
                          Text(
                            'Screenshots',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(
                                context,
                              ).textTheme.bodyLarge?.color,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 200,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: screenshots.length,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(width: 16),
                              itemBuilder: (context, index) {
                                return GestureDetector(
                                  onTap: () {
                                    showDialog(
                                      context: context,
                                      builder: (context) =>
                                          _FullscreenImageViewer(
                                            imageUrls: screenshots,
                                            initialIndex: index,
                                          ),
                                    );
                                  },
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(
                                      screenshots[index],
                                      height: 200,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => Container(
                                        height: 200,
                                        width: 300,
                                        color: Colors.grey[800],
                                        child: const Center(
                                          child: Icon(
                                            Icons.vrpano,
                                            size: 40,
                                            color: Colors.white54,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                        Html(
                          data:
                              widget.app['long_description'] ??
                              'No description available.',
                          style: {
                            "body": Style(
                              fontSize: FontSize(22.0),
                              color: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.color
                                  ?.withValues(alpha: 0.8),
                              lineHeight: LineHeight(1.6),
                              margin: Margins.zero,
                              padding: HtmlPaddings.zero,
                            ),
                          },
                        ),
                        const SizedBox(height: 32),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green.shade600,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 24,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.download,
                                  size: 32,
                                  color: Colors.white,
                                ),
                                label: const Text(
                                  'Install to Headset',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                onPressed: () async {
                                  final messenger = ScaffoldMessenger.of(context);
                                  try {
                                    final response = await http.post(
                                      Uri.parse('${widget.apiUrl}/install'),
                                      headers: {
                                        'Content-Type': 'application/json',
                                      },
                                      body: json.encode({'app_id': widget.app['id']}),
                                    ).timeout(const Duration(seconds: 10));

                                    if (!context.mounted) return;

                                    if (response.statusCode == 200) {
                                      Navigator.of(context).pop();
                                      messenger.showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Deployment instruction sent to PC via ADB! Check headset for USB Debugging prompt.',
                                            style: TextStyle(fontSize: 18),
                                          ),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    } else {
                                      throw Exception(
                                        'Server responded with ${response.statusCode}',
                                      );
                                    }
                                  } catch (e) {
                                    if (!context.mounted) return;
                                    Navigator.of(context).pop();
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Installation Trigger Error: $e',
                                          style: const TextStyle(fontSize: 18),
                                        ),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                },
                              ),
                            ),
                            if (widget.app['trailer_url'] != null) ...[
                              const SizedBox(width: 24),
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.purple.shade600,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 24,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.play_circle_fill,
                                    size: 32,
                                    color: Colors.white,
                                  ),
                                  label: const Text(
                                    'Watch Trailer',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  onPressed: () async {
                                    String urlString = widget.app['trailer_url'];
                                    if (!urlString.startsWith('http://') &&
                                        !urlString.startsWith('https://')) {
                                      urlString = 'https://$urlString';
                                    }
                                    
                                    final videoId = YoutubePlayerController.convertUrlToId(urlString);
                                    
                                    if (videoId != null && context.mounted) {
                                      showDialog(
                                        context: context,
                                        builder: (context) => _TrailerDialog(videoId: videoId),
                                      );
                                    } else {
                                      final url = Uri.parse(urlString);
                                      try {
                                        await launchUrl(
                                          url,
                                          mode: LaunchMode.inAppWebView,
                                        );
                                      } catch (e) {
                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Could not launch trailer',
                                            ),
                                          ),
                                        );
                                      }
                                    }
                                  },
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final images = _allImages;
    final hasMultipleImages = images.length > 1;

    return Card(
      elevation: 6,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: InkWell(
          onTap: () => _showDetails(context),
          onLongPress: () => _showInstallBottomSheet(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 5,
                child: images.isNotEmpty
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.network(
                            images[_currentImageIndex],
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              color: Colors.grey[800],
                              child: const Center(
                                child: Icon(Icons.vrpano, size: 64, color: Colors.white54),
                              ),
                            ),
                          ),
                          if (_isHovered && hasMultipleImages)
                            Positioned.fill(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.chevron_left, color: Colors.white, size: 32),
                                    onPressed: () {
                                      setState(() {
                                        _currentImageIndex = (_currentImageIndex - 1) % images.length;
                                        if (_currentImageIndex < 0) {
                                          _currentImageIndex += images.length;
                                        }
                                      });
                                    },
                                    style: IconButton.styleFrom(
                                      backgroundColor: Colors.black45,
                                      shape: const CircleBorder(),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.chevron_right, color: Colors.white, size: 32),
                                    onPressed: () {
                                      setState(() {
                                        _currentImageIndex = (_currentImageIndex + 1) % images.length;
                                      });
                                    },
                                    style: IconButton.styleFrom(
                                      backgroundColor: Colors.black45,
                                      shape: const CircleBorder(),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (_isHovered && hasMultipleImages)
                            Positioned(
                              bottom: 8,
                              left: 0,
                              right: 0,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(images.length, (index) {
                                  return Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 2),
                                    width: _currentImageIndex == index ? 8 : 6,
                                    height: _currentImageIndex == index ? 8 : 6,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _currentImageIndex == index ? Colors.white : Colors.white54,
                                    ),
                                  );
                                }),
                              ),
                            ),
                        ],
                      )
                    : Container(
                        color: Colors.grey[800],
                        child: const Center(
                          child: Icon(Icons.vrpano, size: 64, color: Colors.white54),
                        ),
                      ),
              ),
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: AutoSizeText(
                          widget.app['name'] ?? 'Unknown App',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                          minFontSize: 12,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: AutoSizeText(
                                widget.app['categories'] ?? '',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                                minFontSize: 10,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _StarRating(
                            score: _parseRating(widget.app['user_rating']),
                            iconSize: 18,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FullscreenImageViewer extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;

  const _FullscreenImageViewer({
    super.key,
    required this.imageUrls,
    this.initialIndex = 0,
  });

  @override
  State<_FullscreenImageViewer> createState() => _FullscreenImageViewerState();
}

class _FullscreenImageViewerState extends State<_FullscreenImageViewer> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentIndex < widget.imageUrls.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    if (_currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.imageUrls.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemBuilder: (context, index) {
              return InteractiveViewer(
                minScale: 0.1,
                maxScale: 4.0,
                child: Image.network(
                  widget.imageUrls[index],
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const Center(
                    child: Icon(
                      Icons.broken_image,
                      size: 100,
                      color: Colors.grey,
                    ),
                  ),
                ),
              );
            },
          ),
          Positioned(
            top: 10,
            right: 10,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 40),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          if (_currentIndex > 0)
            Positioned(
              left: 10,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios,
                    color: Colors.white,
                    size: 60,
                  ),
                  onPressed: _previousPage,
                ),
              ),
            ),
          if (_currentIndex < widget.imageUrls.length - 1)
            Positioned(
              right: 10,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton(
                  icon: const Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.white,
                    size: 60,
                  ),
                  onPressed: _nextPage,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TrailerDialog extends StatefulWidget {
  final String videoId;
  const _TrailerDialog({required this.videoId});

  @override
  State<_TrailerDialog> createState() => _TrailerDialogState();
}

class _TrailerDialogState extends State<_TrailerDialog> {
  late final YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController.fromVideoId(
      videoId: widget.videoId,
      autoPlay: true,
      params: const YoutubePlayerParams(
        showFullscreenButton: true,
      ),
    );
  }

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: Stack(
          alignment: Alignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: YoutubePlayer(
                controller: _controller,
              ),
            ),
            Positioned(
              top: -10,
              right: -10,
              child: IconButton(
                icon: const Icon(Icons.cancel, color: Colors.white, size: 36),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
