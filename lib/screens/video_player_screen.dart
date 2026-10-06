import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../l10n/strings.dart';
import '../models/media.dart';
import '../services/app_services.dart';
import '../utils/format.dart';

/// Reproductor de video a pantalla completa.
/// - Pausa la música, mantiene la pantalla encendida y continúa donde quedó.
/// - Doble toque a la izquierda/derecha: -10 s / +10 s.
/// - Velocidad, girar pantalla, anterior y siguiente de la misma lista.
class VideoPlayerScreen extends StatefulWidget {
  const VideoPlayerScreen({super.key, required this.services, required this.videos, required this.index});

  final AppServices services;
  final List<VideoItem> videos;
  final int index;

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  late int _index = widget.index;
  bool _showControls = true;
  bool _landscape = false;
  String? _error;
  Timer? _hideTimer;

  /// Se está cambiando de video (evita abrir el siguiente dos veces).
  bool _switching = false;

  VideoItem get _video => widget.videos[_index];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.services.player.pause();
    widget.services.mediaStore.keepScreenOn(true);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _open(_index);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hideTimer?.cancel();
    _saveProgress();
    _controller?.dispose();
    widget.services.mediaStore.keepScreenOn(false);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(const []);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Al salir de la app: pausa y guarda dónde quedó.
    if (state == AppLifecycleState.paused) {
      _controller?.pause();
      _saveProgress();
    } else if (state == AppLifecycleState.inactive) {
      _saveProgress();
    }
  }

  Future<void> _open(int index) async {
    if (_switching) return;
    _switching = true;
    _saveProgress();
    final old = _controller;
    old?.removeListener(_onTick);
    setState(() {
      _index = index;
      _controller = null;
      _error = null;
    });
    await old?.dispose();

    final video = widget.videos[index];
    final controller = VideoPlayerController.contentUri(Uri.parse(video.uri));
    try {
      await controller.initialize();
    } catch (e) {
      await controller.dispose();
      _switching = false;
      if (mounted) setState(() => _error = S.of(context).cannotPlayVideo);
      return;
    }
    if (!mounted) {
      await controller.dispose();
      return;
    }
    final saved = widget.services.videoProgress.positionOf(video.id);
    if (saved != null && saved < controller.value.duration) await controller.seekTo(saved);
    controller.addListener(_onTick);
    _autoOrientation(controller.value.size);
    setState(() => _controller = controller);
    _switching = false;
    await controller.play();
    _scheduleHide();
  }

  void _onTick() {
    final c = _controller;
    if (c == null || !mounted || _switching) return;
    // Terminó: pasa al siguiente si hay.
    final v = c.value;
    if (v.isInitialized && !v.isPlaying && v.duration > Duration.zero && v.position >= v.duration) {
      widget.services.videoProgress.save(_video.id, Duration.zero, v.duration);
      if (_index < widget.videos.length - 1) {
        _open(_index + 1);
        return;
      }
    }
    setState(() {});
  }

  void _saveProgress() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    widget.services.videoProgress.save(_video.id, c.value.position, c.value.duration);
  }

  /// Videos horizontales en horizontal; verticales en vertical.
  void _autoOrientation(Size size) {
    _landscape = size.width > size.height;
    _applyOrientation();
  }

  void _applyOrientation() {
    SystemChrome.setPreferredOrientations(_landscape
        ? const [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]
        : const [DeviceOrientation.portraitUp]);
  }

  void _toggleOrientation() {
    setState(() => _landscape = !_landscape);
    _applyOrientation();
    _scheduleHide();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && (_controller?.value.isPlaying ?? false)) setState(() => _showControls = false);
    });
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _scheduleHide();
  }

  void _togglePlay() {
    final c = _controller;
    if (c == null) return;
    if (c.value.isPlaying) {
      c.pause();
    } else {
      if (c.value.position >= c.value.duration) c.seekTo(Duration.zero);
      c.play();
    }
    _scheduleHide();
  }

  void _seekBy(int seconds) {
    final c = _controller;
    if (c == null) return;
    var target = c.value.position + Duration(seconds: seconds);
    if (target < Duration.zero) target = Duration.zero;
    if (target > c.value.duration) target = c.value.duration;
    c.seekTo(target);
  }

  Future<void> _chooseSpeed() async {
    final c = _controller;
    if (c == null) return;
    final s = S.of(context);
    const speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
    final speed = await showModalBottomSheet<double>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(s.speed, style: Theme.of(sheetContext).textTheme.titleMedium),
            for (final v in speeds)
              ListTile(
                title: Text(v == 1.0 ? s.normalSpeed : '${v}x'),
                trailing: c.value.playbackSpeed == v ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(sheetContext, v),
              ),
          ],
        ),
      ),
    );
    if (speed != null) await c.setPlaybackSpeed(speed);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final c = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      body: _error != null
          ? _errorView(s)
          : c == null
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _toggleControls,
                  onDoubleTapDown: (d) {
                    final width = MediaQuery.sizeOf(context).width;
                    _seekBy(d.localPosition.dx < width / 2 ? -10 : 10);
                  },
                  onDoubleTap: () {},
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Center(
                        child: AspectRatio(
                          aspectRatio: c.value.aspectRatio > 0 ? c.value.aspectRatio : 16 / 9,
                          child: VideoPlayer(c),
                        ),
                      ),
                      AnimatedOpacity(
                        opacity: _showControls ? 1 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: IgnorePointer(ignoring: !_showControls, child: _controls(s, c)),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _errorView(S s) {
    return SafeArea(
      child: Stack(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
            ),
          ),
          IconButton(
            color: Colors.white,
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _controls(S s, VideoPlayerController c) {
    final value = c.value;
    final duration = value.duration;
    final position = value.position > duration ? duration : value.position;
    final max = duration.inMilliseconds.toDouble();
    const white = Colors.white;

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black54, Colors.transparent, Colors.transparent, Colors.black54],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Row(
              children: [
                IconButton(color: white, icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
                Expanded(
                  child: Text(_video.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: white, fontSize: 16, fontWeight: FontWeight.w600)),
                ),
                IconButton(color: white, tooltip: s.speed, icon: const Icon(Icons.speed_rounded), onPressed: _chooseSpeed),
                IconButton(
                  color: white,
                  tooltip: s.rotate,
                  icon: const Icon(Icons.screen_rotation_rounded),
                  onPressed: _toggleOrientation,
                ),
              ],
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  color: white,
                  iconSize: 36,
                  tooltip: s.previous,
                  onPressed: _index > 0 ? () => _open(_index - 1) : null,
                  icon: const Icon(Icons.skip_previous_rounded),
                ),
                const SizedBox(width: 12),
                IconButton(color: white, iconSize: 36, onPressed: () => _seekBy(-10), icon: const Icon(Icons.replay_10_rounded)),
                const SizedBox(width: 12),
                IconButton.filled(
                  iconSize: 48,
                  style: IconButton.styleFrom(backgroundColor: white, foregroundColor: Colors.black),
                  onPressed: _togglePlay,
                  icon: Icon(value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
                ),
                const SizedBox(width: 12),
                IconButton(color: white, iconSize: 36, onPressed: () => _seekBy(10), icon: const Icon(Icons.forward_10_rounded)),
                const SizedBox(width: 12),
                IconButton(
                  color: white,
                  iconSize: 36,
                  tooltip: s.next,
                  onPressed: _index < widget.videos.length - 1 ? () => _open(_index + 1) : null,
                  icon: const Icon(Icons.skip_next_rounded),
                ),
              ],
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Text(formatDuration(position), style: const TextStyle(color: white)),
                  Expanded(
                    child: Slider(
                      value: max <= 0 ? 0 : position.inMilliseconds.toDouble().clamp(0, max),
                      max: max <= 0 ? 1 : max,
                      onChanged: max <= 0
                          ? null
                          : (v) {
                              c.seekTo(Duration(milliseconds: v.round()));
                              _scheduleHide();
                            },
                    ),
                  ),
                  Text(formatDuration(duration), style: const TextStyle(color: white)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
