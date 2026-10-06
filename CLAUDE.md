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
3. Copia `plataforma/android/AndroidManifest.xml`, pega `plataforma/android/MainActivity.kt` conservando la línea `package` generada (**la primera línea de ese archivo debe ser siempre `package`**) y sube `minSdk` a 24 con `sed` en `build.gradle.kts` (el `grep` siguiente hace fallar el paso si no lo encuentra).
4. `flutter pub get` (si falla, `flutter pub upgrade --major-versions`).
5. `dart run flutter_launcher_icons` y `dart run flutter_native_splash:create` (configurados al final de `pubspec.yaml`).
6. `flutter build apk --release --split-per-abi --target-platform android-arm,android-arm64` y sube ambos APK en el artifact `vixago-player-apk`. **El que sirve para casi todos los celulares es `app-arm64-v8a-release.apk`.**

El APK se firma con la llave debug de cada compilación: hay que desinstalar la versión anterior antes de instalar una nueva.

## Stack

- Flutter (SDK `^3.6.0`, Material 3).
- `flutter_localizations` (SDK) y `shared_preferences`.
- `flutter_launcher_icons` y `flutter_native_splash` (dev).
- Estado con `ChangeNotifier` + `ListenableBuilder` (sin provider ni riverpod). Dependencias por constructor desde `main.dart`.

## Estructura

```
lib/
  main.dart                          MaterialApp dentro de ListenableBuilder(preferences) para themeMode y locale
  theme.dart                         AppColors (cian #1FD8FF, azul #3D6BFF, violeta #9B5CFF, noche #05091C), AppLogo, AppTitle
  l10n/strings.dart                  Clase S con todos los textos en español e inglés (_t('es', 'en'))
  services/preferences_service.dart  Apariencia (ThemeMode, por defecto del sistema) e idioma (null = sistema)
  screens/home_screen.dart           Pantalla provisional (logo + "Muy pronto") y menú lateral con Ajustes y Acerca de
assets/icon/
  app_icon.png     Símbolo sobre fondo redondeado (512), para Android viejo
  logo.png         Igual, 256, para dentro de la app (AppLogo)
  foreground.png   Solo el símbolo (V + play + nota) con fondo transparente, ~62% del lienzo (ícono adaptable y arranque en Android 12+)
  background.png   Degradado azul noche (#16206E -> #020616)
  logo_full.png    Logo completo con "Vixago Player – Music & Video" (arranque en Android < 12 y pantalla de inicio)
plataforma/android/  AndroidManifest.xml (label "Vixago Player") y MainActivity.kt (FlutterActivity)
```

## Decisiones

- **Logo.** El original (1254 px) trae el texto "Vixago Player – Music & Video". En el ícono del celular el texto sería ilegible, así que el ícono usa solo el símbolo; el logo completo va en el arranque y en la pantalla de inicio. Los recortes se hicieron con Pillow (alfa según el brillo; el fondo azul noche queda transparente).
- **Idioma.** Igual que DownPlayer: `supportedLocales` `[en, es]` (inglés de respaldo), selector en el menú (Automático, Español, English). Regla: ningún texto fijo en pantallas, todo va a `S`.
- **Apariencia.** `themeMode` por defecto `ThemeMode.system`; selector en el menú (Predeterminado del sistema, Claro, Oscuro).
- **Firma Vixago.** "por Vixago" en el menú lateral y "© 2026 Vixago" en Acerca de.

## Estado actual

- v0.1.0: base del proyecto (ícono, arranque, idioma, apariencia, pantalla provisional). Repositorio: https://github.com/vperea95/Vixago-Player (rama `main`). Esperando que el usuario defina las funciones del reproductor.
