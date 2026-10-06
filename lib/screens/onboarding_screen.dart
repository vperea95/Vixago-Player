import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../services/app_services.dart';
import '../theme.dart';
import '../widgets/folder_picker.dart';
import 'home_screen.dart';

/// Primera vez: permiso para leer la música y los videos, y elegir de qué
/// carpetas se toman. Todo se puede cambiar después desde el menú.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.services});

  final AppServices services;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  // 0 = bienvenida y permiso, 1 = carpetas de música, 2 = carpetas de video.
  int _step = 0;
  bool _asking = false;
  late Set<String> _music = widget.services.library.musicFolders.toSet();
  late Set<String> _videos = widget.services.library.videoFolders.toSet();

  @override
  void initState() {
    super.initState();
    if (widget.services.library.hasPermission) _step = 1;
  }

  Future<void> _askPermission() async {
    setState(() => _asking = true);
    final ok = await widget.services.library.requestPermission();
    if (!mounted) return;
    setState(() {
      _asking = false;
      if (ok) _step = 1;
    });
  }

  Future<void> _finish() async {
    final library = widget.services.library;
    await library.setMusicFolders(_music);
    await library.setVideoFolders(_videos);
    await library.completeSetup();
    if (!mounted) return;
    await Navigator.pushReplacement(
      context,
      MaterialPageRoute<void>(builder: (_) => HomeScreen(services: widget.services)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      body: SafeArea(
        child: switch (_step) {
          0 => _welcome(s),
          1 => _folders(
              s,
              title: s.chooseMusicFolders,
              hint: s.chooseMusicFoldersHint,
              icon: Icons.music_note_rounded,
              isVideo: false,
              selected: _music,
              onChanged: (v) => setState(() => _music = v),
              onNext: () => setState(() => _step = 2),
              onBack: null,
            ),
          _ => _folders(
              s,
              title: s.chooseVideoFolders,
              hint: s.chooseVideoFoldersHint,
              icon: Icons.movie_rounded,
              isVideo: true,
              selected: _videos,
              onChanged: (v) => setState(() => _videos = v),
              onNext: _finish,
              onBack: () => setState(() => _step = 1),
            ),
        },
      ),
    );
  }

  Widget _welcome(S s) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Spacer(),
          Image.asset('assets/icon/logo_full.png', width: 220, height: 220),
          const SizedBox(height: 16),
          Text(s.welcomeTitle, textAlign: TextAlign.center, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Text(s.welcomeBody, textAlign: TextAlign.center, style: theme.textTheme.bodyLarge),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: _asking ? null : _askPermission,
              icon: const Icon(Icons.lock_open_rounded),
              label: Text(s.allowAccess),
            ),
          ),
          if (!widget.services.library.hasPermission && !_asking)
            TextButton(
              onPressed: widget.services.mediaStore.openAppSettings,
              child: Text(s.openSettings),
            ),
        ],
      ),
    );
  }

  Widget _folders(
    S s, {
    required String title,
    required String hint,
    required IconData icon,
    required bool isVideo,
    required Set<String> selected,
    required ValueChanged<Set<String>> onChanged,
    required VoidCallback onNext,
    required VoidCallback? onBack,
  }) {
    final theme = Theme.of(context);
    final library = widget.services.library;
    final folders = isVideo ? library.availableVideoFolders : library.availableMusicFolders;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(gradient: AppColors.gradient, borderRadius: BorderRadius.circular(14)),
                child: Icon(icon, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Text(hint, style: theme.textTheme.bodyMedium),
        ),
        Expanded(
          child: SingleChildScrollView(
            child: FolderPicker(folders: folders, selected: selected, onChanged: onChanged, isVideo: isVideo),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(
            children: [
              if (onBack != null) TextButton(onPressed: onBack, child: Text(s.back)),
              const Spacer(),
              FilledButton(onPressed: onNext, child: Text(isVideo ? s.finish : s.next)),
            ],
          ),
        ),
      ],
    );
  }
}
