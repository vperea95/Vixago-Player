import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../models/media.dart';
import '../services/app_services.dart';
import '../services/collections_service.dart';
import '../utils/format.dart';
import 'artwork.dart';

/// Fila de una canción. La que está sonando se resalta.
class TrackTile extends StatelessWidget {
  const TrackTile({
    super.key,
    required this.track,
    required this.services,
    required this.onTap,
    this.playlist,
  });

  final Track track;
  final AppServices services;
  final VoidCallback onTap;

  /// Si la fila está dentro de una lista, el menú permite quitarla de ella.
  final Playlist? playlist;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final scheme = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: services.player,
      builder: (context, _) {
        final isCurrent = services.player.current?.id == track.id;
        return ListTile(
          onTap: onTap,
          leading: Stack(
            children: [
              Artwork(mediaStore: services.mediaStore, uri: track.uri, size: 48),
              if (isCurrent)
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(10)),
                  child: Icon(
                    services.player.isPlaying ? Icons.graphic_eq_rounded : Icons.pause_rounded,
                    color: Colors.white,
                  ),
                ),
            ],
          ),
          title: Text(
            track.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isCurrent ? scheme.primary : null,
              fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          subtitle: Text(
            [
              track.artist.isEmpty ? s.unknownArtist : track.artist,
              if (track.duration > Duration.zero) formatDuration(track.duration),
            ].join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: IconButton(
            tooltip: s.options,
            icon: const Icon(Icons.more_vert),
            onPressed: () => showTrackMenu(context, services, track, playlist: playlist),
          ),
        );
      },
    );
  }
}

/// Menú de una canción: cola, favorita, listas.
Future<void> showTrackMenu(BuildContext context, AppServices services, Track track, {Playlist? playlist}) {
  final s = S.of(context);
  final collections = services.collections;
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Artwork(mediaStore: services.mediaStore, uri: track.uri, size: 44),
            title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(track.artist.isEmpty ? s.unknownArtist : track.artist),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.queue_music_rounded),
            title: Text(s.addToQueue),
            onTap: () {
              Navigator.pop(sheetContext);
              services.player.addToQueue([track]);
              _snack(context, s.addedToQueue);
            },
          ),
          ListTile(
            leading: Icon(collections.isFavorite(track.id) ? Icons.favorite : Icons.favorite_border),
            title: Text(collections.isFavorite(track.id) ? s.removeFavorite : s.addFavorite),
            onTap: () {
              Navigator.pop(sheetContext);
              collections.toggleFavorite(track.id);
            },
          ),
          ListTile(
            leading: const Icon(Icons.playlist_add_rounded),
            title: Text(s.addToPlaylist),
            onTap: () {
              Navigator.pop(sheetContext);
              showAddToPlaylist(context, services, [track]);
            },
          ),
          if (playlist != null)
            ListTile(
              leading: const Icon(Icons.playlist_remove_rounded),
              title: Text(s.removeFromPlaylist),
              onTap: () {
                Navigator.pop(sheetContext);
                collections.removeFromPlaylist(playlist, track.id);
              },
            ),
        ],
      ),
    ),
  );
}

/// Elegir una lista (o crear una nueva) y agregar las canciones.
Future<void> showAddToPlaylist(BuildContext context, AppServices services, List<Track> tracks) async {
  final s = S.of(context);
  final collections = services.collections;
  final ids = tracks.map((t) => t.id).toList();
  final choice = await showModalBottomSheet<Object>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(s.addToPlaylist, style: Theme.of(sheetContext).textTheme.titleMedium),
          ),
          ListTile(
            leading: const Icon(Icons.add_rounded),
            title: Text(s.newPlaylist),
            onTap: () => Navigator.pop(sheetContext, 'new'),
          ),
          for (final p in collections.playlists)
            ListTile(
              leading: const Icon(Icons.queue_music_rounded),
              title: Text(p.name),
              subtitle: Text(s.songCount(p.trackIds.length)),
              onTap: () => Navigator.pop(sheetContext, p),
            ),
        ],
      ),
    ),
  );
  if (!context.mounted || choice == null) return;
  if (choice == 'new') {
    final name = await askPlaylistName(context);
    if (name == null || !context.mounted) return;
    await collections.createPlaylist(name, trackIds: ids);
    if (context.mounted) _snack(context, s.addedToPlaylist(name));
  } else if (choice is Playlist) {
    await collections.addToPlaylist(choice, ids);
    if (context.mounted) _snack(context, s.addedToPlaylist(choice.name));
  }
}

/// Pide el nombre de una lista. Null si cancela.
Future<String?> askPlaylistName(BuildContext context, {String initial = ''}) {
  final s = S.of(context);
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(initial.isEmpty ? s.newPlaylist : s.rename),
      content: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(hintText: s.playlistName),
        onSubmitted: (v) {
          if (v.trim().isNotEmpty) Navigator.pop(dialogContext, v.trim());
        },
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(s.cancel)),
        FilledButton(
          onPressed: () {
            final v = controller.text.trim();
            if (v.isNotEmpty) Navigator.pop(dialogContext, v);
          },
          child: Text(s.save),
        ),
      ],
    ),
  );
}

void _snack(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}
