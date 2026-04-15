import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../install_service.dart';
import '../utils/formatters.dart';
import '../utils/localization.dart';
import 'fullscreen_image_viewer.dart';
import 'star_rating.dart';
import 'trailer_dialog.dart';

class AppCard extends StatefulWidget {
  final dynamic app;
  final String apiUrl;

  const AppCard({super.key, required this.app, required this.apiUrl});

  @override
  State<AppCard> createState() => AppCardState();
}

class AppCardState extends State<AppCard> {
  bool _isHovered = false;
  int _currentImageIndex = 0;

  bool _isInstalling = false;
  double _installProgress = 0.0;

  List<String> get _allImages {
    final images = <String>[];
    if (((widget.app['thumbnail_url'] ?? widget.app['preview_photo']) ??
                widget.app['preview_photo']) !=
            null &&
        ((widget.app['thumbnail_url'] ?? widget.app['preview_photo']) ??
                widget.app['preview_photo'])
            .toString()
            .isNotEmpty) {
      images.add(
        ((widget.app['thumbnail_url'] ?? widget.app['preview_photo']) ??
            widget.app['preview_photo']),
      );
    }
    if (widget.app['screenshots'] != null) {
      try {
        final decoded = jsonDecode(widget.app['screenshots']);
        if (decoded is List) {
          images.addAll(
            decoded.map((e) => e.toString()).where((e) => e.isNotEmpty),
          );
        }
      } catch (_) {}
    }
    return images;
  }

