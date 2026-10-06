import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../models/media.dart';
import '../services/app_services.dart';
import '../services/collections_service.dart';
import '../widgets/artwork.dart';
import '../widgets/mini_player.dart';
import '../widgets/track_tile.dart';
import 'track_list_screen.dart';

/// Música: canciones, artistas, álbumes, carpetas y listas.
class MusicScreen extends StatelessWidget {
  const MusicScreen({super.key, required this.services});

  final AppServices services;

  void _openList(BuildContext context, String title, List<Track> Function() tracks, {Playlist? playlist}) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => TrackListScreen(services: services, title: title, tracks: tracks, playlist: playlist),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: Text(s.music),
          actions: [
            IconButton(
              tooltip: s.search,
              icon: const Icon(Icons.search_rounded),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(builder: (_) => _SearchScreen(services: services)),
              ),
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: s.songs),
              Tab(text: s.artists),
              Tab(text: s.albums),
              Tab(text: s.foldersTab),
              Tab(text: s.playlists),
            ],
          ),
        ),
        bottomNavigationBar: MiniPlayer(services: services),
        body: ListenableBuilder(
          listenable: Listenable.merge([services.library, services.collections]),
          builder: (context, _) => TabBarView(
            children: [
              _songs(context, s),
              _artists(context, s),
              _albums(context, s),
              _folders(context, s),
              _playlists(context, s),
            ],
          ),
        ),
      ),
    );
  }

  Widget _songs(BuildContext context, S s) {
    final tracks = services.library.tracks;
    if (tracks.isEmpty) return _empty(s.noSongs);
    return ListView.builder(
      itemCount: tracks.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                Expanded(child: Text(s.songCount(tracks.length))),
                FilledButton.tonalIcon(
                  onPressed: () => services.player.playTracks(tracks, shuffle: true),
                  icon: const Icon(Icons.shuffle_rounded),
                  label: Text(s.shuffle),
                ),
              ],
            ),
          );
        }
        return TrackTile(
          track: tracks[i - 1],
          services: services,
          onTap: () => services.player.playTracks(tracks, index: i - 1),
        );
      },
    );
  }

  Widget _artists(BuildContext context, S s) {
    final artists = services.library.artists;
    if (artists.isEmpty) return _empty(s.noSongs);
    final names = artists.keys.toList();
    return ListView.builder(
      itemCount: names.length,
      itemBuilder: (context, i) {
        final name = names[i];
        final tracks = artists[name]!;
        final label = name.isEmpty ? s.unknownArtist : name;
        return ListTile(
          leading: Artwork(mediaStore: services.mediaStore, uri: tracks.first.uri, size: 48, radius: 24),
          title: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(s.songCount(tracks.length)),
          onTap: () => _openList(context, label, () => services.library.artists[name] ?? const []),
        );
      },
    );
  }

  Widget _albums(BuildContext context, S s) {
    final albums = services.library.albums;
    if (albums.isEmpty) return _empty(s.noSongs);
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.78,
      ),
      itemCount: albums.length,
      itemBuilder: (context, i) {
        final album = albums[i];
        final name = album.name.isEmpty ? s.unknownAlbum : album.name;
        return InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _openList(
            context,
            name,
            () => services.library.albums.where((a) => a.id == album.id).firstOrNull?.tracks ?? const [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: Artwork(mediaStore: services.mediaStore, uri: album.tracks.first.uri, size: null, radius: 14, thumbSize: 400),
              ),
              const SizedBox(height: 6),
              Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(
                album.artist.isEmpty ? s.songCount(album.tracks.length) : album.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _folders(BuildContext context, S s) {
    final folders = services.library.trackFolders;
    if (folders.isEmpty) return _empty(s.noSongs);
    final paths = folders.keys.toList();
    return ListView.builder(
      itemCount: paths.length,
      itemBuilder: (context, i) {
        final path = paths[i];
        final folder = MediaFolder(path: path, count: folders[path]!.length);
        return ListTile(
          leading: const CircleAvatar(child: Icon(Icons.folder_rounded)),
          title: Text(folder.name),
          subtitle: Text('${folder.displayPath}\n${s.songCount(folder.count)}', maxLines: 2, overflow: TextOverflow.ellipsis),
          isThreeLine: true,
          onTap: () => _openList(context, folder.name, () => services.library.trackFolders[path] ?? const []),
        );
      },
    );
  }

  Widget _playlists(BuildContext context, S s) {
    final collections = services.collections;
    final library = services.library;
    List<Track> favorites() => collections.favorites.map(library.trackById).whereType<Track>().toList();
    List<Track> Function() tracksOf(Playlist p) =>
        () => p.trackIds.map(library.trackById).whereType<Track>().toList();

    return ListView(
      children: [
        ListTile(
          leading: const CircleAvatar(child: Icon(Icons.favorite_rounded)),
          title: Text(s.favorites),
          subtitle: Text(s.songCount(favorites().length)),
          onTap: () => _openList(context, s.favorites, favorites),
        ),
        for (final p in collections.playlists)
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.queue_music_rounded)),
            title: Text(p.name),
            subtitle: Text(s.songCount(tracksOf(p)().length)),
            onTap: () => _openList(context, p.name, tracksOf(p), playlist: p),
          ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: OutlinedButton.icon(
            onPressed: () async {
              final name = await askPlaylistName(context);
              if (name != null) await collections.createPlaylist(name);
            },
            icon: const Icon(Icons.add_rounded),
            label: Text(s.newPlaylist),
          ),
        ),
      ],
    );
  }

  Widget _empty(String text) => Center(
        child: Padding(padding: const EdgeInsets.all(32), child: Text(text, textAlign: TextAlign.center)),
      );
}

/// Busca canciones por título, artista o álbum (sin importar tildes).
class _SearchScreen extends StatefulWidget {
  const _SearchScreen({required this.services});

  final AppServices services;

  @override
  State<_SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<_SearchScreen> {
  String _query = '';

  static String _norm(String text) {
    const from = 'áéíóúüñàèìòù';
    const to = 'aeiouunaeiou';
    final lower = text.toLowerCase();
    final buffer = StringBuffer();
    for (final ch in lower.split('')) {
      final i = from.indexOf(ch);
      buffer.write(i >= 0 ? to[i] : ch);
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final q = _norm(_query.trim());
    final results = q.isEmpty
        ? const <Track>[]
        : widget.services.library.tracks
            .where((t) => _norm('${t.title} ${t.artist} ${t.album}').contains(q))
            .toList();
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          autofocus: true,
          decoration: InputDecoration(hintText: s.searchHint, border: InputBorder.none),
          onChanged: (v) => setState(() => _query = v),
        ),
      ),
      bottomNavigationBar: MiniPlayer(services: widget.services),
      body: q.isEmpty
          ? const SizedBox.shrink()
          : results.isEmpty
              ? Center(child: Text(s.noResults))
              : ListView.builder(
                  itemCount: results.length,
                  itemBuilder: (context, i) => TrackTile(
                    track: results[i],
                    services: widget.services,
                    onTap: () => widget.services.player.playTracks(results, index: i),
                  ),
                ),
    );
  }
}
