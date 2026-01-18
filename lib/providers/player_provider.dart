import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:audio_service/audio_service.dart';
import '../models/playlist.dart';
import '../services/audio_handler.dart';
import 'package:path/path.dart' as p;

// --- Shared AudioPlayer Instance ---
// Provides the raw AudioPlayer instance. We use a Provider because we want to
// ensure it's a singleton (or scoped) and dispose of it when the provider is disposed.
final audioPlayerProvider = Provider<AudioPlayer>((ref) {
  final player = AudioPlayer();
  ref.onDispose(() {
    player.dispose();
  });
  return player;
});

// --- AudioHandler Provider ---
// Provides the audio handler for lock screen controls
final audioHandlerProvider = Provider<SimpleAudioHandler?>((ref) {
  return null; // Will be overridden in main.dart
});

// --- Stream Providers for High-Frequency Updates ---

final playerPositionProvider = StreamProvider<Duration>((ref) {
  final player = ref.watch(audioPlayerProvider);
  return player.positionStream;
});

final playerDurationProvider = StreamProvider<Duration?>((ref) {
  final player = ref.watch(audioPlayerProvider);
  return player.durationStream;
});

// Provides the full PlayerState from just_audio (playing status + processing state)
// We use the fully qualified name or ensure no collision.
// Since we renamed our local class to PlayerMetadata, this is now safe if we don't alias?
// Wait, we need to make sure 'PlayerState' refers to just_audio's class here.
// But we are in the same file where we define PlayerMetadata.
// The import 'package:just_audio/just_audio.dart' provides PlayerState.
// So if we don't have a local PlayerState, 'PlayerState' refers to just_audio's.
final audioPlayerStateProvider = StreamProvider<PlayerState>((ref) {
  final player = ref.watch(audioPlayerProvider);
  return player.playerStateStream;
});

final playerPlayingProvider = StreamProvider<bool>((ref) {
  final player = ref.watch(audioPlayerProvider);
  return player.playingStream;
});

// --- Player State (Metadata & Low-Frequency Config) ---

class PlayerMetadata {
  // Removed high-frequency fields: isPlaying, position, duration
  final String? currentSongPath;
  final String? artist;
  final String? title;
  final Playlist? currentPlaylist;
  final bool isShuffleModeEnabled;
  final LoopMode loopMode;

  PlayerMetadata({
    this.currentSongPath,
    this.artist,
    this.title,
    this.currentPlaylist,
    this.isShuffleModeEnabled = false,
    this.loopMode = LoopMode.off,
  });

  PlayerMetadata copyWith({
    String? currentSongPath,
    String? artist,
    String? title,
    Playlist? currentPlaylist,
    bool? isShuffleModeEnabled,
    LoopMode? loopMode,
  }) {
    return PlayerMetadata(
      currentSongPath: currentSongPath ?? this.currentSongPath,
      artist: artist ?? this.artist,
      title: title ?? this.title,
      currentPlaylist: currentPlaylist ?? this.currentPlaylist,
      isShuffleModeEnabled: isShuffleModeEnabled ?? this.isShuffleModeEnabled,
      loopMode: loopMode ?? this.loopMode,
    );
  }
}

final playerProvider = StateNotifierProvider<PlayerNotifier, PlayerMetadata>((
  ref,
) {
  final player = ref.watch(audioPlayerProvider);
  final handler = ref.watch(audioHandlerProvider);
  return PlayerNotifier(player, handler);
});

class PlayerNotifier extends StateNotifier<PlayerMetadata> {
  final AudioPlayer _player;
  final SimpleAudioHandler? _handler;
  Playlist? _activePlaylist;

  PlayerNotifier(this._player, this._handler) : super(PlayerMetadata()) {
    _init();
  }

  Future<void> _init() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

    // We no longer update state for position/duration/playing.
    // Instead we just listen to what's needed for logic or side effects.

    // Side effect: Save position for resume
    _player.positionStream.listen((position) {
      _savePositionDebounced(position);
    });

    _player.playbackEventStream.listen((event) {
      // Also save on playback events (like seek)
      _savePositionDebounced(event.updatePosition);
    });

    _player.currentIndexStream.listen((index) {
      if (index != null && _activePlaylist != null) {
        _updateCurrentSongInfo(index);
      }
    });

    _player.shuffleModeEnabledStream.listen((enabled) {
      if (state.isShuffleModeEnabled != enabled) {
        state = state.copyWith(isShuffleModeEnabled: enabled);
      }
    });

