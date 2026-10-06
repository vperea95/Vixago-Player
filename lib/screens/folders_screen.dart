import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../services/library_service.dart';
import '../widgets/folder_picker.dart';

/// Cambiar en cualquier momento de qué carpetas se toman la música y los videos.
/// Los cambios se guardan al instante.
class FoldersScreen extends StatelessWidget {
  const FoldersScreen({super.key, required this.library, this.initialTab = 0});

  final LibraryService library;

  /// 0 = música, 1 = videos.
  final int initialTab;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return DefaultTabController(
      length: 2,
      initialIndex: initialTab,
      child: Scaffold(
        appBar: AppBar(
          title: Text(s.folders),
          actions: [
            IconButton(
              tooltip: s.rescan,
              icon: const Icon(Icons.refresh),
              onPressed: library.scan,
            ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(icon: const Icon(Icons.music_note_rounded), text: s.music),
              Tab(icon: const Icon(Icons.movie_rounded), text: s.videos),
            ],
          ),
        ),
        body: ListenableBuilder(
          listenable: library,
          builder: (context, _) {
            if (library.scanning) return const Center(child: CircularProgressIndicator());
            return TabBarView(
              children: [
                ListView(
                  children: [
                    _hint(context, s.chooseMusicFoldersHint),
                    FolderPicker(
                      folders: library.availableMusicFolders,
                      selected: library.musicFolders,
                      onChanged: library.setMusicFolders,
                      isVideo: false,
                    ),
                  ],
                ),
                ListView(
                  children: [
                    _hint(context, s.chooseVideoFoldersHint),
                    FolderPicker(
                      folders: library.availableVideoFolders,
                      selected: library.videoFolders,
                      onChanged: library.setVideoFolders,
                      isVideo: true,
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _hint(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
      );
}
