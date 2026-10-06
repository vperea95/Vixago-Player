import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Textos de la app en español e inglés. Se elige según el idioma del sistema
/// (o el que el usuario escoja en el menú): español si el celular está en
/// español, inglés en cualquier otro idioma.
///
/// En pantallas: `S.of(context).texto`. En servicios sin contexto: `S.current.texto`.
/// Regla: no escribir textos fijos en las pantallas; agregarlos aquí en los dos idiomas.
class S {
  const S._(this.languageCode);

  final String languageCode;

  /// El primero es el idioma de respaldo cuando el sistema está en otro idioma.
  static const supportedLocales = [Locale('en'), Locale('es')];

  static S current = const S._('es');

  static S of(BuildContext context) => Localizations.of<S>(context, S) ?? current;

  static S forLocale(Locale locale) => S._(locale.languageCode == 'es' ? 'es' : 'en');

  static const LocalizationsDelegate<S> delegate = _SDelegate();

  bool get isSpanish => languageCode == 'es';
  String _t(String es, String en) => isSpanish ? es : en;

  // ---------- Marca ----------
  String get tagline => _t('Música y video', 'Music & Video');
  String get byVixago => _t('por Vixago', 'by Vixago');
  String get legalese => '© 2026 Vixago';
  String get aboutText => _t(
        'Reproductor de música y video.\n\nDesarrollada por Vixago.',
        'Music and video player.\n\nDeveloped by Vixago.',
      );

  // ---------- Inicio ----------
  String get comingSoon => _t('Muy pronto', 'Coming soon');
  String get comingSoonHint => _t(
        'Aquí vas a poder escuchar tu música y ver tus videos.',
        'Here you will be able to listen to your music and watch your videos.',
      );

  // ---------- Ajustes ----------
  String get settings => _t('Ajustes', 'Settings');
  String get appearance => _t('Apariencia', 'Appearance');
  String get themeSystem => _t('Predeterminado del sistema', 'System default');
  String get themeLight => _t('Claro', 'Light');
  String get themeDark => _t('Oscuro', 'Dark');
  String get language => _t('Idioma', 'Language');
  String get languageSystem => _t('Automático (del sistema)', 'Automatic (system)');
  String get about => _t('Acerca de', 'About');
}

class _SDelegate extends LocalizationsDelegate<S> {
  const _SDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<S> load(Locale locale) {
    final strings = S.forLocale(locale);
    S.current = strings;
    return SynchronousFuture(strings);
  }

  @override
  bool shouldReload(_SDelegate old) => false;
}
