import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import '../models/playlist.dart';

class PlayerState {
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final String? currentSongPath;
  final String? artist;
  final String? title;
  final Playlist? currentPlaylist;
  final bool isShuffleModeEnabled;
  final LoopMode loopMode;

  PlayerState({
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.currentSongPath,
    this.artist,
    this.title,
    this.currentPlaylist,
    this.isShuffleModeEnabled = false,
    this.loopMode = LoopMode.off,
  });

  PlayerState copyWith({
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    String? currentSongPath,
    String? artist,
    String? title,
    Playlist? currentPlaylist,
    bool? isShuffleModeEnabled,
    LoopMode? loopMode,
  }) {
    return PlayerState(
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      currentSongPath: currentSongPath ?? this.currentSongPath,
      artist: artist ?? this.artist,
      title: title ?? this.title,
      currentPlaylist: currentPlaylist ?? this.currentPlaylist,
      isShuffleModeEnabled: isShuffleModeEnabled ?? this.isShuffleModeEnabled,
      loopMode: loopMode ?? this.loopMode,
    );
  }
}

final playerProvider = StateNotifierProvider<PlayerNotifier, PlayerState>((
  ref,
) {
  return PlayerNotifier();
});

class PlayerNotifier extends StateNotifier<PlayerState> {
  late AudioPlayer _player;
  Playlist? _activePlaylist;

  PlayerNotifier() : super(PlayerState()) {
    _init();
  }

  Future<void> _init() async {
    _player = AudioPlayer();
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

    // Listen to player streams
    _player.playerStateStream.listen((playerState) {
      state = state.copyWith(isPlaying: playerState.playing);
    });

    _player.positionStream.listen((position) {
      state = state.copyWith(position: position);
      _savePositionDebounced(position);
    });

    _player.durationStream.listen((duration) {
      if (duration != null) {
        state = state.copyWith(duration: duration);
      }
    });

    _player.currentIndexStream.listen((index) {
      if (index != null && _activePlaylist != null) {
        _updateCurrentSongInfo(index);
      }
    });

    _player.shuffleModeEnabledStream.listen((enabled) {
      state = state.copyWith(isShuffleModeEnabled: enabled);
    });

    _player.loopModeStream.listen((mode) {
      state = state.copyWith(loopMode: mode);
    });

    _player.playbackEventStream.listen((event) {});

    // Listen to the new errorStream as requested
    _player.errorStream.listen((error) {
      print("Playback error: $error");
    });
  }

  Future<void> _updateCurrentSongInfo(int index) async {
    if (_activePlaylist == null ||
        index < 0 ||
        index >= _activePlaylist!.songPaths.length)
      return;

    final path = _activePlaylist!.songPaths[index];

    // Find metadata in the playlist
    final songMeta = _activePlaylist!.songs?.firstWhere(
      (s) => s.path == path,
      orElse: () => SongMetadata(path: path),
    );

    state = state.copyWith(
      currentSongPath: path,
      title: songMeta?.title ?? path.split('/').last,
      artist: songMeta?.artist ?? 'Unknown Artist',
    );

    // Save functionality
    _activePlaylist!.lastPlayedIndex = index;
    if (_activePlaylist!.isInBox) {
      await _activePlaylist!.save();
    }
  }

  void _savePositionDebounced(Duration position) {
    if (_activePlaylist != null) {
      _activePlaylist!.lastPlayedPosition = position.inMilliseconds;
    }
  }

  Future<void> _flushStateToHive() async {
    if (_activePlaylist != null && _activePlaylist!.isInBox) {
      await _activePlaylist!.save();
    }
  }

  Future<void> playPlaylist(Playlist playlist, {int? initialIndex}) async {
    _activePlaylist = playlist;
    state = state.copyWith(currentPlaylist: playlist);

    final audioSources = playlist.songPaths
        .map((path) => AudioSource.file(path))
        .toList();

    int startIndex = initialIndex ?? playlist.lastPlayedIndex;
    int startPosMs = (initialIndex == null)
        ? playlist.lastPlayedPosition
        : 0; // If explicit index, start from 0

    // Bounds check
    if (startIndex >= audioSources.length) startIndex = 0;
    if (startIndex < 0) startIndex = 0;
    if (startPosMs < 0) startPosMs = 0;

    try {
      await _player.setAudioSources(
        audioSources,
        initialIndex: startIndex,
        initialPosition: Duration(milliseconds: startPosMs),
      );
      _player.play();
    } catch (e) {
      print("Error loading playlist: $e");
    }
  }

