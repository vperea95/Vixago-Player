import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/media.dart';
import 'media_store.dart';

/// Álbum armado a partir de las canciones.
class Album {
  const Album({required this.id, required this.name, required this.artist, required this.tracks});

  final int id;
  final String name;
  final String artist;
  final List<Track> tracks;
}

/// Biblioteca de música y videos. Solo muestra lo que está en las carpetas que
/// el usuario eligió (así no aparecen, por ejemplo, los audios de WhatsApp).
class LibraryService extends ChangeNotifier {
  LibraryService(this.api);

  static const _musicFoldersKey = 'music_folders';
  static const _videoFoldersKey = 'video_folders';
  static const _setupDoneKey = 'setup_done';

  final MediaStoreApi api;
  SharedPreferences? _prefs;

  bool hasPermission = false;
  bool scanning = false;

  /// Ya pasó por la configuración inicial (permiso + carpetas).
  bool setupDone = false;

  List<Track> _allTracks = const [];
  List<VideoItem> _allVideos = const [];
  Set<String> _musicFolders = {};
  Set<String> _videoFolders = {};

  List<Track> tracks = const [];
  List<VideoItem> videos = const [];

  Set<String> get musicFolders => Set.unmodifiable(_musicFolders);
  Set<String> get videoFolders => Set.unmodifiable(_videoFolders);

  /// Todas las carpetas del celular que tienen música, para elegir.
  List<MediaFolder> get availableMusicFolders => _foldersOf(_allTracks.map((t) => t.folder));

  /// Todas las carpetas del celular que tienen videos, para elegir.
  List<MediaFolder> get availableVideoFolders => _foldersOf(_allVideos.map((v) => v.folder));

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    _musicFolders = (_prefs!.getStringList(_musicFoldersKey) ?? const []).toSet();
    _videoFolders = (_prefs!.getStringList(_videoFoldersKey) ?? const []).toSet();
    setupDone = _prefs!.getBool(_setupDoneKey) ?? false;
    hasPermission = await api.hasPermission();
    if (hasPermission) await scan();
    notifyListeners();
  }

  Future<bool> requestPermission() async {
    hasPermission = await api.requestPermission();
    if (hasPermission) await scan();
    notifyListeners();
    return hasPermission;
  }

  /// Vuelve a leer la música y los videos del celular.
  Future<void> scan() async {
    if (!hasPermission) return;
    scanning = true;
    notifyListeners();
    final results = await Future.wait([api.audio(), api.videos()]);
    _allTracks = results[0] as List<Track>;
    _allVideos = results[1] as List<VideoItem>;
    scanning = false;
    _applyFolders();
  }

  Future<void> setMusicFolders(Set<String> folders) async {
    _musicFolders = Set.of(folders);
    _applyFolders();
    await _prefs?.setStringList(_musicFoldersKey, _musicFolders.toList());
  }

  Future<void> setVideoFolders(Set<String> folders) async {
    _videoFolders = Set.of(folders);
    _applyFolders();
    await _prefs?.setStringList(_videoFoldersKey, _videoFolders.toList());
  }

  Future<void> completeSetup() async {
    setupDone = true;
    notifyListeners();
    await _prefs?.setBool(_setupDoneKey, true);
  }

  void _applyFolders() {
    tracks = _allTracks.where((t) => _musicFolders.contains(t.folder)).toList()
      ..sort((a, b) => _compare(a.title, b.title));
    videos = _allVideos.where((v) => _videoFolders.contains(v.folder)).toList()
      ..sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
    notifyListeners();
  }

  Track? trackById(int id) {
    for (final t in tracks) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// Artistas (vacío = artista desconocido), de la A a la Z.
  Map<String, List<Track>> get artists {
    final map = <String, List<Track>>{};
    for (final t in tracks) {
      map.putIfAbsent(t.artist, () => []).add(t);
    }
    final keys = map.keys.toList()..sort(_compareUnknownLast);
    return {for (final k in keys) k: map[k]!};
  }

  List<Album> get albums {
    final map = <int, List<Track>>{};
    for (final t in tracks) {
      map.putIfAbsent(t.albumId, () => []).add(t);
    }
    final result = map.entries.map((e) {
      final list = e.value..sort((a, b) => a.trackNumber.compareTo(b.trackNumber));
      final first = list.first;
      final artists = list.map((t) => t.artist).where((a) => a.isNotEmpty).toSet();
      return Album(
        id: e.key,
        name: first.album,
        artist: artists.length == 1 ? artists.first : '',
        tracks: list,
      );
    }).toList()
      ..sort((a, b) => _compareUnknownLast(a.name, b.name));
    return result;
  }

  /// Canciones agrupadas por carpeta (solo las elegidas).
  Map<String, List<Track>> get trackFolders {
    final map = <String, List<Track>>{};
    for (final t in tracks) {
      map.putIfAbsent(t.folder, () => []).add(t);
    }
    final keys = map.keys.toList()..sort((a, b) => _compare(_last(a), _last(b)));
    return {for (final k in keys) k: map[k]!};
  }

  /// Videos agrupados por carpeta (solo las elegidas).
  Map<String, List<VideoItem>> get videoFoldersContent {
    final map = <String, List<VideoItem>>{};
    for (final v in videos) {
      map.putIfAbsent(v.folder, () => []).add(v);
    }
    final keys = map.keys.toList()..sort((a, b) => _compare(_last(a), _last(b)));
    return {for (final k in keys) k: map[k]!};
  }

  static List<MediaFolder> _foldersOf(Iterable<String> folders) {
    final counts = <String, int>{};
    for (final f in folders) {
      if (f.isEmpty) continue;
      counts[f] = (counts[f] ?? 0) + 1;
    }
    final list = counts.entries.map((e) => MediaFolder(path: e.key, count: e.value)).toList()
      ..sort((a, b) => _compare(a.displayPath, b.displayPath));
    return list;
  }

  static String _last(String path) {
    final parts = path.split('/').where((p) => p.isNotEmpty);
    return parts.isEmpty ? path : parts.last;
  }

  static int _compare(String a, String b) => a.toLowerCase().compareTo(b.toLowerCase());

  /// Orden alfabético dejando al final los vacíos ("desconocido").
  static int _compareUnknownLast(String a, String b) {
    if (a.isEmpty != b.isEmpty) return a.isEmpty ? 1 : -1;
    return _compare(a, b);
  }
}
