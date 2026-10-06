# Vixago Player — contexto del proyecto

App móvil en Flutter: reproductor de **música y video**, de la marca **Vixago** ("por Vixago"). Solo Android por ahora.

Se construye con la misma forma de trabajo que DownPlayer (`C:\Users\ANDRES\Documents\proyectos de apps\descargador de videos tiktok\DownPlayerTiktok`) y Radio Colombia. Revisar sus `CLAUDE.md` cuando haga falta reutilizar algo (descarga con yt-dlp, audio en segundo plano con audio_service, idioma, íconos).

## Cómo trabajar con el usuario

- Responder siempre en español.
- El usuario trabaja en Windows, con `cmd`, en la carpeta `C:\Users\ANDRES\Documents\proyectos de apps\Vixago Player`.
- **No tiene Flutter, Java ni Android SDK instalados localmente.** El APK se compila en GitHub Actions al hacer push a `main`. No proponer `flutter run` local.
- Pasos manuales (git, GitHub, instalar en el celular) **uno a la vez** y en lenguaje simple.
- Para publicar cambios: `git add .`, `git commit -m "mensaje"`, `git push`.
- Las advertencias `LF will be replaced by CRLF` al hacer `git add` son normales.

## Cómo se compila

El repositorio **no contiene** `android/` ni `ios/`. El workflow `.github/workflows/compilar-apk.yml`:

1. Instala Java 17 y Flutter estable.
2. `flutter create --org com.vixago --project-name vixago_player --platforms=android .` (applicationId `com.vixago.vixago_player`) y borra `test/`.
3. Copia `plataforma/android/AndroidManifest.xml` y `plataforma/android/keep.xml` (a `res/raw/`), pega `plataforma/android/MainActivity.kt` conservando la línea `package` generada (**la primera línea de ese archivo debe ser siempre `package`**) y sube `minSdk` a 24 con `sed` en `build.gradle.kts` (el `grep` siguiente hace fallar el paso si no lo encuentra).
4. `flutter pub get` (si falla, `flutter pub upgrade --major-versions`).
5. `dart run flutter_launcher_icons` y `dart run flutter_native_splash:create` (configurados al final de `pubspec.yaml`).
6. `flutter build apk --release --split-per-abi --target-platform android-arm,android-arm64` y sube ambos APK en el artifact `vixago-player-apk`. **El que sirve para casi todos los celulares es `app-arm64-v8a-release.apk`.**

El APK se firma con la llave debug de cada compilación: hay que desinstalar la versión anterior antes de instalar una nueva.

## Stack

- Flutter (SDK `^3.6.0`, Material 3).
- `just_audio` **0.10.x** (API nueva de listas: `setAudioSources`, `addAudioSources`; `ConcatenatingAudioSource` está obsoleto) + `audio_service` 0.18 + `audio_session` 0.2: música en segundo plano, notificación y pantalla de bloqueo.
- **No usar `just_audio_background`** (lección de Radio Colombia: se traga errores y saca el servicio del primer plano).
- `video_player`: videos con `VideoPlayerController.contentUri`.
- `http`: letras desde LRCLIB. `path_provider`: caché de letras y carátulas para la notificación.
- `shared_preferences`, `flutter_localizations`. Dev: `flutter_launcher_icons`, `flutter_native_splash`.
- Estado con `ChangeNotifier` + `ListenableBuilder` (sin provider ni riverpod). Todos los servicios van juntos en `AppServices` y se pasan por constructor.

## Estructura

```
lib/
  main.dart                          MaterialApp en ListenableBuilder(preferences) (tema e idioma); home = SplashScreen
  theme.dart                         AppColors (cian #1FD8FF, azul #3D6BFF, violeta #9B5CFF, noche #05091C), AppLogo, AppTitle
  l10n/strings.dart                  Clase S: todos los textos en español e inglés (_t y _n para plurales)
  models/media.dart                  Track, VideoItem, MediaFolder (desde MediaStore)
  player/music_player.dart           MusicPlayer: AudioHandler + ChangeNotifier (cola, aleatorio, repetir, interrupciones, carátula en la notificación)
  services/app_services.dart         Contenedor de todos los servicios
  services/media_store.dart          MethodChannel 'vixago/media' (permiso, audio, videos, miniaturas, keepScreenOn)
  services/library_service.dart      Carpetas elegidas, filtrado, artistas, álbumes, carpetas
  services/collections_service.dart  Favoritas y listas de reproducción (IDs de canción en SharedPreferences)
  services/equalizer_service.dart    AndroidEqualizer de just_audio, presets interpolados al número de bandas
  services/lyrics_service.dart       LRCLIB (get y search), LRC sincronizado, caché en disco
  services/video_progress_service.dart  Dónde quedó cada video
  services/preferences_service.dart  Apariencia e idioma
  screens/splash_screen.dart         Pantalla de carga (logo, ~0,8 s) que crea los servicios e inicia AudioService
  screens/onboarding_screen.dart     Primera vez: permiso -> carpetas de música -> carpetas de video
  screens/home_screen.dart           Tarjetas Música y Videos + menú lateral (carpetas, ecualizador, apariencia, idioma, acerca de)
  screens/folders_screen.dart        Cambiar carpetas en cualquier momento (pestañas Música / Videos)
  screens/music_screen.dart          Pestañas Canciones, Artistas, Álbumes, Carpetas, Listas + búsqueda
  screens/track_list_screen.dart     Lista genérica (artista, álbum, carpeta, favoritas, lista del usuario)
  screens/now_playing_screen.dart    Reproductor completo, cola
  screens/lyrics_screen.dart         Letra sincronizada (resalta y se desplaza) o simple
  screens/equalizer_screen.dart      Encendido, presets, bandas verticales
  screens/videos_screen.dart         Cuadrícula de videos, chips por carpeta, barra de progreso visto
  screens/video_player_screen.dart   Reproductor de video (continuar, doble toque ±10 s, velocidad, girar, anterior/siguiente)
  widgets/                           artwork, mini_player, track_tile (+ menú y "agregar a lista"), folder_picker
assets/icon/                         app_icon, logo (símbolo), foreground, background, logo_full (con texto)
plataforma/android/                  AndroidManifest.xml, MainActivity.kt (AudioServiceActivity), keep.xml
```

