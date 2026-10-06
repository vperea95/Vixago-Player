import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Una lista de reproducción creada por el usuario.
class Playlist {
  Playlist({required this.id, required this.name, required this.trackIds});

  final String id;
  String name;
  final List<int> trackIds;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'tracks': trackIds};

  static Playlist? fromJson(Object? json) {
    if (json is! Map) return null;
    return Playlist(
      id: '${json['id']}',
      name: '${json['name'] ?? ''}',
      trackIds: [for (final t in (json['tracks'] as List? ?? const [])) if (t is num) t.toInt()],
    );
  }
}

/// Favoritas y listas de reproducción, guardadas en el celular (por ID de canción).
class CollectionsService extends ChangeNotifier {
  static const _favoritesKey = 'favorite_tracks';
  static const _playlistsKey = 'playlists';

  SharedPreferences? _prefs;
  final List<int> _favorites = [];
  final List<Playlist> _playlists = [];

  List<int> get favorites => List.unmodifiable(_favorites);
  List<Playlist> get playlists => List.unmodifiable(_playlists);

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    _favorites
      ..clear()
      ..addAll((_prefs!.getStringList(_favoritesKey) ?? const []).map(int.tryParse).whereType<int>());
    _playlists.clear();
    final raw = _prefs!.getString(_playlistsKey);
    if (raw != null) {
      try {
        _playlists.addAll((jsonDecode(raw) as List).map(Playlist.fromJson).whereType<Playlist>());
      } catch (e) {
        debugPrint('Listas dañadas: $e');
      }
    }
    notifyListeners();
  }

  bool isFavorite(int trackId) => _favorites.contains(trackId);

  Future<void> toggleFavorite(int trackId) async {
    if (!_favorites.remove(trackId)) _favorites.insert(0, trackId);
    notifyListeners();
    await _prefs?.setStringList(_favoritesKey, _favorites.map((e) => '$e').toList());
  }

  Future<Playlist> createPlaylist(String name, {List<int> trackIds = const []}) async {
    final playlist = Playlist(
      id: '${DateTime.now().microsecondsSinceEpoch}',
      name: name.trim(),
      trackIds: List.of(trackIds),
    );
    _playlists.add(playlist);
    await _savePlaylists();
    return playlist;
  }

  Future<void> renamePlaylist(Playlist playlist, String name) async {
    playlist.name = name.trim();
    await _savePlaylists();
  }

  Future<void> deletePlaylist(Playlist playlist) async {
    _playlists.removeWhere((p) => p.id == playlist.id);
    await _savePlaylists();
  }

  /// Agrega sin repetir. Devuelve cuántas canciones se agregaron.
  Future<int> addToPlaylist(Playlist playlist, List<int> trackIds) async {
    var added = 0;
    for (final id in trackIds) {
      if (!playlist.trackIds.contains(id)) {
        playlist.trackIds.add(id);
        added++;
      }
    }
    await _savePlaylists();
    return added;
  }

  Future<void> removeFromPlaylist(Playlist playlist, int trackId) async {
    playlist.trackIds.remove(trackId);
    await _savePlaylists();
  }

  Future<void> _savePlaylists() async {
    notifyListeners();
    await _prefs?.setString(_playlistsKey, jsonEncode(_playlists.map((p) => p.toJson()).toList()));
  }
}
