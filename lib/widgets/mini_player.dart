import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../screens/now_playing_screen.dart';
import '../services/app_services.dart';
import 'artwork.dart';

/// Barra inferior con la canción actual. Al tocarla abre el reproductor completo.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key, required this.services});

  final AppServices services;

  @override
  Widget build(BuildContext context) {
    final player = services.player;
    return ListenableBuilder(
      listenable: player,
      builder: (context, _) {
        final track = player.current;
        if (track == null) return const SizedBox.shrink();
        final s = S.of(context);
        final scheme = Theme.of(context).colorScheme;
        return Material(
          color: scheme.surfaceContainerHigh,
          child: SafeArea(
            top: false,
            child: InkWell(
              onTap: () => NowPlayingScreen.open(context, services),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  StreamBuilder<Duration>(
                    stream: player.positionStream,
                    builder: (context, snap) {
                      final total = player.duration ?? track.duration;
                      final pos = snap.data ?? Duration.zero;
                      final value = total.inMilliseconds <= 0 ? 0.0 : pos.inMilliseconds / total.inMilliseconds;
                      return LinearProgressIndicator(value: value.clamp(0.0, 1.0), minHeight: 2);
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                    child: Row(
                      children: [
                        Artwork(mediaStore: services.mediaStore, uri: track.uri, size: 44, radius: 8),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w600)),
                              Text(
                                track.artist.isEmpty ? s.unknownArtist : track.artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: player.isPlaying ? s.pause : s.play,
                          iconSize: 34,
                          icon: Icon(player.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
                          onPressed: player.togglePlay,
                        ),
                        IconButton(
                          tooltip: s.next,
                          icon: const Icon(Icons.skip_next_rounded),
                          onPressed: player.skipToNext,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
