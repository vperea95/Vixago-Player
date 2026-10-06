import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../models/media.dart';
import '../services/app_services.dart';
import '../services/lyrics_service.dart';

/// Letra de la canción actual. Si está sincronizada, resalta la línea que suena
/// y se desplaza sola; tocar una línea salta a ese momento.
class LyricsScreen extends StatefulWidget {
  const LyricsScreen({super.key, required this.services});

  final AppServices services;

  @override
  State<LyricsScreen> createState() => _LyricsScreenState();
}

class _LyricsScreenState extends State<LyricsScreen> {
  static const _lineHeight = 56.0;
  static const _topPadding = 120.0;

  final _scroll = ScrollController();
  Track? _track;
  Future<Lyrics?>? _future;
  int _currentLine = -1;

  @override
  void initState() {
    super.initState();
    widget.services.player.addListener(_onPlayer);
    _track = widget.services.player.current;
    final track = _track;
    if (track != null) _future = widget.services.lyrics.forTrack(track);
  }

  @override
  void dispose() {
    widget.services.player.removeListener(_onPlayer);
    _scroll.dispose();
    super.dispose();
  }

  /// Si cambia la canción, busca la nueva letra.
  void _onPlayer() {
    final track = widget.services.player.current;
    if (track?.id == _track?.id) return;
    setState(() {
      _track = track;
      _currentLine = -1;
      _future = track == null ? null : widget.services.lyrics.forTrack(track);
    });
  }

  void _retry() {
    final track = _track;
    if (track == null) return;
    setState(() => _future = widget.services.lyrics.forget(track.id).then((_) => widget.services.lyrics.forTrack(track)));
  }

  void _follow(List<LyricLine> lines, Duration position) {
    var index = -1;
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].time <= position) {
        index = i;
      } else {
        break;
      }
    }
    if (index == _currentLine) return;
    _currentLine = index;
    if (index >= 0 && _scroll.hasClients) {
      // Deja la línea actual un poco arriba del centro.
      final target = (_topPadding + index * _lineHeight - _scroll.position.viewportDimension * 0.4)
          .clamp(0.0, _scroll.position.maxScrollExtent);
      _scroll.animateTo(target, duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final track = _track;
    return Scaffold(
      appBar: AppBar(
        title: Text(track?.title ?? s.lyrics, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: track == null
          ? Center(child: Text(s.nothingPlaying))
          : FutureBuilder<Lyrics?>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(s.searchingLyrics),
                      ],
                    ),
                  );
                }
                final lyrics = snap.data;
                if (lyrics == null) return _notFound(s);
                if (lyrics.instrumental && !lyrics.isSynced && lyrics.plain.isEmpty) {
                  return Center(child: Text(s.instrumental));
                }
                return lyrics.isSynced ? _synced(lyrics.synced) : _plain(lyrics.plain);
              },
            ),
    );
  }

  Widget _notFound(S s) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lyrics_outlined, size: 56),
            const SizedBox(height: 12),
            Text(s.lyricsNotFound, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.tonal(onPressed: _retry, child: Text(s.retry)),
          ],
        ),
      ),
    );
  }

  Widget _plain(String text) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Text(text, style: const TextStyle(fontSize: 18, height: 1.6)),
    );
  }

  Widget _synced(List<LyricLine> lines) {
    final scheme = Theme.of(context).colorScheme;
    final player = widget.services.player;
    return StreamBuilder<Duration>(
      stream: player.positionStream,
      builder: (context, snap) {
        final position = snap.data ?? Duration.zero;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _follow(lines, position);
        });
        return ListView.builder(
          controller: _scroll,
          padding: const EdgeInsets.symmetric(vertical: _topPadding, horizontal: 24),
          itemExtent: _lineHeight,
          itemCount: lines.length,
          itemBuilder: (context, i) {
            final active = i == _currentLine;
            return InkWell(
              onTap: () => player.seek(lines[i].time),
              child: Align(
                alignment: Alignment.centerLeft,
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: TextStyle(
                    fontSize: active ? 22 : 18,
                    fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                    color: active ? scheme.primary : scheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                  child: Text(lines[i].text.isEmpty ? '♪' : lines[i].text, maxLines: 2, overflow: TextOverflow.ellipsis),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
