import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

/// Audio handler that bridges just_audio with Android's media session
class SimpleAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer _player;

  SimpleAudioHandler(this._player) {
    // Listen to playback events and broadcast to audio_service
    _player.playbackEventStream.listen(_broadcastState);
    _player.playingStream.listen((playing) {
      playbackState.add(playbackState.value.copyWith(playing: playing));
    });
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> stop() => _player.stop();

  /// Rewind 5 seconds
  @override
  Future<void> rewind() async {
    final newPosition = _player.position - const Duration(seconds: 5);
    await _player.seek(
      newPosition < Duration.zero ? Duration.zero : newPosition,
    );
  }

  /// Fast forward 5 seconds
  @override
  Future<void> fastForward() async {
    final duration = _player.duration;
    final newPosition = _player.position + const Duration(seconds: 5);
    if (duration != null && newPosition > duration) {
      await _player.seek(duration);
    } else {
      await _player.seek(newPosition);
    }
  }

  @override
  Future<void> skipToNext() => _player.seekToNext();

  @override
  Future<void> skipToPrevious() => _player.seekToPrevious();

  /// Update the media item displayed on lock screen
  void updateMetadata(MediaItem item) {
    mediaItem.add(item);
  }

  /// Broadcast playback state to audio_service
  void _broadcastState(PlaybackEvent event) {
    playbackState.add(
      PlaybackState(
        controls: [
          MediaControl.rewind,
          if (_player.playing) MediaControl.pause else MediaControl.play,
          MediaControl.fastForward,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState:
            const {
              ProcessingState.idle: AudioProcessingState.idle,
              ProcessingState.loading: AudioProcessingState.loading,
              ProcessingState.buffering: AudioProcessingState.buffering,
              ProcessingState.ready: AudioProcessingState.ready,
              ProcessingState.completed: AudioProcessingState.completed,
            }[_player.processingState] ??
            AudioProcessingState.idle,
        playing: _player.playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: event.currentIndex,
      ),
    );
  }
}
