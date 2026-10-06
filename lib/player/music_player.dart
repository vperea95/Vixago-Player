import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import '../l10n/strings.dart';
import '../models/media.dart';
import '../services/equalizer_service.dart';
import '../services/media_store.dart';

enum PlayerRepeat { off, all, one }

/// Reproductor de música: cola, aleatorio, repetir y ecualizador. Es a la vez el
/// AudioHandler de audio_service (notificación, pantalla de bloqueo, audífonos)
/// y el ChangeNotifier de la interfaz.
///
/// Lección de Radio Colombia: durante una llamada se pausa el audio pero a
/// audio_service se le sigue informando `playing: true`. Si se le informara una
/// pausa, el servicio saldría del primer plano y Android (12+) no lo deja volver
/// desde segundo plano al colgar.
class MusicPlayer extends BaseAudioHandler with ChangeNotifier {
  MusicPlayer({required this.equalizer, required this.mediaStore}) {
    _player = AudioPlayer(
      handleInterruptions: false,
      audioPipeline: AudioPipeline(androidAudioEffects: [equalizer.effect]),
    );
    _subs.addAll([
      _player.playbackEventStream.listen((_) => _broadcast()),
      _player.playingStream.listen((_) => _changed()),
      _player.currentIndexStream.listen(_onIndex),
      _player.shuffleModeEnabledStream.listen((_) => _changed()),
      _player.loopModeStream.listen((_) => _changed()),
      _player.processingStateStream.listen(_onProcessingState),
      _player.errorStream.listen(_onError),
    ]);
    unawaited(_initAudioSession());
  }

  final EqualizerService equalizer;
  final MediaStoreApi mediaStore;
  late final AudioPlayer _player;
  final List<StreamSubscription<dynamic>> _subs = [];

  /// Canciones en el orden original (el aleatorio lo maneja just_audio).
  List<Track> _tracks = const [];
  bool _interrupted = false;

  List<Track> get tracks => List.unmodifiable(_tracks);
  Track? get current {
    final i = _player.currentIndex;
    return i != null && i >= 0 && i < _tracks.length ? _tracks[i] : null;
  }

  bool get isPlaying => _player.playing;
  bool get shuffle => _player.shuffleModeEnabled;
  PlayerRepeat get repeat => switch (_player.loopMode) {
        LoopMode.off => PlayerRepeat.off,
        LoopMode.all => PlayerRepeat.all,
        LoopMode.one => PlayerRepeat.one,
      };
  Duration get position => _player.position;
  Duration? get duration => _player.duration;
  Stream<Duration> get positionStream => _player.positionStream;

  /// Cola en el orden en que va a sonar (respeta el aleatorio).
  List<Track> get upNext {
    final indices = _player.shuffleModeEnabled ? _player.shuffleIndices : List.generate(_tracks.length, (i) => i);
    return [for (final i in indices) if (i < _tracks.length) _tracks[i]];
  }

  /// Reproduce [list] desde [index]. Con [shuffle], en orden aleatorio.
  Future<void> playTracks(List<Track> list, {int index = 0, bool shuffle = false}) async {
    if (list.isEmpty) return;
    _tracks = List.of(list);
    queue.add(_tracks.map(_mediaItemFor).toList());
    final start = shuffle && index == 0 ? DateTime.now().millisecondsSinceEpoch % list.length : index;
    await _player.setShuffleModeEnabled(shuffle);
    await _player.setAudioSources(
      [for (final t in _tracks) AudioSource.uri(Uri.parse(t.uri), tag: t)],
      initialIndex: start,
      initialPosition: Duration.zero,
    );
    if (shuffle) await _player.shuffle();
    await play();
    unawaited(equalizer.attach());
  }

  /// Agrega canciones al final de la cola (o empieza a sonar si no hay nada).
  Future<void> addToQueue(List<Track> list) async {
    if (_tracks.isEmpty) return playTracks(list);
    _tracks = [..._tracks, ...list];
    queue.add(_tracks.map(_mediaItemFor).toList());
    await _player.addAudioSources([for (final t in list) AudioSource.uri(Uri.parse(t.uri), tag: t)]);
    _changed();
  }

  Future<void> toggleShuffle() async {
    final value = !_player.shuffleModeEnabled;
    if (value) await _player.shuffle();
    await _player.setShuffleModeEnabled(value);
  }

  Future<void> cycleRepeat() async {
    await _player.setLoopMode(switch (_player.loopMode) {
      LoopMode.off => LoopMode.all,
      LoopMode.all => LoopMode.one,
      LoopMode.one => LoopMode.off,
    });
  }

  // ---------- AudioHandler (notificación, pantalla de bloqueo, audífonos) ----------

  @override
  Future<void> play() async {
    if (_tracks.isEmpty) return;
    _interrupted = false;
    await (await AudioSession.instance).setActive(true);
    // play() de just_audio termina cuando se pausa: no se espera.
    unawaited(_player.play());
    _broadcast();
  }

  @override
  Future<void> pause() async {
    _interrupted = false;
    await _player.pause();
    _broadcast();
  }

  Future<void> togglePlay() => _player.playing ? pause() : play();

