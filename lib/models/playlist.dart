import 'package:hive_ce/hive_ce.dart';

part 'playlist.g.dart';

@HiveType(typeId: 3)
class SongMetadata extends HiveObject {
  @HiveField(0)
  final String path;

  @HiveField(1)
  final String? title;

  @HiveField(2)
  final String? artist;

  @HiveField(3)
  final String? album;

  @HiveField(4)
  final int? durationMs;

  SongMetadata({
    required this.path,
    this.title,
    this.artist,
    this.album,
    this.durationMs,
  });
}

@HiveType(typeId: 2)
class Playlist extends HiveObject {
  @HiveField(0)
  final String name;

  @HiveField(1)
  final List<String> songPaths;

  @HiveField(2)
  int lastPlayedIndex;

  @HiveField(3)
  int lastPlayedPosition; // in milliseconds

  @HiveField(4)
  bool shuffle;

  @HiveField(5)
  int repeatMode;

  @HiveField(6)
  List<SongMetadata>? songs;

  Playlist({
    required this.name,
    required this.songPaths,
    this.lastPlayedIndex = 0,
    this.lastPlayedPosition = 0,
    this.shuffle = false,
    this.repeatMode = 0,
    this.songs,
  });
}
