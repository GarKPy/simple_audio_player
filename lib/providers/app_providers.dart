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

  late Box<Playlist> _box;

  Future<void> _init() async {
    _box = await Hive.openBox<Playlist>('playlists');
    state = _box.values.toList();
  }

  Future<void> createPlaylist(String name) async {
    final playlist = Playlist(name: name, songPaths: []);
    await _box.add(playlist);
    state = _box.values.toList();
  }

  Future<void> updatePlaylist(int index, Playlist playlist) async {
    await _box.putAt(index, playlist);
    state = _box.values.toList();
  }

  Future<void> deletePlaylist(int index) async {
    await _box.deleteAt(index);
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
