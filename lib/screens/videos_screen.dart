import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../models/media.dart';
import '../services/app_services.dart';
import '../utils/format.dart';
import '../widgets/artwork.dart';
import '../widgets/mini_player.dart';
import 'video_player_screen.dart';

/// Videos de las carpetas elegidas, en cuadrícula, con filtro por carpeta.
class VideosScreen extends StatefulWidget {
  const VideosScreen({super.key, required this.services});

  final AppServices services;

  @override
  State<VideosScreen> createState() => _VideosScreenState();
}

class _VideosScreenState extends State<VideosScreen> {
  /// Carpeta elegida en los chips; null = todas.
  String? _folder;

  Future<void> _play(List<VideoItem> list, int index) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => VideoPlayerScreen(services: widget.services, videos: list, index: index)),
    );
    // Al volver, se redibuja para actualizar las barras de "visto hasta aquí".
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final library = widget.services.library;
    return Scaffold(
      appBar: AppBar(title: Text(s.videos)),
      bottomNavigationBar: MiniPlayer(services: widget.services),
      body: ListenableBuilder(
        listenable: library,
        builder: (context, _) {
          final byFolder = library.videoFoldersContent;
          if (_folder != null && !byFolder.containsKey(_folder)) _folder = null;
          final list = _folder == null ? library.videos : byFolder[_folder]!;
          if (library.videos.isEmpty) {
            return Center(
              child: Padding(padding: const EdgeInsets.all(32), child: Text(s.noVideos, textAlign: TextAlign.center)),
            );
          }
          return Column(
            children: [
              if (byFolder.length > 1)
                SizedBox(
                  height: 52,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(s.all),
                          selected: _folder == null,
                          onSelected: (_) => setState(() => _folder = null),
                        ),
                      ),
                      for (final path in byFolder.keys)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(MediaFolder(path: path, count: 0).name),
                            selected: _folder == path,
                            onSelected: (_) => setState(() => _folder = path),
                          ),
                        ),
                    ],
                  ),
                ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 260,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.05,
                  ),
                  itemCount: list.length,
                  itemBuilder: (context, i) => _VideoCard(
                    services: widget.services,
                    video: list[i],
                    onTap: () => _play(list, i),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _VideoCard extends StatelessWidget {
  const _VideoCard({required this.services, required this.video, required this.onTap});

  final AppServices services;
  final VideoItem video;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final saved = services.videoProgress.positionOf(video.id);
    final progress = saved == null || video.duration.inMilliseconds <= 0
        ? null
        : (saved.inMilliseconds / video.duration.inMilliseconds).clamp(0.0, 1.0);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 10,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Artwork(mediaStore: services.mediaStore, uri: video.uri, video: true, size: null, radius: 0, thumbSize: 360),
                  Positioned(
                    right: 6,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(6)),
                      child: Text(formatDuration(video.duration), style: const TextStyle(color: Colors.white, fontSize: 12)),
                    ),
                  ),
                  if (progress != null)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: LinearProgressIndicator(value: progress, minHeight: 3, backgroundColor: Colors.white24),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(video.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