## Decisiones

- **Nombres que chocan con Flutter.** Flutter 3.47 agregó `RepeatMode` (repeating_animation_builder.dart) y rompió la compilación; el modo repetir se llama `PlayerRepeat`. Evitar nombres genéricos que Flutter pueda agregar. Si la compilación falla, el paso "Mostrar errores" del workflow publica los errores como anotaciones (se leen sin iniciar sesión en `api.github.com/repos/vperea95/Vixago-Player/check-runs/<job>/annotations`).

- **Carpetas elegidas (pedido clave del usuario).** No se muestra todo el audio/video del celular (por ejemplo, audios de WhatsApp). `MainActivity` lee **todo** MediaStore (audio y video) con la carpeta de cada archivo (padre de `DATA`, o `RELATIVE_PATH` si no hay). `LibraryService` arma la lista de carpetas con su conteo y **solo muestra lo de las carpetas marcadas** (`music_folders` y `video_folders` en SharedPreferences). `FolderPicker` marca en rojo las carpetas de apps de mensajes (whatsapp, telegram, voice notes, recordings…). Por defecto no hay ninguna carpeta marcada. Se cambian en el menú → Carpetas de música / videos.
- **Primera vez.** `setup_done` en SharedPreferences. Si falta, o si no hay permiso, la pantalla de carga lleva a `OnboardingScreen`.
- **Permisos.** Android 13+: `READ_MEDIA_AUDIO` y `READ_MEDIA_VIDEO`; antes: `READ_EXTERNAL_STORAGE` (maxSdk 32). No se declara `READ_MEDIA_VISUAL_USER_SELECTED` (así Android 14 no ofrece "acceso parcial").
- **Pantalla de carga.** La nativa (flutter_native_splash) y luego `SplashScreen` con el mismo fondo #05091C y el logo con una animación de 550 ms. Espera como mínimo 800 ms y lo que tarde en leer la biblioteca (al usuario no le gusta esperar: no subir ese mínimo).
- **Segundo plano.** `MainActivity` hereda de `AudioServiceActivity`; el manifest declara el servicio y el receiver de audio_service, `FOREGROUND_SERVICE_MEDIA_PLAYBACK` y `WAKE_LOCK`. El workflow copia `keep.xml` a `res/raw` para que R8 no borre los íconos `audio_service_*` (sin ellos la música se corta en Android 13+). Interrupciones manejadas a mano (`handleInterruptions: false`): en una llamada se pausa pero a audio_service se le informa `playing: true` (buffering), como en Radio Colombia; desconectar audífonos pausa.
- **Carátulas.** `thumbnail` en Kotlin: `loadThumbnail` (Android 10+), o la imagen incrustada con `MediaMetadataRetriever` (audio) / `MediaStore.Video.Thumbnails` (video) antes. `MediaStoreApi` las guarda en memoria (máx. 400). Para la notificación se escriben en `caratulas/` de la caché y se pasan como `file://`.
- **Ecualizador.** `AndroidEqualizer` dentro del `AudioPipeline` del reproductor. Sus parámetros solo existen después de cargar música (`attach()` tras `playTracks`). Presets en dB para 5 bandas, interpolados si el celular tiene otra cantidad. Mover una banda pasa a "Personalizado". Se guarda encendido, preset y ganancias.
- **Letras.** LRCLIB (`/api/get` con artista, título, álbum y duración; si no, `/api/search` eligiendo la duración más parecida, máx. 10 s de diferencia). Limpia "(Official Video)" y similares; sin artista, prueba "Artista - Título". Caché en `letras/<id>.json`; un "no encontrada" se reintenta a los 7 días; los errores de red no se guardan.
- **Videos.** Al abrir se pausa la música, `keepScreenOn(true)` (FLAG_KEEP_SCREEN_ON; video_player no lo hace solo) y modo inmersivo. Orientación automática según el video. Guarda la posición (se olvida si está en los primeros 5 s o a menos de 10 s del final).
- **Idioma, apariencia y firma.** Igual que DownPlayer: `[en, es]` con inglés de respaldo, selector en el menú; `ThemeMode.system` por defecto; "por Vixago" y "© 2026 Vixago".

## Estado actual

- v0.1.0: base del proyecto (ícono, arranque, idioma, apariencia, pantalla provisional). Compilada con éxito en Actions al primer intento (06/10/2026). Repositorio: https://github.com/vperea95/Vixago-Player (rama `main`). Esperando que el usuario defina las funciones del reproductor.
- v0.2.0: pantalla de carga, configuración inicial con carpetas, música (artistas, álbumes, carpetas, listas, favoritas, búsqueda, cola, aleatorio, repetir), segundo plano, ecualizador, letras y videos. Escrita completa, **sin compilar todavía**.

## Pendientes e ideas

- Llave de firma fija a nombre de Vixago (keystore en GitHub Secrets) para actualizar sin desinstalar.
- Temporizador para apagar la música, widget en la pantalla de inicio, compartir canciones, ordenar listas.
