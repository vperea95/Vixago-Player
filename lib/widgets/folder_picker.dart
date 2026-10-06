import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../models/media.dart';

/// Lista de carpetas con casillas. Las de apps de mensajería (WhatsApp,
/// Telegram…) se marcan con un aviso para que el usuario sepa qué son.
class FolderPicker extends StatelessWidget {
  const FolderPicker({
    super.key,
    required this.folders,
    required this.selected,
    required this.onChanged,
    required this.isVideo,
  });

  final List<MediaFolder> folders;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;
  final bool isVideo;

  static final _messaging = RegExp(r'whatsapp|telegram|signal|messenger|viber|voice notes|recordings|call', caseSensitive: false);

  static bool isMessagingFolder(MediaFolder f) => _messaging.hasMatch(f.path);

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    if (folders.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Text(isVideo ? s.noVideoFoldersFound : s.noMusicFoldersFound, textAlign: TextAlign.center),
      );
    }
    final allSelected = folders.every((f) => selected.contains(f.path));
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
          child: Row(
            children: [
              Expanded(child: Text(s.foldersSelected(selected.where((p) => folders.any((f) => f.path == p)).length, folders.length))),
              TextButton(
                onPressed: () => onChanged(allSelected ? <String>{} : folders.map((f) => f.path).toSet()),
                child: Text(allSelected ? s.selectNone : s.selectAll),
              ),
            ],
          ),
        ),
        for (final folder in folders)
          CheckboxListTile(
            value: selected.contains(folder.path),
            onChanged: (checked) {
              final next = Set.of(selected);
              if (checked == true) {
                next.add(folder.path);
              } else {
                next.remove(folder.path);
              }
              onChanged(next);
            },
            secondary: Icon(
              isMessagingFolder(folder) ? Icons.chat_outlined : Icons.folder_outlined,
              color: isMessagingFolder(folder) ? theme.colorScheme.error : theme.colorScheme.primary,
            ),
            title: Text(folder.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              [
                folder.displayPath,
                isVideo ? s.videoCount(folder.count) : s.songCount(folder.count),
                if (isMessagingFolder(folder)) s.messagingFolder,
              ].join('\n'),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            isThreeLine: true,
          ),
      ],
    );
  }
}
