import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../player/music_player.dart';
import '../services/app_services.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/artwork.dart';
import '../widgets/track_tile.dart';
import 'equalizer_screen.dart';
import 'lyrics_screen.dart';

/// Reproductor completo de la canción actual.
class NowPlayingScreen extends StatelessWidget {
  const NowPlayingScreen({super.key, required this.services});

  final AppServices services;

  static Future<void> open(BuildContext context, AppServices services) {
    return Navigator.push(
      context,
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 280),
        pageBuilder: (_, __, ___) => NowPlayingScreen(services: services),
        transitionsBuilder: (_, animation, __, child) => SlideTransition(
          position: Tween(begin: const Offset(0, 1), end: Offset.zero)
              .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
          child: child,
        ),
      ),
    );
  }

  void _push(BuildContext context, Widget screen) =>
      Navigator.push(context, MaterialPageRoute<void>(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final player = services.player;
    final scheme = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: Listenable.merge([player, services.collections]),
      builder: (context, _) {
        final track = player.current;
        if (track == null) {
          return Scaffold(appBar: AppBar(), body: Center(child: Text(s.nothingPlaying)));
        }
        final favorite = services.collections.isFavorite(track.id);
        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              tooltip: s.close,
              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 32),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(s.nowPlaying, style: Theme.of(context).textTheme.titleMedium),
            centerTitle: true,
            actions: [
              IconButton(
                tooltip: s.equalizer,
                icon: const Icon(Icons.equalizer_rounded),
                onPressed: () => _push(context, EqualizerScreen(services: services)),
              ),
            ],
          ),
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Cuadrada, lo más grande posible sin empujar los controles fuera de la pantalla.
                final maxArt = math.max(120.0, constraints.maxHeight * 0.45);
                final artSize = (constraints.maxWidth - 64).clamp(120.0, maxArt);
                return Column(
                  children: [
                    const Spacer(),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(color: AppColors.blue.withValues(alpha: 0.35), blurRadius: 40, offset: const Offset(0, 16)),
                        ],
                      ),
                      child: Artwork(
                        mediaStore: services.mediaStore,
                        uri: track.uri,
                        size: artSize,
                        radius: 24,
                        thumbSize: 900,
                      ),
                    ),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(track.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                                const SizedBox(height: 2),
                                Text(
                                  track.artist.isEmpty ? s.unknownArtist : track.artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 16),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: favorite ? s.removeFavorite : s.addFavorite,
                            iconSize: 30,
                            color: favorite ? AppColors.violet : null,
                            icon: Icon(favorite ? Icons.favorite_rounded : Icons.favorite_border_rounded),
                            onPressed: () => services.collections.toggleFavorite(track.id),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    _Progress(player: player, fallback: track.duration),
                    _Controls(player: player),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          TextButton.icon(
                            onPressed: () => _push(context, LyricsScreen(services: services)),
                            icon: const Icon(Icons.lyrics_outlined),
                            label: Text(s.lyrics),
                          ),
                          TextButton.icon(
                            onPressed: () => showAddToPlaylist(context, services, [track]),
                            icon: const Icon(Icons.playlist_add_rounded),
                            label: Text(s.addShort),
                          ),
                          TextButton.icon(
                            onPressed: () => _showQueue(context),
                            icon: const Icon(Icons.queue_music_rounded),
                            label: Text(s.queue),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _showQueue(BuildContext context) {
    final s = S.of(context);
    final player = services.player;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.92,
        builder: (context, scroll) => ListenableBuilder(
          listenable: player,
          builder: (context, _) {
            final order = player.upNext;
            final all = player.tracks;
            return ListView.builder(
              controller: scroll,
              itemCount: order.length + 1,
              itemBuilder: (context, i) {
                if (i == 0) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                    child: Text(s.queue, style: Theme.of(context).textTheme.titleMedium),
                  );
                }
                final track = order[i - 1];
                final isCurrent = player.current?.id == track.id;
                return ListTile(
                  leading: Artwork(mediaStore: services.mediaStore, uri: track.uri, size: 40, radius: 8),
                  title: Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: isCurrent ? FontWeight.w800 : null,
                      color: isCurrent ? Theme.of(context).colorScheme.primary : null,
                    ),
                  ),
                  subtitle: Text(track.artist.isEmpty ? s.unknownArtist : track.artist, maxLines: 1),
                  trailing: isCurrent ? const Icon(Icons.graphic_eq_rounded) : null,
                  onTap: () => player.skipToQueueItem(all.indexOf(track)),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.player, required this.fallback});

  final MusicPlayer player;
  final Duration fallback;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: player.positionStream,
      builder: (context, snap) {
        final total = player.duration ?? fallback;
        final max = total.inMilliseconds.toDouble();
        final pos = (snap.data ?? Duration.zero).inMilliseconds.toDouble().clamp(0.0, max <= 0 ? 0.0 : max);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            children: [
              Slider(
                value: max <= 0 ? 0 : pos,
                max: max <= 0 ? 1 : max,
                onChanged: max <= 0 ? null : (v) => player.seek(Duration(milliseconds: v.round())),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(formatDuration(Duration(milliseconds: pos.round()))),
                    Text(formatDuration(total)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({required this.player});

  final MusicPlayer player;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final scheme = Theme.of(context).colorScheme;
    final active = scheme.primary;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(
          tooltip: s.shuffle,
          color: player.shuffle ? active : null,
          icon: const Icon(Icons.shuffle_rounded),
          onPressed: player.toggleShuffle,
        ),
        IconButton(
          tooltip: s.previous,
          iconSize: 40,
          icon: const Icon(Icons.skip_previous_rounded),
          onPressed: player.skipToPrevious,
        ),
        Container(
          decoration: const BoxDecoration(shape: BoxShape.circle, gradient: AppColors.gradient),
          child: IconButton(
            tooltip: player.isPlaying ? s.pause : s.play,
            iconSize: 44,
            color: Colors.white,
            icon: Icon(player.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
            onPressed: player.togglePlay,
          ),
        ),
        IconButton(
          tooltip: s.next,
          iconSize: 40,
          icon: const Icon(Icons.skip_next_rounded),
          onPressed: player.skipToNext,
        ),
        IconButton(
          tooltip: switch (player.repeat) {
            RepeatMode.off => s.repeatOff,
            RepeatMode.all => s.repeatAll,
            RepeatMode.one => s.repeatOne,
          },
          color: player.repeat == RepeatMode.off ? null : active,
          icon: Icon(player.repeat == RepeatMode.one ? Icons.repeat_one_rounded : Icons.repeat_rounded),
          onPressed: player.cycleRepeat,
        ),
      ],
    );
  }
}
