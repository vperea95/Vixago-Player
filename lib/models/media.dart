/// Una canción del celular (MediaStore).
class Track {
  const Track({
    required this.id,
    required this.uri,
    required this.title,
    required this.artist,
    required this.album,
    required this.albumId,
    required this.duration,
    required this.folder,
    required this.fileName,
    required this.dateAdded,
    required this.trackNumber,
  });

  final int id;

  /// content:// del archivo.
  final String uri;
  final String title;

  /// Vacío si el archivo no lo dice (MediaStore pone "<unknown>").
  final String artist;
  final String album;
  final int albumId;
  final Duration duration;

  /// Carpeta donde está el archivo (ruta completa).
  final String folder;
  final String fileName;
  final DateTime dateAdded;
  final int trackNumber;

  factory Track.fromMap(Map<dynamic, dynamic> m) {
    final fileName = '${m['fileName'] ?? ''}';
    var title = _clean(m['title']);
    if (title.isEmpty) title = _withoutExtension(fileName);
    return Track(
      id: (m['id'] as num).toInt(),
      uri: '${m['uri']}',
      title: title,
      artist: _clean(m['artist']),
      album: _clean(m['album']),
      albumId: (m['albumId'] as num?)?.toInt() ?? 0,
      duration: Duration(milliseconds: (m['duration'] as num?)?.toInt() ?? 0),
      folder: '${m['folder'] ?? ''}',
      fileName: fileName,
      dateAdded: DateTime.fromMillisecondsSinceEpoch(((m['dateAdded'] as num?)?.toInt() ?? 0) * 1000),
      // MediaStore guarda el disco y la pista juntos (1003 = disco 1, pista 3).
      trackNumber: ((m['track'] as num?)?.toInt() ?? 0) % 1000,
    );
  }
}

/// Un video del celular (MediaStore).
class VideoItem {
  const VideoItem({
    required this.id,
    required this.uri,
    required this.title,
    required this.duration,
    required this.width,
    required this.height,
    required this.folder,
    required this.size,
    required this.dateAdded,
  });

  final int id;
  final String uri;
  final String title;
  final Duration duration;
  final int width;
  final int height;
  final String folder;
  final int size;
  final DateTime dateAdded;

  factory VideoItem.fromMap(Map<dynamic, dynamic> m) {
    final fileName = '${m['fileName'] ?? ''}';
    var title = _clean(m['title']);
    if (title.isEmpty) title = _withoutExtension(fileName);
    return VideoItem(
      id: (m['id'] as num).toInt(),
      uri: '${m['uri']}',
      title: title,
      duration: Duration(milliseconds: (m['duration'] as num?)?.toInt() ?? 0),
      width: (m['width'] as num?)?.toInt() ?? 0,
      height: (m['height'] as num?)?.toInt() ?? 0,
      folder: '${m['folder'] ?? ''}',
      size: (m['size'] as num?)?.toInt() ?? 0,
      dateAdded: DateTime.fromMillisecondsSinceEpoch(((m['dateAdded'] as num?)?.toInt() ?? 0) * 1000),
    );
  }
}

/// Una carpeta que tiene música o videos, con cuántos archivos tiene.
class MediaFolder {
  const MediaFolder({required this.path, required this.count});

  final String path;
  final int count;

  /// Último tramo de la ruta: "/storage/emulated/0/Music/Rock" -> "Rock".
  String get name {
    final parts = path.split('/').where((p) => p.isNotEmpty).toList();
    return parts.isEmpty ? path : parts.last;
  }

  /// Ruta sin el prefijo del almacenamiento interno, para mostrarla.
  String get displayPath => path.replaceFirst(RegExp(r'^/storage/emulated/\d+/'), '');
}

String _clean(Object? value) {
  final text = '${value ?? ''}'.trim();
  return text == '<unknown>' ? '' : text;
}

String _withoutExtension(String fileName) {
  final dot = fileName.lastIndexOf('.');
  return dot > 0 ? fileName.substring(0, dot) : fileName;
}
