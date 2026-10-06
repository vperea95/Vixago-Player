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
  String _n(int n, String esOne, String esMany, String enOne, String enMany) =>
      n == 1 ? _t(esOne, enOne) : _t(esMany, enMany);

  // ---------- Generales ----------
  String get cancel => _t('Cancelar', 'Cancel');
  String get save => _t('Guardar', 'Save');
  String get delete => _t('Eliminar', 'Delete');
  String get rename => _t('Cambiar nombre', 'Rename');
  String get retry => _t('Reintentar', 'Try again');
  String get options => _t('Opciones', 'Options');
  String get close => _t('Cerrar', 'Close');
  String get back => _t('Atrás', 'Back');
  String get next => _t('Siguiente', 'Next');
  String get finish => _t('Listo', 'Done');
  String get search => _t('Buscar', 'Search');
  String get all => _t('Todos', 'All');
  String get selectAll => _t('Todas', 'All');
  String get selectNone => _t('Ninguna', 'None');

  // ---------- Marca ----------
  String get byVixago => _t('por Vixago', 'by Vixago');
  String get legalese => '© 2026 Vixago';
  String get aboutText => _t(
        'Reproductor de música y video.\n\nDesarrollada por Vixago.',
        'Music and video player.\n\nDeveloped by Vixago.',
      );

  // ---------- Bienvenida y carpetas ----------
  String get welcomeTitle => _t('Bienvenido a Vixago Player', 'Welcome to Vixago Player');
  String get welcomeBody => _t(
        'Para mostrar tu música y tus videos, la app necesita permiso para leerlos. '
            'Después eliges de qué carpetas tomarlos: nada más se mostrará.',
        'To show your music and videos, the app needs permission to read them. '
            'Then you choose which folders to use: nothing else will be shown.',
      );
  String get allowAccess => _t('Permitir acceso', 'Allow access');
  String get openSettings => _t('Abrir ajustes del celular', 'Open phone settings');
  String get chooseMusicFolders => _t('¿De dónde tomo la música?', 'Where should I get music from?');
  String get chooseMusicFoldersHint => _t(
        'Marca solo las carpetas con tu música. Las que no marques no aparecerán (por ejemplo, los audios de WhatsApp).',
        "Check only the folders with your music. Unchecked folders won't appear (for example, WhatsApp audio).",
      );
  String get chooseVideoFolders => _t('¿De dónde tomo los videos?', 'Where should I get videos from?');
  String get chooseVideoFoldersHint => _t(
        'Marca solo las carpetas con los videos que quieres ver. Puedes cambiarlo cuando quieras desde el menú.',
        'Check only the folders with the videos you want to watch. You can change it anytime from the menu.',
      );
  String foldersSelected(int selected, int total) =>
      _t('$selected de $total carpetas elegidas', '$selected of $total folders selected');
  String get messagingFolder => _t('Carpeta de una app de mensajes', 'Messaging app folder');
  String get noMusicFoldersFound =>
      _t('No se encontraron carpetas con música en el celular.', 'No folders with music were found on the phone.');
  String get noVideoFoldersFound =>
      _t('No se encontraron carpetas con videos en el celular.', 'No folders with videos were found on the phone.');
  String get folders => _t('Carpetas', 'Folders');
  String get rescan => _t('Buscar archivos nuevos', 'Look for new files');
  String get chooseFolders => _t('Toca para elegir carpetas', 'Tap to choose folders');

  // ---------- Inicio y menú ----------
  String get homeGreeting => _t('¿Qué quieres disfrutar hoy?', 'What do you want to enjoy today?');
  String get music => _t('Música', 'Music');
  String get videos => _t('Videos', 'Videos');
  String songCount(int n) => _n(n, '1 canción', '$n canciones', '1 song', '$n songs');
  String videoCount(int n) => _n(n, '1 video', '$n videos', '1 video', '$n videos');
  String get library => _t('Biblioteca', 'Library');
  String get musicFolders => _t('Carpetas de música', 'Music folders');
  String get musicFoldersHint => _t('Elige de dónde se toma la música', 'Choose where music comes from');
  String get videoFolders => _t('Carpetas de videos', 'Video folders');
  String get videoFoldersHint => _t('Elige de dónde se toman los videos', 'Choose where videos come from');
  String get settings => _t('Ajustes', 'Settings');
  String get appearance => _t('Apariencia', 'Appearance');
  String get themeSystem => _t('Predeterminado del sistema', 'System default');
  String get themeLight => _t('Claro', 'Light');
  String get themeDark => _t('Oscuro', 'Dark');
  String get language => _t('Idioma', 'Language');
  String get languageSystem => _t('Automático (del sistema)', 'Automatic (system)');
  String get about => _t('Acerca de', 'About');

  // ---------- Música ----------
  String get songs => _t('Canciones', 'Songs');
  String get artists => _t('Artistas', 'Artists');
  String get albums => _t('Álbumes', 'Albums');
  String get foldersTab => _t('Carpetas', 'Folders');
  String get playlists => _t('Listas', 'Playlists');
  String get favorites => _t('Favoritas', 'Favorites');
  String get unknownArtist => _t('Artista desconocido', 'Unknown artist');
  String get unknownAlbum => _t('Álbum desconocido', 'Unknown album');
  String get noSongs => _t(
        'No hay canciones en las carpetas elegidas. Puedes cambiar las carpetas desde el menú.',
        'There are no songs in the chosen folders. You can change the folders from the menu.',
      );
  String get searchHint => _t('Canción, artista o álbum', 'Song, artist or album');
  String get noResults => _t('Sin resultados', 'No results');
  String get shuffle => _t('Aleatorio', 'Shuffle');
  String get play => _t('Reproducir', 'Play');
  String get pause => _t('Pausar', 'Pause');
  String get previous => _t('Anterior', 'Previous');
  String get repeatOff => _t('Repetir: no', 'Repeat: off');
  String get repeatAll => _t('Repetir: todas', 'Repeat: all');
  String get repeatOne => _t('Repetir: una', 'Repeat: one');
  String get nowPlaying => _t('Sonando ahora', 'Now playing');
  String get nothingPlaying => _t('No hay nada sonando.', 'Nothing is playing.');
  String get queue => _t('Cola', 'Queue');
  String get addShort => _t('Agregar', 'Add');
  String get addToQueue => _t('Agregar a la cola', 'Add to queue');
  String get addedToQueue => _t('Agregada a la cola', 'Added to queue');
  String get addFavorite => _t('Agregar a favoritas', 'Add to favorites');
  String get removeFavorite => _t('Quitar de favoritas', 'Remove from favorites');
  String get addToPlaylist => _t('Agregar a una lista', 'Add to playlist');
  String addedToPlaylist(String name) => _t('Agregada a "$name"', 'Added to "$name"');
  String get removeFromPlaylist => _t('Quitar de esta lista', 'Remove from this playlist');
  String get newPlaylist => _t('Nueva lista', 'New playlist');
  String get playlistName => _t('Nombre de la lista', 'Playlist name');
  String get deletePlaylist => _t('Eliminar lista', 'Delete playlist');
  String deletePlaylistQuestion(String name) =>
      _t('¿Eliminar la lista "$name"? Las canciones no se borran.', 'Delete the playlist "$name"? The songs are not deleted.');
  String get emptyPlaylist => _t(
        'Esta lista está vacía. Agrega canciones desde el menú ⋮ de cada canción.',
        'This playlist is empty. Add songs from the ⋮ menu of each song.',
      );

  // ---------- Letras ----------
  String get lyrics => _t('Letra', 'Lyrics');
  String get searchingLyrics => _t('Buscando la letra…', 'Looking for lyrics…');
  String get lyricsNotFound => _t(
        'No se encontró la letra de esta canción. Se necesita internet y que el título y el artista estén bien escritos.',
        "Lyrics for this song weren't found. Internet is needed, and the title and artist must be spelled correctly.",
      );
  String get instrumental => _t('Esta canción es instrumental.', 'This song is instrumental.');

  // ---------- Ecualizador ----------
  String get equalizer => _t('Ecualizador', 'Equalizer');
  String get equalizerOn => _t('Activar ecualizador', 'Enable equalizer');
  String get equalizerHint => _t('Se aplica a toda la música', 'Applies to all music');
  String get equalizerNeedsMusic => _t(
        'Reproduce una canción para ajustar las bandas del ecualizador.',
        'Play a song to adjust the equalizer bands.',
      );
  String get eqNormal => _t('Normal', 'Normal');
  String get eqBass => _t('Más graves', 'Bass boost');
  String get eqClassical => _t('Clásica', 'Classical');
  String get eqElectronic => _t('Electrónica', 'Electronic');
  String get eqVocal => _t('Voces', 'Vocal');
  String get eqCustom => _t('Personalizado', 'Custom');

  // ---------- Videos ----------
  String get noVideos => _t(
        'No hay videos en las carpetas elegidas. Puedes cambiar las carpetas desde el menú.',
        'There are no videos in the chosen folders. You can change the folders from the menu.',
      );
  String get cannotPlayVideo =>
      _t('No se pudo reproducir este video. Puede estar dañado o en un formato no compatible.',
          "This video couldn't be played. It may be damaged or in an unsupported format.");
  String get speed => _t('Velocidad', 'Speed');
  String get normalSpeed => _t('Normal', 'Normal');
  String get rotate => _t('Girar pantalla', 'Rotate screen');
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
