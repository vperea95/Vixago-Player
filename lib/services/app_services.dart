import '../player/music_player.dart';
import 'collections_service.dart';
import 'equalizer_service.dart';
import 'library_service.dart';
import 'lyrics_service.dart';
import 'media_store.dart';
import 'preferences_service.dart';
import 'video_progress_service.dart';

/// Todos los servicios de la app, para pasarlos juntos por constructor.
class AppServices {
  const AppServices({
    required this.preferences,
    required this.mediaStore,
    required this.library,
    required this.collections,
    required this.equalizer,
    required this.player,
    required this.lyrics,
    required this.videoProgress,
  });

  final PreferencesService preferences;
  final MediaStoreApi mediaStore;
  final LibraryService library;
  final CollectionsService collections;
  final EqualizerService equalizer;
  final MusicPlayer player;
  final LyricsService lyrics;
  final VideoProgressService videoProgress;
}
