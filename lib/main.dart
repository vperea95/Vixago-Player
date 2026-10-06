import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'l10n/strings.dart';
import 'screens/splash_screen.dart';
import 'services/preferences_service.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final preferences = PreferencesService();
  await preferences.load();

  // Idioma para los textos que se usan antes de que cargue la interfaz.
  S.current = S.forLocale(preferences.locale ?? PlatformDispatcher.instance.locale);

  runApp(VixagoPlayerApp(preferences: preferences));
}

class VixagoPlayerApp extends StatelessWidget {
  const VixagoPlayerApp({super.key, required this.preferences});

  final PreferencesService preferences;

  @override
  Widget build(BuildContext context) {
    // Apariencia e idioma siguen al sistema, salvo que el usuario elija otro en el menú.
    return ListenableBuilder(
      listenable: preferences,
      builder: (context, _) => MaterialApp(
        title: 'Vixago Player',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        themeMode: preferences.themeMode,
        locale: preferences.locale,
        supportedLocales: S.supportedLocales,
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        // La pantalla de carga prepara los servicios y luego abre el inicio.
        home: SplashScreen(preferences: preferences),
      ),
    );
  }
}
