import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../services/api_service.dart';

class ChatMedia extends StatelessWidget {
  final String url;
  final String type;

  const ChatMedia({super.key, required this.url, required this.type});

  @override
  Widget build(BuildContext context) {
    if (type == 'sticker') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.amber.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          url,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      );
    }

    try {
      final uri = ApiService.chatMediaUri(url);
      if (type == 'video') return ChatVideo(uri: uri);
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: uri.scheme == 'data'
            ? Image.memory(
                uri.data!.contentAsBytes(),
                height: 180,
                fit: BoxFit.contain,
                errorBuilder: (_, error, stackTrace) => const _MediaError(),
              )
            : Image.network(
                uri.toString(),
                height: 180,
                fit: BoxFit.contain,
                errorBuilder: (_, error, stackTrace) => const _MediaError(),
              ),
      );
    } on FormatException {
      return const _MediaError();
    }
  }
}

class _MediaError extends StatelessWidget {
  const _MediaError();

  @override
  Widget build(BuildContext context) {
    return const Text('This attachment could not be loaded.');
  }
}

class ChatVideo extends StatefulWidget {
  final Uri uri;

  const ChatVideo({super.key, required this.uri});

  @override
  State<ChatVideo> createState() => _ChatVideoState();
}

class _ChatVideoState extends State<ChatVideo> {
  VideoPlayerController? _controller;
  bool _loading = false;
  String? _error;

  @override
  void didUpdateWidget(ChatVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uri != widget.uri) {
      _releaseController();
      _loading = false;
      _error = null;
    }
  }

  void _releaseController() {
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      controller.removeListener(_onVideoChanged);
      unawaited(controller.dispose());
    }
  }

  @override
  void dispose() {
    _releaseController();
    super.dispose();
  }

  void _onVideoChanged() {
    if (!mounted) return;
    setState(() {
      if (_controller?.value.hasError ?? false) {
        _error =
            'Video could not be played. Check your connection or try again.';
      }
    });
  }

  Future<void> _playOrPause() async {
    if (_loading) return;
    if (_error != null) _releaseController();
    setState(() {
      _error = null;
      _loading = true;
    });
    final controller =
        _controller ?? VideoPlayerController.networkUrl(widget.uri);
    if (_controller == null) {
      _controller = controller;
      controller.addListener(_onVideoChanged);
    }
    try {
      // Load only after a tap, rather than downloading every video in the room.
      if (!controller.value.isInitialized) {
        await controller.initialize().timeout(const Duration(seconds: 30));
      }
      if (!mounted || _controller != controller) return;
      if (controller.value.isPlaying) {
        await controller.pause();
      } else {
        await controller.play();
      }
    } on PlatformException {
      _showPlaybackError(controller);
    } on TimeoutException {
      _showPlaybackError(controller);
    } on UnimplementedError {
      _showPlaybackError(controller);
    } on UnsupportedError {
      _showPlaybackError(controller);
    } finally {
      if (mounted && _controller == controller) {
        setState(() => _loading = false);
      }
    }
  }

  void _showPlaybackError(VideoPlayerController controller) {
    if (!mounted || _controller != controller) return;
    setState(() {
      _error = 'Video could not be played. Check your connection or try again.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final initialized = controller?.value.isInitialized ?? false;
    final playing = controller?.value.isPlaying ?? false;
    return SizedBox(
      width: 240,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (initialized && _error == null)
            AspectRatio(
              aspectRatio: controller!.value.aspectRatio,
              child: VideoPlayer(controller),
            ),
          if (_error != null)
            Text(_error!)
          else if (!initialized)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('Video attachment'),
            ),
          if (initialized && _error == null)
            VideoProgressIndicator(controller!, allowScrubbing: true),
          IconButton(
            tooltip: _error != null
                ? 'Retry video'
                : playing
                ? 'Pause video'
                : 'Play video',
            onPressed: _loading ? null : _playOrPause,
            icon: _loading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(playing ? Icons.pause_circle : Icons.play_circle),
          ),
        ],
      ),
    );
  }
}
