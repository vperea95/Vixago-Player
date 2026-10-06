import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../models/media.dart';

class LyricLine {
  const LyricLine(this.time, this.text);

  final Duration time;
  final String text;
}

class Lyrics {
  const Lyrics({required this.synced, required this.plain, required this.instrumental});

  /// Con tiempos: se resalta la línea que suena. Vacía si solo hay letra simple.
  final List<LyricLine> synced;
  final String plain;
  final bool instrumental;

  bool get isSynced => synced.isNotEmpty;

  static Lyrics? fromLrclib(Map<String, dynamic> json) {
    final synced = parseLrc('${json['syncedLyrics'] ?? ''}');
    final plain = '${json['plainLyrics'] ?? ''}'.trim();
    final instrumental = json['instrumental'] == true;
    if (synced.isEmpty && plain.isEmpty && !instrumental) return null;
    return Lyrics(synced: synced, plain: plain, instrumental: instrumental);
  }

  /// Formato LRC: "[01:23.45] texto". Una línea puede tener varios tiempos.
  static List<LyricLine> parseLrc(String lrc) {
    final stamp = RegExp(r'\[(\d+):(\d+(?:\.\d+)?)\]');
    final lines = <LyricLine>[];
    for (final raw in const LineSplitter().convert(lrc)) {
      final matches = stamp.allMatches(raw).toList();
      if (matches.isEmpty) continue;
      final text = raw.substring(matches.last.end).trim();
      for (final m in matches) {
        final ms = (int.parse(m.group(1)!) * 60000 + double.parse(m.group(2)!) * 1000).round();
        lines.add(LyricLine(Duration(milliseconds: ms), text));
      }
    }
    lines.sort((a, b) => a.time.compareTo(b.time));
    return lines;
  }
}

/// Letras desde LRCLIB (https://lrclib.net): gratuito y sin clave.
/// Se guardan en el celular para no volver a buscarlas.
class LyricsService {
  static const _base = 'https://lrclib.net/api';
  static const _headers = {'User-Agent': 'VixagoPlayer/0.2 (https://github.com/vperea95/Vixago-Player)'};

  final Map<int, Lyrics?> _memory = {};

  /// Hubo un problema de conexión en la última búsqueda (no se guarda como "sin letra").
  bool _failed = false;

  Future<Lyrics?> forTrack(Track track) async {
    if (_memory.containsKey(track.id)) return _memory[track.id];
    final cached = await _readCache(track.id);
    if (cached != null) {
      final lyrics = cached['found'] == true ? Lyrics.fromLrclib(Map<String, dynamic>.from(cached['data'] as Map)) : null;
      _memory[track.id] = lyrics;
      return lyrics;
    }

    final (artist, title) = _searchTerms(track);
    _failed = false;
    Map<String, dynamic>? found;
    if (artist.isNotEmpty) {
      found = await _get({
        'artist_name': artist,
        'track_name': title,
        if (track.album.isNotEmpty) 'album_name': track.album,
        if (track.duration > Duration.zero) 'duration': '${track.duration.inSeconds}',
      });
    }
    found ??= await _search(artist, title, track.duration);

    final lyrics = found == null ? null : Lyrics.fromLrclib(found);
    if (lyrics == null && _failed) return null;
    _memory[track.id] = lyrics;
    await _writeCache(track.id, {'found': lyrics != null, 'data': found});
    return lyrics;
  }

  /// Limpia el título ("Canción (Video Oficial)" -> "Canción") y, si no hay
  /// artista, lo saca del nombre "Artista - Canción".
  static (String, String) _searchTerms(Track track) {
    var artist = track.artist;
    var title = track.title;
    if (artist.isEmpty && title.contains(' - ')) {
      final i = title.indexOf(' - ');
      artist = title.substring(0, i).trim();
      title = title.substring(i + 3).trim();
    }
    title = title
        .replaceAll(RegExp(r'\s*[\(\[][^\)\]]*(official|oficial|video|audio|lyric|letra|hd|4k|remaster)[^\)\]]*[\)\]]',
            caseSensitive: false), '')
        .trim();
    return (artist, title);
  }

  Future<Map<String, dynamic>?> _get(Map<String, String> query) async {
    try {
      final response = await http
          .get(Uri.parse('$_base/get').replace(queryParameters: query), headers: _headers)
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) {
        if (response.statusCode != 404) _failed = true;
        return null;
      }
      return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    } catch (e) {
      _failed = true;
      debugPrint('LRCLIB get: $e');
      return null;
    }
  }

  /// Búsqueda más flexible; elige el resultado de duración más parecida.
  Future<Map<String, dynamic>?> _search(String artist, String title, Duration duration) async {
    try {
      final query = artist.isEmpty ? {'q': title} : {'track_name': title, 'artist_name': artist};
      final response = await http
          .get(Uri.parse('$_base/search').replace(queryParameters: query), headers: _headers)
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) {
        _failed = true;
        return null;
      }
      final results = (jsonDecode(utf8.decode(response.bodyBytes)) as List).whereType<Map<String, dynamic>>().toList();
      if (results.isEmpty) return null;
      if (duration > Duration.zero) {
        double diff(Map<String, dynamic> r) => ((r['duration'] as num?)?.toDouble() ?? 0) - duration.inSeconds;
        results.sort((a, b) => diff(a).abs().compareTo(diff(b).abs()));
        // Más de 10 segundos de diferencia: probablemente es otra canción.
        if (diff(results.first).abs() > 10) return null;
      }
      return results.first;
    } catch (e) {
      _failed = true;
      debugPrint('LRCLIB search: $e');
      return null;
    }
  }

  Future<File> _file(int id) async {
    final dir = Directory('${(await getApplicationSupportDirectory()).path}/letras');
    await dir.create(recursive: true);
    return File('${dir.path}/$id.json');
  }

  Future<Map<String, dynamic>?> _readCache(int id) async {
    try {
      final file = await _file(id);
      if (!await file.exists()) return null;
      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      // Si no se encontró, se vuelve a intentar después de una semana.
      final savedAt = DateTime.fromMillisecondsSinceEpoch((json['savedAt'] as num?)?.toInt() ?? 0);
      if (json['found'] != true && DateTime.now().difference(savedAt) > const Duration(days: 7)) return null;
      return json;
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeCache(int id, Map<String, dynamic> json) async {
    try {
      final file = await _file(id);
      await file.writeAsString(jsonEncode({...json, 'savedAt': DateTime.now().millisecondsSinceEpoch}));
    } catch (_) {}
  }

  /// Borra la letra guardada para buscarla otra vez.
  Future<void> forget(int trackId) async {
    _memory.remove(trackId);
    try {
      await (await _file(trackId)).delete();
    } catch (_) {}
  }
}
