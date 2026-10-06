import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../models/media.dart';
import '../services/app_services.dart';
import '../services/collections_service.dart';
import '../utils/format.dart';
import '../widgets/artwork.dart';
import '../widgets/mini_player.dart';
import '../widgets/track_tile.dart';

/// Canciones de un artista, álbum, carpeta, las favoritas o una lista.
class TrackListScreen extends StatelessWidget {
  const TrackListScreen({
    super.key,
    required this.services,
    required this.title,
    required this.tracks,
    this.playlist,
  });

  final AppServices services;
  final String title;

  /// Se vuelve a pedir cuando cambian la biblioteca o las listas.
  final List<Track> Function() tracks;

  /// Si es una lista del usuario: se puede renombrar, borrar y quitar canciones.
  final Playlist? playlist;

  Future<void> _rename(BuildContext context, Playlist p) async {
    final name = await askPlaylistName(context, initial: p.name);
    if (name != null) await services.collections.renamePlaylist(p, name);
  }

  Future<void> _delete(BuildContext context, Playlist p) async {
    final s = S.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(s.deletePlaylistQuestion(p.name)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(s.cancel)),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(s.delete)),
        ],
      ),
    );
    if (ok == true) {
      await services.collections.deletePlaylist(p);
      if (context.mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final p = playlist;
    return ListenableBuilder(
      listenable: Listenable.merge([services.library, services.collections]),
      builder: (context, _) {
        final list = tracks();
        final total = list.fold<Duration>(Duration.zero, (sum, t) => sum + t.duration);
        return Scaffold(
          appBar: AppBar(
            title: Text(p?.name ?? title, maxLines: 1, overflow: TextOverflow.ellipsis),
            actions: [
              if (p != null)
                PopupMenuButton<String>(
                  onSelected: (v) => v == 'rename' ? _rename(context, p) : _delete(context, p),
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'rename', child: Text(s.rename)),
                    PopupMenuItem(value: 'delete', child: Text(s.deletePlaylist)),
                  ],
                ),
            ],
          ),
          bottomNavigationBar: MiniPlayer(services: services),
          body: list.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(p != null ? s.emptyPlaylist : s.noSongs, textAlign: TextAlign.center),
                  ),
                )
              : ListView.builder(
                  itemCount: list.length + 1,
                  itemBuilder: (context, i) {
                    if (i == 0) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        child: Row(
                          children: [
                            Artwork(mediaStore: services.mediaStore, uri: list.first.uri, size: 72, radius: 14),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                '${s.songCount(list.length)} · ${formatTotal(total)}',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                            IconButton.filledTonal(
                              tooltip: s.shuffle,
                              icon: const Icon(Icons.shuffle_rounded),
                              onPressed: () => services.player.playTracks(list, shuffle: true),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filled(
                              tooltip: s.play,
                              icon: const Icon(Icons.play_arrow_rounded),
                              onPressed: () => services.player.playTracks(list),
                            ),
                          ],
                        ),
                      );
                    }
                    final track = list[i - 1];
                    return TrackTile(
                      track: track,
                      services: services,
                      playlist: p,
                      onTap: () => services.player.playTracks(list, index: i - 1),
                    );
                  },
                ),
        );
      },
    );
  }
}
