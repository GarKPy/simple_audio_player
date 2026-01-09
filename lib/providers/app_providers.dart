import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/adapters.dart';
import 'package:flutter_media_metadata/flutter_media_metadata.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:io';
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

    final settingsBox = Hive.box('settings');
    final orderedNames = List<String>.from(
      settingsBox.get('playlist_order', defaultValue: [])!,
    );

    final playlists = _box.values.toList();
    if (orderedNames.isNotEmpty) {
      playlists.sort((a, b) {
        final indexA = orderedNames.indexOf(a.name);
        final indexB = orderedNames.indexOf(b.name);
        if (indexA == -1 && indexB == -1) return 0;
        if (indexA == -1) return 1;
        if (indexB == -1) return -1;
        return indexA.compareTo(indexB);
      });
    }
    state = playlists;

    // Background refresh for songs missing metadata
    _refreshAllMetadata();
  }

  Future<void> _refreshAllMetadata() async {
    bool changed = false;
    final player = AudioPlayer();
    for (var playlist in state) {
      bool playlistChanged = false;
      playlist.songs ??= [];

      // If songs list is empty but songPaths is not, or lengths mismatch
      if (playlist.songs!.length != playlist.songPaths.length) {
        for (var path in playlist.songPaths) {
          if (!playlist.songs!.any((s) => s.path == path)) {
            final songMeta = await _fetchMetadata(path, player);
            playlist.songs!.add(songMeta);
            playlistChanged = true;
          }
        }
      }

      if (playlistChanged) {
        await playlist.save();
        changed = true;
      }
    }
    await player.dispose();
    if (changed) {
      state = _box.values.toList();
    }
  }

  Future<SongMetadata> _fetchMetadata(String path, AudioPlayer player) async {
    String? title;
    String? artist;
    String? album;
    int? durationMs;

    try {
      final metadata = await MetadataRetriever.fromFile(File(path));
      title = metadata.trackName;
      artist = metadata.trackArtistNames?.join(', ');
      album = metadata.albumName;
      durationMs = metadata.trackDuration;
    } catch (e) {
      print("Error fetching metadata for $path: $e");
    }

    // Use just_audio for duration as requested by user
    try {
      final duration = await player.setFilePath(path);
      if (duration != null) {
        durationMs = duration.inMilliseconds;
      }
    } catch (e) {
      print("Error fetching duration with just_audio for $path: $e");
    }

    return SongMetadata(
      path: path,
      title: title,
      artist: artist,
      album: album,
      durationMs: durationMs,
    );
  }

  Future<void> createPlaylist(String name) async {
    if (_box.values.any((p) => p.name == name)) return; // Prevent duplicates
    final playlist = Playlist(name: name, songPaths: []);
    await _box.add(playlist);
    state = _box.values.toList();
    _updateStoredOrder();
  }

  Future<void> reorderPlaylists(int oldIndex, int newIndex) async {
    final list = List<Playlist>.from(state);
    if (newIndex > oldIndex) newIndex--;
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    state = list;
    _updateStoredOrder();
  }

  void _updateStoredOrder() {
    final settingsBox = Hive.box('settings');
    final orderedNames = state.map((p) => p.name).toList();
    settingsBox.put('playlist_order', orderedNames);
  }

  Future<void> deletePlaylist(Playlist playlist) async {
    // deleting by object matching reference or we need key
    // HiveObject has delete()
    await playlist.delete();
    // or _box.delete(key) if we knew it.
    // simpler to refresh state
    state = _box.values.toList();
    _updateStoredOrder();
  }

  // Method to add songs to a playlist
  Future<void> addSongsToPlaylist(Playlist playlist, List<String> paths) async {
    final player = AudioPlayer();
    for (final path in paths) {
      if (!playlist.songPaths.contains(path)) {
        playlist.songPaths.add(path);
      }

      final songMeta = await _fetchMetadata(path, player);
      playlist.songs ??= [];

      final existingIndex = playlist.songs!.indexWhere((s) => s.path == path);
      if (existingIndex != -1) {
        playlist.songs![existingIndex] = songMeta;
      } else {
        playlist.songs!.add(songMeta);
      }
    }
    await player.dispose();
    await playlist.save();
    state = _box.values.toList();
  }

  // Method to remove song from playlist
  Future<void> removeSongFromPlaylist(Playlist playlist, int index) async {
    final pathToRemove = playlist.songPaths[index];
    playlist.songPaths.removeAt(index);

    // Also remove from songs metadata list
    if (playlist.songs != null) {
      playlist.songs!.removeWhere((s) => s.path == pathToRemove);
    }

    await playlist.save();
    state = _box.values.toList();
  }

  Future<void> setLastPlayed(Playlist playlist, int index) async {
    playlist.lastPlayedIndex = index;
    await playlist.save();
    state = _box.values.toList();
  }

  // --- Helpers for other widgets ---
  SongMetadata? getMetadataForPath(String path) {
    for (var playlist in state) {
      if (playlist.songs != null) {
        final song = playlist.songs!.where((s) => s.path == path).firstOrNull;
        if (song != null) return song;
      }
    }
    return null;
  }

  static String formatDuration(int? ms) {
    if (ms == null || ms == 0) return "--:--";
    final duration = Duration(milliseconds: ms);
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return "$minutes:${seconds.toString().padLeft(2, '0')}";
  }

  // --- Duration Caching ---
  Future<Duration?> getCachedDuration(String path) async {
    final box = Hive.box<int>('audio_durations');

    if (box.containsKey(path)) {
      return Duration(milliseconds: box.get(path)!);
    }

    final duration = await getAudioDuration(path);
    if (duration != null) {
      box.put(path, duration.inMilliseconds);
    }
    return duration;
  }

  Future<Duration?> getAudioDuration(String path) async {
    final player = AudioPlayer();
    try {
      final duration = await player.setFilePath(path);
      return duration;
    } catch (e) {
      print("Error fetching duration for $path: $e");
      return null;
    } finally {
      await player.dispose();
    }
  }
}
