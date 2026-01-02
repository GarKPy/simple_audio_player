import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/adapters.dart';
import '../models/playlist.dart';
export 'player_provider.dart';

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
final selectedPlaylistIndexProvider = StateProvider<int>((ref) => 0);

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
