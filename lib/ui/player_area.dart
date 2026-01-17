import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../providers/app_providers.dart';
import '../providers/tab_provider.dart';

class PlayerArea extends ConsumerStatefulWidget {
  const PlayerArea({super.key});

  @override
  ConsumerState<PlayerArea> createState() => _PlayerAreaState();
}

class _PlayerAreaState extends ConsumerState<PlayerArea> {
  // Logic from snippet
  bool _isDragging = false;
  double? _dragValue;
  bool _showRemainingTime = false;

  String _formatDuration(Duration? d) {
    if (d == null) return "00:00";
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    // Metadata (Low Frequency)
    final playerMetadata = ref.watch(playerProvider);
    final player = ref.watch(audioPlayerProvider); // Direct player for controls

    // High Frequency Providers
    final positionAsync = ref.watch(playerPositionProvider);
    final durationAsync = ref.watch(playerDurationProvider);
    final playerStateAsync = ref.watch(audioPlayerStateProvider);

    final duration = durationAsync.value ?? Duration.zero;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Scrolling Artist & Title
          SizedBox(
            height: 40,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Text(
                    "${playerMetadata.artist ?? 'Artist'} - ${playerMetadata.title ?? 'Song Title'}",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Snippet Logic Integration: Position / Duration Labels & Slider
          positionAsync.when(
            data: (position) {
              var displayPosition = position;
              if (_isDragging && _dragValue != null) {
                displayPosition = Duration(milliseconds: _dragValue!.round());
              }
              // Ensure we don't exceed duration for display
              if (displayPosition > duration) {
                displayPosition = duration;
              }

              return Row(
                children: [
                  InkWell(
                    onTap: () {
                      setState(() {
                        _showRemainingTime = !_showRemainingTime;
                      });
                    },
                    child: Text(
                      _showRemainingTime
                          ? "-${_formatDuration(duration - displayPosition)}"
                          : _formatDuration(displayPosition),
                      textAlign: TextAlign.start,
                      maxLines: 1,
                    ),
                  ),
                  Expanded(
                    child: Slider(
                      min: 0,
                      max: duration.inMilliseconds.toDouble() > 0
                          ? duration.inMilliseconds.toDouble()
                          : 0.0,
                      value: (_isDragging && _dragValue != null)
                          ? _dragValue!
                          : position.inMilliseconds.toDouble().clamp(
                              0.0,
                              duration.inMilliseconds.toDouble() > 0
                                  ? duration.inMilliseconds.toDouble()
                                  : 0.0,
                            ),
                      onChanged: (value) {
                        setState(() {
                          _isDragging = true;
                          _dragValue = value;
                        });
                      },
                      onChangeStart: (value) {
                        player.pause();
                      },

                      onChangeEnd: (value) {
                        player.seek(Duration(milliseconds: value.round()));
                        player.play();
                        setState(() {
                          _isDragging = false;
                          _dragValue = null;
                        });
                      },
                    ),
                  ),
                  Text(_formatDuration(duration), textAlign: TextAlign.end),
                ],
              );
            },
            error: (_, __) => const Text("Error loading position"),
            loading: () => const Row(
              children: [
                Text("00:00"),
                Expanded(child: Slider(value: 0, onChanged: null)),
                Text("00:00", textAlign: TextAlign.end),
              ],
            ),
          ),

          // Controls
          SizedBox(
            height: 80,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(
                    Icons.shuffle,
                    color: playerMetadata.isShuffleModeEnabled
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                  onPressed: () => ref
                      .read(playerProvider.notifier)
                      .setShuffleMode(!playerMetadata.isShuffleModeEnabled),
                ),
                IconButton(
                  icon: const Icon(Icons.replay_5),
                  onPressed: () => ref
                      .read(playerProvider.notifier)
                      .seekRelative(const Duration(seconds: -5)),
                ),
                IconButton(
                  icon: const Icon(Icons.skip_previous),
                  onPressed: () => ref.read(playerProvider.notifier).previous(),
                ),
                // Play/Pause Button Logic from Snippet (adapted to fit in Row)
                playerStateAsync.when(
                  data: (playerState) {
                    final processingState = playerState.processingState;
                    final playing = playerState.playing;

                    if (processingState == ProcessingState.loading ||
                        processingState == ProcessingState.buffering) {
                      return const SizedBox(
                        width: 64,
                        height: 64,
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    } else if (playing != true) {
                      return IconButton(
                        icon: const Icon(Icons.play_arrow),
                        iconSize: 64.0,
                        onPressed: () {
                          // Context-aware Play Logic
                          final currentTabIndex = ref.read(tabProvider);
                          if (currentTabIndex == 1) {
                            // Playlist Tab
                            final playlists = ref.read(playlistsProvider);
                            final selectedIndex = ref.read(
                              selectedPlaylistIndexProvider,
                            );
                            if (selectedIndex < playlists.length) {
                              final visiblePlaylist = playlists[selectedIndex];
                              final currentPlaylist =
                                  playerMetadata.currentPlaylist;

                              if (currentPlaylist?.name !=
                                  visiblePlaylist.name) {
                                // Switch to visible playlist
                                ref
                                    .read(playerProvider.notifier)
                                    .playPlaylist(
                                      visiblePlaylist,
                                      initialIndex:
                                          visiblePlaylist.lastPlayedIndex,
                                      initialPosition: Duration(
                                        milliseconds:
                                            visiblePlaylist.lastPlayedPosition,
                                      ),
                                    );
                                return;
                              }
                            }
                          }
                          // Default behavior
                          player.play();
                        },
                      );
                    } else if (processingState != ProcessingState.completed) {
                      return IconButton(
                        icon: const Icon(Icons.pause),
                        iconSize: 64.0,
                        onPressed: player.pause,
                      );
                    } else {
                      return IconButton(
                        icon: const Icon(Icons.replay),
                        iconSize: 64.0,
                        onPressed: () => player.seek(Duration.zero),
                      );
                    }
                  },
                  error: (_, __) => const Icon(Icons.error),
                  loading: () => const SizedBox(
                    width: 64,
                    height: 64,
                    child: CircularProgressIndicator(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.skip_next),
                  onPressed: () => ref.read(playerProvider.notifier).next(),
                ),
                IconButton(
                  icon: const Icon(Icons.forward_5),
                  onPressed: () => ref
                      .read(playerProvider.notifier)
                      .seekRelative(const Duration(seconds: 5)),
                ),
                _RepeatPopup(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RepeatPopup extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loopMode = ref.watch(playerProvider.select((s) => s.loopMode));

    IconData iconData;
    Color? color;

    switch (loopMode) {
      case LoopMode.off:
        iconData = Icons.repeat;
        color = null;
        break;
      case LoopMode.one:
        iconData = Icons.repeat_one;
        color = Theme.of(context).colorScheme.primary;
        break;
      case LoopMode.all:
        iconData = Icons.repeat;
        color = Theme.of(context).colorScheme.primary;
        break;
    }

    return PopupMenuButton<LoopMode>(
      icon: Icon(iconData, color: color),
      initialValue: loopMode,
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: LoopMode.off,
          child: Row(
            children: [
              Icon(Icons.repeat),
              SizedBox(width: 8),
              Text('No Repeat'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: LoopMode.one,
          child: Row(
            children: [
              Icon(Icons.repeat_one),
              SizedBox(width: 8),
              Text('Repeat One'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: LoopMode.all,
          child: Row(
            children: [
              Icon(Icons.repeat),
              SizedBox(width: 8),
              Text('Repeat List'),
            ],
          ),
        ),
      ],
      onSelected: (mode) {
        ref.read(playerProvider.notifier).setLoopMode(mode);
      },
    );
  }
}
