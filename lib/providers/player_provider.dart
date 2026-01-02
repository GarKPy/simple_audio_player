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
  }

  Future<void> _updateCurrentSongInfo(int index) async {
    if (_activePlaylist == null ||
        index < 0 ||
        index >= _activePlaylist!.songPaths.length)
      return;

    final path = _activePlaylist!.songPaths[index];
    // Here you would optimally parse metadata. For now, using filename.
    final filename = path.split('/').last;

    state = state.copyWith(
      currentSongPath: path,
      title: filename, // Temporary fallback
      artist: 'Unknown Artist', // JSON/Metadata parsing needed later
    );

    // Save functionality
    _activePlaylist!.lastPlayedIndex = index;
    await _activePlaylist!.save();
  }

  void _savePositionDebounced(Duration position) {
    // Very simple debounce or direct save.
    // Saving to Hive excessively (every 200ms) might be bad.
    // Better to save on pause or stop.
    // But user requested "last played info" which usually implies exact resume.
    // We will save to a memory variable and flush on pause/dispose?
    // For now, let's update the model in memory, not save to disk every frame.
    if (_activePlaylist != null) {
      _activePlaylist!.lastPlayedPosition = position.inMilliseconds;
      // We defer .save() to pause/stop or specific checkpoints
    }
  }

  Future<void> _flushStateToHive() async {
    if (_activePlaylist != null) {
      await _activePlaylist!.save();
    }
  }

  Future<void> playPlaylist(Playlist playlist, {int? initialIndex}) async {
    _activePlaylist = playlist;
    state = state.copyWith(currentPlaylist: playlist);

    final audioSources = playlist.songPaths
        .map((path) => AudioSource.file(path))
        .toList();
    final source = ConcatenatingAudioSource(children: audioSources);

    int startIndex = initialIndex ?? playlist.lastPlayedIndex;
    int startPosMs = (initialIndex == null)
        ? playlist.lastPlayedPosition
        : 0; // If explicit index, start from 0

    // Bounds check
    if (startIndex >= audioSources.length) startIndex = 0;
    if (startIndex < 0) startIndex = 0;
    if (startPosMs < 0) startPosMs = 0;

    try {
      await _player.setAudioSource(
        source,
        initialIndex: startIndex,
        initialPosition: Duration(milliseconds: startPosMs),
      );
      _player.play();
    } catch (e) {
      print("Error loading playlist: $e");
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