  @override
  Future<void> stop() async {
    _interrupted = false;
    await _player.stop();
    playbackState.add(PlaybackState());
    await super.stop();
    _changed();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() async {
    if (_player.hasNext) {
      await _player.seekToNext();
    } else if (_tracks.isNotEmpty) {
      // Al final de la cola vuelve a la primera.
      await _player.seek(Duration.zero, index: _player.effectiveIndices.firstOrNull ?? 0);
    }
  }

  @override
  Future<void> skipToPrevious() async {
    // Como en casi todos los reproductores: si ya pasaron 3 s, vuelve al inicio.
    if (_player.position > const Duration(seconds: 3) || !_player.hasPrevious) {
      await _player.seek(Duration.zero);
    } else {
      await _player.seekToPrevious();
    }
  }

  @override
  Future<void> skipToQueueItem(int index) => _player.seek(Duration.zero, index: index);

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    final value = shuffleMode != AudioServiceShuffleMode.none;
    if (value) await _player.shuffle();
    await _player.setShuffleModeEnabled(value);
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) => _player.setLoopMode(switch (repeatMode) {
        AudioServiceRepeatMode.none => LoopMode.off,
        AudioServiceRepeatMode.one => LoopMode.one,
        AudioServiceRepeatMode.all || AudioServiceRepeatMode.group => LoopMode.all,
      });

  // ---------- Eventos ----------

  void _onIndex(int? index) {
    final track = current;
    if (track == null) return;
    final item = _mediaItemFor(track);
    mediaItem.add(item);
    _changed();
    unawaited(_loadArtwork(track, item));
  }

  /// La notificación necesita la carátula como archivo: se guarda en la caché.
  Future<void> _loadArtwork(Track track, MediaItem item) async {
    try {
      final bytes = await mediaStore.thumbnail(track.uri, size: 512);
      if (bytes == null) return;
      final dir = Directory('${(await getTemporaryDirectory()).path}/caratulas');
      await dir.create(recursive: true);
      final file = File('${dir.path}/${track.albumId}_${track.id}.jpg');
      if (!await file.exists()) await file.writeAsBytes(bytes);
      if (current?.id == track.id) mediaItem.add(item.copyWith(artUri: Uri.file(file.path)));
    } catch (e) {
      debugPrint('Carátula: $e');
    }
  }

  void _onProcessingState(ProcessingState state) {
    // Terminó la cola sin repetir: vuelve al inicio, en pausa.
    if (state == ProcessingState.completed) {
      unawaited(() async {
        await _player.pause();
        await _player.seek(Duration.zero, index: _player.effectiveIndices.firstOrNull ?? 0);
      }());
    }
    _changed();
  }

  /// Un archivo dañado o borrado: se salta al siguiente.
  void _onError(PlayerException e) {
    debugPrint('Error de reproducción: ${e.message}');
    if (_player.hasNext) unawaited(_player.seekToNext());
  }

  Future<void> _initAudioSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
      session.interruptionEventStream.listen(_onInterruption);
      // Se desconectaron los audífonos: pausa, como cualquier reproductor.
      session.becomingNoisyEventStream.listen((_) => pause());
    } catch (e) {
      debugPrint('AudioSession: $e');
    }
  }

  void _onInterruption(AudioInterruptionEvent event) {
    if (event.begin) {
      switch (event.type) {
        case AudioInterruptionType.duck:
          _player.setVolume(0.3);
        case AudioInterruptionType.pause:
        case AudioInterruptionType.unknown:
          if (_player.playing) {
            _interrupted = true;
            _player.pause();
          }
      }
    } else {
      switch (event.type) {
        case AudioInterruptionType.duck:
          _player.setVolume(1);
        case AudioInterruptionType.pause:
          if (_interrupted) play();
        case AudioInterruptionType.unknown:
          // Otra app de música tomó el audio: queda en pausa normal.
          if (_interrupted) {
            _interrupted = false;
            _broadcast();
          }
      }
    }
  }

  void _changed() {
    _broadcast();
    notifyListeners();
  }

  void _broadcast() {
    final playing = _player.playing || _interrupted;
    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: const {MediaAction.seek, MediaAction.seekForward, MediaAction.seekBackward},
      androidCompactActionIndices: const [0, 1, 2],
      processingState: switch (_player.processingState) {
        ProcessingState.idle => AudioProcessingState.idle,
        ProcessingState.loading => AudioProcessingState.loading,
        ProcessingState.buffering => AudioProcessingState.buffering,
        ProcessingState.ready => _interrupted ? AudioProcessingState.buffering : AudioProcessingState.ready,
        ProcessingState.completed => AudioProcessingState.completed,
      },
      playing: playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: _player.currentIndex,
      shuffleMode: _player.shuffleModeEnabled ? AudioServiceShuffleMode.all : AudioServiceShuffleMode.none,
      repeatMode: switch (_player.loopMode) {
        LoopMode.off => AudioServiceRepeatMode.none,
        LoopMode.one => AudioServiceRepeatMode.one,
        LoopMode.all => AudioServiceRepeatMode.all,
      },
    ));
  }

  MediaItem _mediaItemFor(Track t) => MediaItem(
        id: t.uri,
        title: t.title,
        artist: t.artist.isEmpty ? S.current.unknownArtist : t.artist,
        album: t.album,
        duration: t.duration > Duration.zero ? t.duration : null,
      );

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _player.dispose();
    super.dispose();
  }
}
