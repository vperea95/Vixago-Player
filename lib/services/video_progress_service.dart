import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Recuerda dónde quedó cada video para continuar desde ahí.
class VideoProgressService {
  static const _key = 'video_progress';
  static const _maxEntries = 300;

  SharedPreferences? _prefs;
  final Map<String, int> _positions = {};

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    try {
      final raw = _prefs!.getString(_key);
      if (raw != null) {
        (jsonDecode(raw) as Map).forEach((k, v) {
          if (v is num) _positions['$k'] = v.toInt();
        });
      }
    } catch (_) {}
  }

  Duration? positionOf(int videoId) {
    final ms = _positions['$videoId'];
    return ms == null ? null : Duration(milliseconds: ms);
  }

  /// Guarda la posición. Si está al principio o casi al final, la olvida.
  Future<void> save(int videoId, Duration position, Duration duration) async {
    final key = '$videoId';
    final nearEnd = duration > Duration.zero && duration - position < const Duration(seconds: 10);
    if (position < const Duration(seconds: 5) || nearEnd) {
      _positions.remove(key);
    } else {
      _positions.remove(key);
      _positions[key] = position.inMilliseconds;
      while (_positions.length > _maxEntries) {
        _positions.remove(_positions.keys.first);
      }
    }
    await _prefs?.setString(_key, jsonEncode(_positions));
  }
}
