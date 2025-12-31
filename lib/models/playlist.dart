import 'package:hive_ce/hive_ce.dart';
import 'repeat_mode.dart';

part 'playlist.g.dart';

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
  RepeatMode repeatMode;

  Playlist({
    required this.name,
    required this.songPaths,
    this.lastPlayedIndex = 0,
    this.lastPlayedPosition = 0,
    this.shuffle = false,
    this.repeatMode = RepeatMode.none,
  });
}