    _player.loopModeStream.listen((mode) {
      if (state.loopMode != mode) {
        state = state.copyWith(loopMode: mode);
      }
    });

    _player.errorStream.listen((error) {
      // Handle error logging
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

    // Update lock screen metadata
    _handler?.updateMetadata(
      MediaItem(
        id: path,
        album: _activePlaylist?.name ?? p.dirname(path).split(p.separator).last,
        title: state.title!,
        artist: state.artist!,
        duration: songMeta?.durationMs != null
            ? Duration(milliseconds: songMeta!.durationMs!)
            : null,
      ),
    );

    // Save functionality
    _activePlaylist!.lastPlayedIndex = index;
    if (_activePlaylist!.isInBox) {
      await _activePlaylist!.save();
    }
  }

  Future<void> _savePositionDebounced(Duration position) async {
    if (_activePlaylist != null && _activePlaylist!.isInBox) {
      _activePlaylist!.lastPlayedPosition = position.inMilliseconds;
      await _activePlaylist!.save();
    }
  }

  Future<void> _saveCurrentPlaybackState() async {
    if (_activePlaylist != null && _activePlaylist!.isInBox) {
      final currentIdx = _player.currentIndex;
      if (currentIdx != null) {
        _activePlaylist!.lastPlayedIndex = currentIdx;
      }
      _activePlaylist!.lastPlayedPosition = _player.position.inMilliseconds;
      await _activePlaylist!.save();
    }
  }

  Future<void> _flushStateToHive() async {
    if (_activePlaylist != null && _activePlaylist!.isInBox) {
      await _activePlaylist!.save();
    }
  }

  Future<void> playPlaylist(
    Playlist playlist, {
    int initialIndex = 0,
    Duration? initialPosition,
  }) async {
    // Save state of the previos playlist before switching
    await _saveCurrentPlaybackState();

    _activePlaylist = playlist;
    state = state.copyWith(currentPlaylist: playlist);

    final audioSources = playlist.songPaths
        .map((path) => AudioSource.file(path))
        .toList();

    // Safety check just in case
    if (initialIndex >= audioSources.length) {
      initialIndex = 0;
      initialPosition = Duration.zero;
    }

    try {
      // Load and apply playlist-specific settings
      await _player.setShuffleModeEnabled(playlist.shuffle);
      await _player.setLoopMode(_intToLoopMode(playlist.repeatMode));

      await _player.setAudioSources(
        audioSources,
        initialIndex: initialIndex,
        initialPosition: initialPosition,
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
      await _saveCurrentPlaybackState();
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
      await pause();
    } else {
      await play();
    }
  }

  Future<void> pause() async {
    await _player.pause();
    await _flushStateToHive();
  }

  Future<void> play() async {
    await _player.play();
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
    // Requires reading current position from player, as it's not in state
    final currentPosition = _player.position; // Get direct value
    final newPosition = currentPosition + offset;
    final duration = _player.duration; // Get direct value

    if (newPosition < Duration.zero) {
      await seek(Duration.zero);
    } else if (duration != null && newPosition > duration) {
      await seek(duration);
    } else {
      await seek(newPosition);
    }
  }

  Future<void> setShuffleMode(bool enabled) async {
    await _player.setShuffleModeEnabled(enabled);
    if (_activePlaylist != null && _activePlaylist!.isInBox) {
      _activePlaylist!.shuffle = enabled;
      await _activePlaylist!.save();
    }
  }

  Future<void> setLoopMode(LoopMode mode) async {
    await _player.setLoopMode(mode);
    if (_activePlaylist != null && _activePlaylist!.isInBox) {
      _activePlaylist!.repeatMode = _loopModeToInt(mode);
      await _activePlaylist!.save();
    }
  }

  Future<void> stopPlayback() async {
    await _player.stop();
    _activePlaylist = null;
    state = PlayerMetadata();
  }

  int _loopModeToInt(LoopMode mode) {
    switch (mode) {
      case LoopMode.off:
        return 0;
      case LoopMode.one:
        return 1;
      case LoopMode.all:
        return 2;
    }
  }

  LoopMode _intToLoopMode(int val) {
    switch (val) {
      case 1:
        return LoopMode.one;
      case 2:
        return LoopMode.all;
      default:
        return LoopMode.off;
    }
  }

  @override
  void dispose() {
    _flushStateToHive();
    // Reference to _player is managed by audioPlayerProvider (disposed there)
    // So we don't dispose _player here to avoid double disposal or disposing shared instance
    super.dispose();
  }
}
