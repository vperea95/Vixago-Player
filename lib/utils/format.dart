/// 75 s -> "1:15", 3725 s -> "1:02:05".
String formatDuration(Duration d) {
  final total = d.inSeconds;
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = (total % 60).toString().padLeft(2, '0');
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$s' : '$m:$s';
}

/// Duración total de varias canciones: "1 h 12 min" o "35 min".
String formatTotal(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes % 60;
  return h > 0 ? '$h h $m min' : '${d.inMinutes} min';
}
