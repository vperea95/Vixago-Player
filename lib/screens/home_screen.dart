import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../services/app_services.dart';
import '../theme.dart';
import '../widgets/mini_player.dart';
import 'equalizer_screen.dart';
import 'folders_screen.dart';
import 'music_screen.dart';
import 'videos_screen.dart';

/// Inicio: una tarjeta para la música y otra para los videos.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.services});

  final AppServices services;

  void _open(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute<void>(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final library = services.library;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: const Row(
          children: [
            AppLogo(size: 32),
            SizedBox(width: 10),
            AppTitle(),
          ],
        ),
      ),
      drawer: _SettingsDrawer(services: services),
      bottomNavigationBar: MiniPlayer(services: services),
      body: ListenableBuilder(
        listenable: library,
        builder: (context, _) {
          final hasMusicFolders = library.musicFolders.isNotEmpty;
          final hasVideoFolders = library.videoFolders.isNotEmpty;
          return RefreshIndicator(
            onRefresh: library.scan,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 16),
                  child: Text(
                    s.homeGreeting,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                _HomeCard(
                  icon: Icons.music_note_rounded,
                  title: s.music,
                  subtitle: hasMusicFolders ? s.songCount(library.tracks.length) : s.chooseFolders,
                  colors: const [AppColors.cyan, AppColors.blue],
                  onTap: () => hasMusicFolders
                      ? _open(context, MusicScreen(services: services))
                      : _open(context, FoldersScreen(library: library)),
                ),
                const SizedBox(height: 16),
                _HomeCard(
                  icon: Icons.movie_rounded,
                  title: s.videos,
                  subtitle: hasVideoFolders ? s.videoCount(library.videos.length) : s.chooseFolders,
                  colors: const [AppColors.blue, AppColors.violet],
                  onTap: () => hasVideoFolders
                      ? _open(context, VideosScreen(services: services))
                      : _open(context, FoldersScreen(library: library, initialTab: 1)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Tarjeta grande con degradado e ícono.
class _HomeCard extends StatelessWidget {
  const _HomeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.colors,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 2.1,
      child: Material(
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
          ),
          child: InkWell(
            onTap: onTap,
            child: Stack(
              children: [
                // Ícono grande de fondo, como marca de agua.
                Positioned(
                  right: -18,
                  bottom: -24,
                  child: Icon(icon, size: 170, color: Colors.white.withValues(alpha: 0.16)),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(icon, color: Colors.white, size: 32),
                      ),
                      const Spacer(),
                      Text(
                        title,
                        style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800),
                      ),
                      Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 15)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsDrawer extends StatelessWidget {
  const _SettingsDrawer({required this.services});

  final AppServices services;

  String _themeLabel(S s, ThemeMode mode) => switch (mode) {
        ThemeMode.system => s.themeSystem,
        ThemeMode.light => s.themeLight,
        ThemeMode.dark => s.themeDark,
      };

  String _languageLabel(S s, String? code) => switch (code) {
        'es' => 'Español',
        'en' => 'English',
        _ => s.languageSystem,
      };

  /// Diálogo con opciones; la elegida lleva un check.
  Future<T?> _pick<T>(BuildContext context, String title, List<(T, String)> options, T current) {
    return showDialog<T>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(title),
        children: [
          for (final (value, label) in options)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, value),
              child: Row(
                children: [
                  Expanded(child: Text(label)),
                  if (value == current) Icon(Icons.check, color: Theme.of(context).colorScheme.primary),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute<void>(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final preferences = services.preferences;
    return Drawer(
      child: SafeArea(
        child: ListenableBuilder(
          listenable: preferences,
          builder: (context, _) {
            final s = S.of(context);
            final muted = Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                );
            return ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                  child: Row(
                    children: [
                      const AppLogo(size: 56),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const AppTitle(),
                          Text(s.byVixago, style: muted),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(),
                _section(s.library),
                ListTile(
                  leading: const Icon(Icons.library_music_outlined),
                  title: Text(s.musicFolders),
                  subtitle: Text(s.musicFoldersHint),
                  onTap: () => _push(context, FoldersScreen(library: services.library)),
                ),
                ListTile(
                  leading: const Icon(Icons.video_library_outlined),
                  title: Text(s.videoFolders),
                  subtitle: Text(s.videoFoldersHint),
                  onTap: () => _push(context, FoldersScreen(library: services.library, initialTab: 1)),
                ),
                ListTile(
                  leading: const Icon(Icons.equalizer_rounded),
                  title: Text(s.equalizer),
                  onTap: () => _push(context, EqualizerScreen(services: services)),
                ),
                const Divider(),
                _section(s.settings),
                ListTile(
                  leading: const Icon(Icons.brightness_6_outlined),
                  title: Text(s.appearance),
                  subtitle: Text(_themeLabel(s, preferences.themeMode)),
                  onTap: () async {
                    final mode = await _pick<ThemeMode>(
                      context,
                      s.appearance,
                      [for (final m in ThemeMode.values) (m, _themeLabel(s, m))],
                      preferences.themeMode,
                    );
                    if (mode != null) await preferences.setThemeMode(mode);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.language),
                  title: Text(s.language),
                  subtitle: Text(_languageLabel(s, preferences.languageCode)),
                  onTap: () async {
                    // '' representa "automático" porque showDialog devuelve null al cerrar sin elegir.
                    final code = await _pick<String>(
                      context,
                      s.language,
                      [('', s.languageSystem), ('es', 'Español'), ('en', 'English')],
                      preferences.languageCode ?? '',
                    );
                    if (code != null) await preferences.setLanguage(code.isEmpty ? null : code);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: Text(s.about),
                  onTap: () {
                    Navigator.pop(context);
                    showAboutDialog(
                      context: context,
                      applicationName: 'Vixago Player',
                      applicationVersion: '0.2.0',
                      applicationIcon: const AppLogo(size: 56),
                      applicationLegalese: s.legalese,
                      children: [
                        const SizedBox(height: 16),
                        Text(s.aboutText),
                      ],
                    );
                  },
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                  child: Text('Vixago Player 0.2.0 · ${s.byVixago}', style: muted),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _section(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
      );
}
