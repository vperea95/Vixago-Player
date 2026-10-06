import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/media.dart';

/// Acceso a la música y los videos del celular (MediaStore de Android).
/// El código nativo está en plataforma/android/MainActivity.kt.
class MediaStoreApi {
  static const _channel = MethodChannel('vixago/media');

  static bool get isSupported => !kIsWeb && Platform.isAndroid;

  /// Carátulas y miniaturas ya cargadas (null = no tiene).
  final Map<String, Future<Uint8List?>> _thumbs = {};

  Future<bool> hasPermission() async => await _invoke<bool>('hasPermission') ?? false;
  Future<bool> requestPermission() async => await _invoke<bool>('requestPermission') ?? false;
  Future<bool> openAppSettings() async => await _invoke<bool>('openAppSettings') ?? false;

  /// Evita que la pantalla se apague (mientras se ve un video).
  Future<void> keepScreenOn(bool on) => _invoke<void>('keepScreenOn', {'on': on});

  Future<List<Track>> audio() async {
    final list = await _invoke<List<dynamic>>('audio') ?? const [];
    return list.whereType<Map>().map(Track.fromMap).toList();
  }

  Future<List<VideoItem>> videos() async {
    final list = await _invoke<List<dynamic>>('videos') ?? const [];
    return list.whereType<Map>().map(VideoItem.fromMap).toList();
  }

  /// Carátula de una canción o miniatura de un video, en JPEG.
  Future<Uint8List?> thumbnail(String uri, {bool video = false, int size = 300}) {
    final key = '$uri|$size';
    // Pocas en memoria: si se llena, se vacía y se vuelve a cargar lo visible.
    if (_thumbs.length > 400 && !_thumbs.containsKey(key)) _thumbs.clear();
    return _thumbs.putIfAbsent(
      key,
      () => _invoke<Uint8List>('thumbnail', {'uri': uri, 'video': video, 'size': size}),
    );
  }

  Future<T?> _invoke<T>(String method, [Map<String, dynamic>? args]) async {
    if (!isSupported) return null;
    try {
      return await _channel.invokeMethod<T>(method, args);
    } catch (e) {
      debugPrint('MediaStoreApi.$method: $e');
      return null;
    }
  }
}
