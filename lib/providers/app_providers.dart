import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/adapters.dart';
import '../models/playlist.dart';

// --- Pinned Folders ---
final pinnedFoldersProvider =
    NotifierProvider<PinnedFoldersNotifier, List<String>>(
      PinnedFoldersNotifier.new,
    );

class PinnedFoldersNotifier extends Notifier<List<String>> {
  @override
  List<String> build() {
    final box = Hive.box<List<String>>('pinned_folders');
    return List<String>.from(box.get('paths', defaultValue: [])!);
  }

  void toggle(String path) {
    final box = Hive.box<List<String>>('pinned_folders');
    final list = List<String>.from(state);
    if (list.contains(path)) {
      list.remove(path);
    } else {
      list.add(path);
    }

    box.put('paths', list);
    state = list;
  }

  bool isPinned(String path) => state.contains(path);
}

// --- Playlists ---
final playlistsProvider =
    StateNotifierProvider<PlaylistsNotifier, List<Playlist>>((ref) {
      return PlaylistsNotifier();
    });

class PlaylistsNotifier extends StateNotifier<List<Playlist>> {
  PlaylistsNotifier() : super([]) {
    _init();
  }

  late final Box<Playlist> _box;

  Future<void> _init() async {
    _box = Hive.box<Playlist>('playlists');
    if (_box.isEmpty) {
      final favorites = Playlist(name: 'Favorites', songPaths: []);
      await _box.add(favorites);
    } else {
      if (!_box.values.any((p) => p.name == 'Favorites')) {
        await _box.add(Playlist(name: 'Favorites', songPaths: []));
      }
    }
    state = _box.values.toList();
  }

  Future<void> createPlaylist(String name) async {
    if (_box.values.any((p) => p.name == name)) return; // Prevent duplicates
    final playlist = Playlist(name: name, songPaths: []);
    await _box.add(playlist);
    state = _box.values.toList();
  }

  Future<void> deletePlaylist(Playlist playlist) async {
    // deleting by object matching reference or we need key
    // HiveObject has delete()
    await playlist.delete();
    // or _box.delete(key) if we knew it.
    // simpler to refresh state
    state = _box.values.toList();
  }

  // Method to add songs to a playlist
  Future<void> addSongsToPlaylist(Playlist playlist, List<String> paths) async {
    playlist.songPaths.addAll(paths);
    await playlist.save();
    state = _box.values.toList();
  }

  // Method to remove song from playlist
  Future<void> removeSongFromPlaylist(Playlist playlist, int index) async {
    playlist.songPaths.removeAt(index);
    await playlist.save();
    state = _box.values.toList();
  }

  Future<void> setLastPlayed(Playlist playlist, int index) async {
    playlist.lastPlayedIndex = index;
    await playlist.save();
    state = _box.values.toList();
  }
}

// --- Player State ---
class PlayerState {
  final String? currentSongPath;
  final bool isPlaying;
  final int position;
  final int duration;
  final String? artist;
  final String? title;

  PlayerState({
    this.currentSongPath,
    this.isPlaying = false,
    this.position = 0,
    this.duration = 0,
    this.artist,
    this.title,
  });

  PlayerState copyWith({
    String? currentSongPath,
    bool? isPlaying,
    int? position,
    int? duration,
    String? artist,
    String? title,
  }) {
    return PlayerState(
      currentSongPath: currentSongPath ?? this.currentSongPath,
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      artist: artist ?? this.artist,
      title: title ?? this.title,
    );
  }
}

final playerProvider = StateNotifierProvider<PlayerNotifier, PlayerState>((
  ref,
) {
  return PlayerNotifier();
});

class PlayerNotifier extends StateNotifier<PlayerState> {
  PlayerNotifier() : super(PlayerState());

  void play(String path, {String? artist, String? title}) {
    state = state.copyWith(
      currentSongPath: path,
      isPlaying: true,
      artist: artist,
      title: title,
    );
    // TODO: Audio playback logic
  }

  void togglePlay() {
    state = state.copyWith(isPlaying: !state.isPlaying);
  }

  void seek(int position) {
    state = state.copyWith(position: position);
  }
}
