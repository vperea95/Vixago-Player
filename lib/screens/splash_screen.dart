import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

import '../player/music_player.dart';
import '../services/app_services.dart';
import '../services/collections_service.dart';
import '../services/equalizer_service.dart';
import '../services/library_service.dart';
import '../services/lyrics_service.dart';
import '../services/media_store.dart';
import '../services/preferences_service.dart';
import '../services/video_progress_service.dart';
import '../theme.dart';
import 'home_screen.dart';
import 'onboarding_screen.dart';

/// Pantalla de carga: el logo con una animación corta mientras se preparan los
/// servicios y se lee la biblioteca. Dura lo mínimo (unos 0,8 s).
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.preferences});

  final PreferencesService preferences;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 550),
  )..forward();

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final minimum = Future<void>.delayed(const Duration(milliseconds: 800));
    final services = await _bootstrap(widget.preferences);
    await minimum;
    if (!mounted) return;
    final next = services.library.setupDone && services.library.hasPermission
        ? HomeScreen(services: services)
        : OnboardingScreen(services: services);
    await Navigator.pushReplacement(
      context,
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (_, __, ___) => next,
        transitionsBuilder: (_, animation, __, child) => FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  static Future<AppServices> _bootstrap(PreferencesService preferences) async {
    final mediaStore = MediaStoreApi();
    final library = LibraryService(mediaStore);
    final collections = CollectionsService();
    final equalizer = EqualizerService();
    final videoProgress = VideoProgressService();
    await Future.wait([library.load(), collections.load(), equalizer.load(), videoProgress.load()]);

    MusicPlayer createPlayer() => MusicPlayer(equalizer: equalizer, mediaStore: mediaStore);
    MusicPlayer player;
    try {
      // Servicio de audio: música con la pantalla apagada y controles en la notificación.
      player = await AudioService.init(
        builder: createPlayer,
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'com.vixago.player.audio',
          androidNotificationChannelName: 'Vixago Player',
          androidNotificationOngoing: true,
        ),
      );
    } catch (e) {
      // Sin el servicio la música solo suena con la app abierta, pero la app funciona.
      debugPrint('No se pudo iniciar el servicio de audio: $e');
      player = createPlayer();
    }

    return AppServices(
      preferences: preferences,
      mediaStore: mediaStore,
      library: library,
      collections: collections,
      equalizer: equalizer,
      player: player,
      lyrics: LyricsService(),
      videoProgress: videoProgress,
    );
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic);
    return Scaffold(
      // Mismo color que la pantalla de arranque de Android, para que no se note el cambio.
      backgroundColor: AppColors.night,
      body: Center(
        child: FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.9, end: 1).animate(curved),
            child: Image.asset('assets/icon/logo_full.png', width: 280, height: 280),
          ),
        ),
      ),
    );
  }
}
