import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../services/media_store.dart';
import '../theme.dart';

/// Carátula de una canción o miniatura de un video. Sin imagen, muestra un
/// cuadro con el degradado de la marca y un ícono.
class Artwork extends StatelessWidget {
  const Artwork({
    super.key,
    required this.mediaStore,
    required this.uri,
    this.video = false,
    this.size = 48,
    this.radius = 10,
    this.thumbSize = 200,
    this.fit = BoxFit.cover,
  });

  final MediaStoreApi mediaStore;
  final String? uri;
  final bool video;

  /// Tamaño en pantalla; null = ocupa el espacio disponible.
  final double? size;
  final double radius;

  /// Tamaño en píxeles que se pide a Android.
  final int thumbSize;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final placeholder = _Placeholder(video: video, iconSize: (size ?? 64) * 0.45);
    final child = uri == null
        ? placeholder
        : FutureBuilder<Uint8List?>(
            future: mediaStore.thumbnail(uri!, video: video, size: thumbSize),
            builder: (context, snap) {
              final bytes = snap.data;
              if (bytes == null) return placeholder;
              return Image.memory(bytes, fit: fit, gaplessPlayback: true, errorBuilder: (_, __, ___) => placeholder);
            },
          );
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: size == null ? child : SizedBox(width: size, height: size, child: child),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.video, required this.iconSize});

  final bool video;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.blue.withValues(alpha: 0.85), AppColors.violet.withValues(alpha: 0.85)],
        ),
      ),
      child: Center(
        child: Icon(video ? Icons.movie_rounded : Icons.music_note_rounded, color: Colors.white, size: iconSize),
      ),
    );
  }
}