  Future<void> playNext(String path, Playlist sourcePlaylist) async {
    // 1. If no active playlist or source is different, we switch context
    final isSameContext = _activePlaylist?.name == sourcePlaylist.name;

    if (!isSameContext) {
      // Switch context:
      // Keep current playing item, then add the 'playNext' item, then the rest of the new playlist
      final currentPath = state.currentSongPath;

      List<String> newPaths = [];
      if (currentPath != null) {
        newPaths.add(currentPath);
      }
      newPaths.add(path);

      // Add rest of sourcePlaylist (excluding 'path' if it's already there)
      for (final p in sourcePlaylist.songPaths) {
        if (p != path && p != currentPath) {
          newPaths.add(p);
        }
      }

      final newPlaylist = Playlist(
        name: sourcePlaylist.name,
        songPaths: newPaths,
        songs: sourcePlaylist.songs, // Re-use metadata if available
      );

      _activePlaylist = newPlaylist;
      state = state.copyWith(currentPlaylist: newPlaylist);

      final audioSources = newPaths.map((p) => AudioSource.file(p)).toList();

      // Capture current position BEFORE updating sources
      final currentPos = _player.position;

      // Update source dynamically using the new API
      await _player.setAudioSources(
        audioSources,
        initialIndex: 0,
        initialPosition: currentPos,
      );
      _player.play();
    } else {
      // Same context: Just move/insert 'path' to next position
      final currentIdx = _player.currentIndex ?? 0;
      final targetIdx = currentIdx + 1;

      // Find if it's already in the queue
      final existingIdx = _activePlaylist!.songPaths.indexOf(path);

      if (existingIdx != -1) {
        if (existingIdx == targetIdx) return; // Already there

        // Update using direct AudioPlayer method
        await _player.moveAudioSource(existingIdx, targetIdx);

        // Update internal list
        final paths = List<String>.from(_activePlaylist!.songPaths);
        final movedPath = paths.removeAt(existingIdx);
        paths.insert(targetIdx, movedPath);

        _activePlaylist = Playlist(
          name: _activePlaylist!.name,
          songPaths: paths,
          songs: _activePlaylist!.songs,
          lastPlayedIndex: _activePlaylist!.lastPlayedIndex,
          lastPlayedPosition: _activePlaylist!.lastPlayedPosition,
        );
      } else {
        // Not in playlist, insert it using direct AudioPlayer method
        await _player.insertAudioSource(targetIdx, AudioSource.file(path));

        final paths = List<String>.from(_activePlaylist!.songPaths);
        paths.insert(targetIdx, path);

        _activePlaylist = Playlist(
          name: _activePlaylist!.name,
          songPaths: paths,
          songs: _activePlaylist!.songs,
          lastPlayedIndex: _activePlaylist!.lastPlayedIndex,
          lastPlayedPosition: _activePlaylist!.lastPlayedPosition,
        );
      }
      state = state.copyWith(currentPlaylist: _activePlaylist);
    }
  }

  Future<void> togglePlay() async {
    if (_player.playing) {
      await _player.pause();
      await _flushStateToHive();
    } else {
      _player.play();
    }
  }

  Future<void> next() async {
    await _player.seekToNext();
  }

  Future<void> previous() async {
    await _player.seekToPrevious();
  }

  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  Future<void> seekRelative(Duration offset) async {
    final newPosition = state.position + offset;
    final duration = state.duration;
    if (newPosition < Duration.zero) {
      await seek(Duration.zero);
    } else if (newPosition > duration) {
      await seek(duration);
    } else {
      await seek(newPosition);
    }
  }

  Future<void> setShuffleMode(bool enabled) async {
    await _player.setShuffleModeEnabled(enabled);
  }

  Future<void> setLoopMode(LoopMode mode) async {
    await _player.setLoopMode(mode);
  }

  @override
  void dispose() {
    _flushStateToHive();
    _player.dispose();
    super.dispose();
  }
}