  void _showInstallBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        bool isInstallingLocal = false;
        double installProgressLocal = 0.0;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Install ${((widget.app['name'] ?? widget.app['title']) ?? widget.app['title']) ?? 'App'}?',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 16),
                  Text(
                    tr(
                      'Do you want to send this app to your headset for installation?',
                    ),
                    style: TextStyle(fontSize: 18),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      OutlinedButton(
                        onPressed: isInstallingLocal
                            ? null
                            : () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                        ),
                        child: Text(
                          tr('Cancel'),
                          style: TextStyle(fontSize: 18),
                        ),
                      ),
                      Container(
                        height: 55,
                        width: 200,
                        clipBehavior: Clip.hardEdge,
                        decoration: BoxDecoration(
                          color: isInstallingLocal
                              ? Colors.grey.shade800
                              : Colors.green.shade600,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Stack(
                          children: [
                            if (isInstallingLocal)
                              FractionallySizedBox(
                                widthFactor: installProgressLocal,
                                child: Container(color: Colors.green.shade600),
                              ),
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: isInstallingLocal
                                    ? null
                                    : () async {
                                        final String appId =
                                            widget.app['id']?.toString() ?? '';
                                        if (appId.isEmpty) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                tr(
                                                  'Invalid Object: App ID is empty',
                                                ),
                                              ),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                          return;
                                        }

                                        setModalState(() {
                                          isInstallingLocal = true;
                                          installProgressLocal = 0.0;
                                        });

                                        try {
                                          await InstallService.installAppLocally(
                                            appId: appId,
                                            apkPath:
                                                widget.app['file_path_apk']
                                                    ?.toString() ??
                                                '',
                                            obbDir:
                                                widget.app['file_path_obb']
                                                    ?.toString() ??
                                                '',
                                            onProgress: (progress) {
                                              // Not displaying string messages right now
                                            },
                                            onDownloadProgress: (progress) {
                                              if (progress >= 0.0 &&
                                                  progress <= 1.0) {
                                                setModalState(() {
                                                  installProgressLocal =
                                                      progress;
                                                });
                                              }
                                            },
                                          );
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Installation Completed!',
                                                ),
                                                backgroundColor: Colors.green,
                                              ),
                                            );
                                          }
                                        } catch (e) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Installation Failed: $e',
                                                ),
                                                backgroundColor: Colors.red,
                                              ),
                                            );
                                          }
                                        } finally {
                                          if (context.mounted) {
                                            Navigator.of(context).pop();
                                          }
                                        }
                                      },
                                child: Center(
                                  child: Text(
                                    isInstallingLocal
                                        ? 'Installing (${(installProgressLocal * 100).toInt()}%)'
                                        : 'Install',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
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

    List<String> tags = [];
    if (widget.app['tags'] != null) {
      final tagsStr = widget.app['tags'].toString();
      if (tagsStr.trim().isNotEmpty) {
        try {
          final List<dynamic> parsed = jsonDecode(tagsStr);
          tags = parsed
              .map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty)
              .toList();
        } catch (_) {
          tags = tagsStr
              .replaceAll(RegExp(r'[\[\]"]'), '')
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();
        }
      }
    }

    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) {
          return Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: Text(
                ((widget.app['name'] ?? widget.app['title']) ??
                        widget.app['title']) ??
                    'Unknown App',
              ),
            ),
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            body: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 4,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_allImages.isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.network(
                              _allImages.first,
                              width: double.infinity,
                              height: 350,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: double.infinity,
                                height: 350,
                                color: Colors.grey[800],
                                child: const Center(
                                  child: Icon(
                                    Icons.vrpano,
                                    size: 80,
                                    color: Colors.white54,
                                  ),
                                ),
                              ),
                            ),
                          )
                        else
                          Container(
                            width: double.infinity,
                            height: 350,
                            decoration: BoxDecoration(
                              color: Colors.grey[800],
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.vrpano,
                                size: 80,
                                color: Colors.white54,
                              ),
                            ),
                          ),
                        if (screenshots.isNotEmpty) ...[
                          const SizedBox(height: 32),
                          Text(
                            tr('Screenshots'),
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(
                                context,
                              ).textTheme.bodyLarge?.color,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 16,
                            runSpacing: 16,
                            children: screenshots.map((url) {
                              int index = screenshots.indexOf(url);
                              return GestureDetector(
                                onTap: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => FullscreenImageViewer(
                                      imageUrls: screenshots,
                                      initialIndex: index,
                                    ),
                                  );
                                },
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    url,
                                    width: 200,
                                    height: 150,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      width: 200,
                                      height: 150,
                                      color: Colors.grey[800],
                                      child: const Center(
                                        child: Icon(
                                          Icons.broken_image,
                                          color: Colors.white54,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                Expanded(
                  flex: 6,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ((widget.app['name'] ?? widget.app['title']) ??
                                  widget.app['title']) ??
                              'Unknown App',
                          style: const TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (getAppSize(widget.app) > 0)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 20.0),
                            child: Text(
                              "Size: \${formatBytes(getAppSize(widget.app))}\${getObbSize(widget.app) > 0 ? '\\n(APK: \${formatBytes(getApkSize(widget.app))} + OBB: \${formatBytes(getObbSize(widget.app))})' : ''}",
                              style: TextStyle(
                                fontSize: 18,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.color
                                    ?.withValues(alpha: 0.7),
                              ),
                            ),
                          )
                        else
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
                            ((widget.app['categories'] ??
                                        widget.app['category']) ??
                                    widget.app['category']) ??
                                'Category',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),

                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            if (widget.app['ovrport'] == 1 ||
                                widget.app['ovrport'] == true ||
                                widget.app['ovrport'] == '1' ||
                                widget.app['ovrport'] == 'true') ...[
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: 12.0,
                                  right: 12.0,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.orange.withValues(
                                        alpha: 0.5,
                                      ),
                                    ),
                                  ),
                                  child: const Text(
                                    'Ovrport',
                                    style: TextStyle(
                                      color: Colors.orange,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(width: 8),
                            Padding(
                              padding: const EdgeInsets.only(top: 12.0),
                              child: Row(
                                children: [
                                  StarRating(
                                    rating: parseRating(
                                      ((widget.app['user_rating'] ??
                                              widget.app['rating']) ??
                                          widget.app['rating']),
                                    ),
                                    size: 32,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "\${parseRating(((widget.app['user_rating'] ?? widget.app['rating']) ?? widget.app['rating'])).toStringAsFixed(1).replaceAll('.0', '')}/5",
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
                            ),
                          ],
                        ),

                        if (tags.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: tags.map((tag) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.secondary
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .secondary
                                        .withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Text(
                                  tag,
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.secondary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],

                        const SizedBox(height: 32),
                        Row(
                          children: [
                            ElevatedButton.icon(
                              onPressed: _isInstalling ? null : () async {
                                        final String appId =
                                            widget.app['id']?.toString() ?? '';
                                        if (appId.isEmpty) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                tr(
                                                  'Invalid Object: App ID is empty',
                                                ),
                                              ),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                          return;
                                        }

                                        setState(() {
                                          _isInstalling = true;
                                          _installProgress = 0.0;
                                        });

                                        try {
                                          await InstallService.installAppLocally(
                                            appId: appId,
                                            apkPath:
                                                widget.app['file_path_apk']
                                                    ?.toString() ??
                                                '',
                                            obbDir:
                                                widget.app['file_path_obb']
                                                    ?.toString() ??
                                                '',
                                            onProgress: (progress) {},
                                            onDownloadProgress: (progress) {
                                              if (progress >= 0.0 &&
                                                  progress <= 1.0) {
                                                setState(() {
                                                  _installProgress = progress;
                                                });
                                              }
                                            },
                                          );

                                          setState(() {
                                            _isInstalling = false;
                                            _installProgress = 1.0;
                                          });

                                          if (mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(tr('Installation Completed!')),
                                                backgroundColor: Colors.green,
                                              ),
                                            );
                                          }
                                        } catch (e) {
                                          setState(() {
                                            _isInstalling = false;
                                          });
                                          if (mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text('Error: $e'),
                                                backgroundColor: Colors.red,
                                              ),
                                            );
                                          }
                                        }
                                      },
                              icon: _isInstalling 
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                                    )
                                  : const Icon(Icons.download, size: 28),
                              label: Text(
                                _isInstalling ? '${(_installProgress * 100).toInt()}%' : tr('Install'),
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 48,
                                  vertical: 24,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                            if (widget.app['video_url'] != null &&
                                    widget.app['video_url'].isNotEmpty ||
                                widget.app['trailer_url'] != null &&
                                    widget.app['trailer_url'].isNotEmpty) ...[
                              const SizedBox(width: 16),
                              ElevatedButton.icon(
                                onPressed: () async {
                                  String urlString =
                                      ((widget.app['trailer_url'] ??
                                          widget.app['video_url']) ??
                                      widget.app['video_url']);
                                  if (!urlString.startsWith('http://') &&
                                      !urlString.startsWith('https://')) {
                                    urlString = 'https://$urlString';
                                  }

                                  final videoId =
                                      YoutubePlayerController.convertUrlToId(
                                        urlString,
                                      );

                                  if (videoId != null && context.mounted) {
                                    showDialog(
                                      context: context,
                                      builder: (context) =>
                                          TrailerDialog(videoId: videoId),
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
                                        SnackBar(
                                          content: Text(
                                            tr('Could not launch trailer'),
                                          ),
                                        ),
                                      );
                                    }
                                  }
                                },
                                icon: const Icon(
                                  Icons.play_circle_fill,
                                  size: 28,
                                ),
                                label: Text(
                                  tr('Watch Trailer'),
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 32,
                                    vertical: 24,
                                  ),
                                  backgroundColor: Theme.of(
                                    context,
                                  ).colorScheme.secondary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),

                        const SizedBox(height: 48),
                        Text(
                          tr('Description'),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Theme.of(
                                context,
                              ).dividerColor.withValues(alpha: 0.1),
                            ),
                          ),
                          child:
                              widget.app['description'] != null &&
                                  widget.app['description']
                                      .toString()
                                      .toLowerCase()
                                      .contains('<')
                              ? Html(data: widget.app['description'])
                              : Text(
                                  widget.app['description'] ??
                                      'No description available.',
                                  style: TextStyle(
                                    fontSize: 18,
                                    height: 1.6,
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.color
                                        ?.withValues(alpha: 0.8),
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          var begin = Offset(0.0, 1.0);
          var end = Offset.zero;
          var curve = Curves.easeInOut;

          var tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));
          var offsetAnimation = animation.drive(tween);

          return FadeTransition(
            opacity: animation,
            child: SlideTransition(position: offsetAnimation, child: child),
          );
        },
      ),
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
                              child: Center(
                                child: Icon(
                                  Icons.vrpano,
                                  size: 64,
                                  color: Colors.white54,
                                ),
                              ),
                            ),
                          ),
                          if (_isHovered && hasMultipleImages)
                            Positioned.fill(
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      Icons.chevron_left,
                                      color: Colors.white,
                                      size: 32,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _currentImageIndex =
                                            (_currentImageIndex - 1) %
                                            images.length;
                                        if (_currentImageIndex < 0) {
                                          _currentImageIndex += images.length;
                                        }
                                      });
                                    },
                                    style: IconButton.styleFrom(
                                      backgroundColor: Colors.black45,
                                      shape: CircleBorder(),
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.chevron_right,
                                      color: Colors.white,
                                      size: 32,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _currentImageIndex =
                                            (_currentImageIndex + 1) %
                                            images.length;
                                      });
                                    },
                                    style: IconButton.styleFrom(
                                      backgroundColor: Colors.black45,
                                      shape: CircleBorder(),
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
                                    margin: EdgeInsets.symmetric(horizontal: 2),
                                    width: _currentImageIndex == index ? 8 : 6,
                                    height: _currentImageIndex == index ? 8 : 6,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _currentImageIndex == index
                                          ? Colors.white
                                          : Colors.white54,
                                    ),
                                  );
                                }),
                              ),
                            ),
                        ],
                      )
                    : Container(
                        color: Colors.grey[800],
                        child: Center(
                          child: Icon(
                            Icons.vrpano,
                            size: 64,
                            color: Colors.white54,
                          ),
                        ),
                      ),
              ),
              Expanded(
                flex: 4,
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Flexible(
                              child: AutoSizeText(
                                ((widget.app['name'] ?? widget.app['title']) ??
                                        widget.app['title']) ??
                                    'Unknown App',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                                minFontSize: 12,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (getAppSize(widget.app) > 0)
                              Padding(
                                padding: EdgeInsets.only(top: 4.0),
                                child: Text(
                                  'Size: ${formatBytes(getAppSize(widget.app))}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.color
                                        ?.withValues(alpha: 0.7),
                                  ),
                                ),
                              ),
                            if (widget.app['ovrport'] == 1 ||
                                widget.app['ovrport'] == true ||
                                widget.app['ovrport'] == '1' ||
                                widget.app['ovrport'] == 'true')
                              Padding(
                                padding: EdgeInsets.only(top: 4.0),
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent.withValues(
                                      alpha: 0.2,
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Ovrport',
                                    style: TextStyle(
                                      color: Colors.redAccent,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Container(
                              padding: EdgeInsets.symmetric(
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
                                ((widget.app['categories'] ??
                                            widget.app['category']) ??
                                        widget.app['category']) ??
                                    '',
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
                          SizedBox(width: 8),
                          StarRating(
                            rating: parseRating(
                              ((widget.app['user_rating'] ??
                                      widget.app['rating']) ??
                                  widget.app['rating']),
                            ),
                            size: 18,
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
