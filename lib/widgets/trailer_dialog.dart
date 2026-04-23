import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class TrailerDialog extends StatefulWidget {
  final String videoId;
  const TrailerDialog({super.key, required this.videoId});

  @override
  State<TrailerDialog> createState() => _TrailerDialogState();
}

class _TrailerDialogState extends State<TrailerDialog> {
  VideoPlayerController? _controller;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _loadStream();
  }

  Future<void> _loadStream() async {
    final yt = YoutubeExplode();
    try {
      final manifest = await yt.videos.streamsClient.getManifest(
        widget.videoId,
      );
      // Prefer muxed (audio+video) streams; pick highest bitrate that has video
      final streams = manifest.muxed.sortByBitrate();
      if (streams.isEmpty) throw Exception('No playable stream found');
      final streamInfo = streams.last; // highest bitrate

      final ctrl = VideoPlayerController.networkUrl(
        Uri.parse(streamInfo.url.toString()),
      );
      await ctrl.initialize();
      await ctrl.setLooping(false);
      await ctrl.play();
      if (!mounted) {
        ctrl.dispose();
        return;
      }
      setState(() {
        _controller = ctrl;
        _loading = false;
      });
    } catch (e) {
      if (mounted)
        setState(() {
          _error = e.toString();
          _loading = false;
        });
    } finally {
      yt.close();
    }
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Center(child: _buildBody()),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 8,
            child: _CircleOverlayButton(
              icon: Icons.close,
              onTap: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }
    if (_error != null) {
      return ColoredBox(
        color: Colors.black,
        child: Center(
          child: Text(
            'Could not load video\n$_error',
            style: const TextStyle(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return VideoPlayer(_controller!);
  }
}

// -- Shared helper ------------------------------------------------------------

class _CircleOverlayButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleOverlayButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}
