import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../providers/app_providers.dart';

class PlayerArea extends ConsumerStatefulWidget {
  const PlayerArea({super.key});

  @override
  ConsumerState<PlayerArea> createState() => _PlayerAreaState();
}

class _PlayerAreaState extends ConsumerState<PlayerArea> {
  bool _showRemaining = true;
  double? _dragValue; // Moved from build to state class
  bool _wasPlayingBeforeDrag = false;

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    // Optional: handle hours if needed, but usually song length is mins
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerProvider);

    final effectivePosition = _dragValue != null
        ? Duration(milliseconds: _dragValue!.toInt())
        : playerState.position;

    final elapsed = _formatDuration(effectivePosition);
    final total = _formatDuration(playerState.duration);
    final remaining = _formatDuration(playerState.duration - effectivePosition);

    final timeDisplay = _showRemaining
        ? "-$remaining / $total"
        : "$elapsed / $total";

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
                    "${playerState.artist ?? 'Artist'} - ${playerState.title ?? 'Song Title'}",
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

          // Time Display
          InkWell(
            onTap: () {
              setState(() {
                _showRemaining = !_showRemaining;
              });
            },
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 8.0,
                vertical: 4.0,
              ),
              child: Text(
                timeDisplay,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),

          // Progress Bar
          Slider(
            activeColor: const Color.fromARGB(255, 32, 255, 244),
            inactiveColor: Theme.of(context).colorScheme.onSurfaceVariant,
            value:
                (_dragValue ?? playerState.position.inMilliseconds.toDouble())
                    .clamp(0.0, playerState.duration.inMilliseconds.toDouble()),
            min: 0.0,
            max: playerState.duration.inMilliseconds.toDouble(),
            onChangeStart: (value) {
              _wasPlayingBeforeDrag = playerState.isPlaying;
              setState(() {
                _dragValue = value;
              });
              ref.read(playerProvider.notifier).pause();
            },
            onChanged: (value) {
              setState(() {
                _dragValue = value;
              });
            },
            onChangeEnd: (value) async {
              await ref
                  .read(playerProvider.notifier)
                  .seek(Duration(milliseconds: value.toInt()));
              // Resume only if it was playing before
              if (_wasPlayingBeforeDrag) {
                await ref.read(playerProvider.notifier).play();
              }
              //await ref.read(playerProvider.notifier).play();
              setState(() {
                _dragValue = null;
              });
            },
          ),

          // Controls
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(
                    Icons.shuffle,
                    color: playerState.isShuffleModeEnabled
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                  onPressed: () => ref
                      .read(playerProvider.notifier)
                      .setShuffleMode(!playerState.isShuffleModeEnabled),
                ), // Shuffle toggle
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
                IconButton(
                  iconSize: 48,
                  icon: Icon(
                    playerState.isPlaying ? Icons.pause : Icons.play_arrow,
                  ),
                  onPressed: () {
                    final notifier = ref.read(playerProvider.notifier);
                    if (playerState.isPlaying) {
                      notifier.togglePlay();
                    } else {
                      final playlists = ref.read(playlistsProvider);
                      final selectedIndex = ref.read(
                        selectedPlaylistIndexProvider,
                      );
                      if (selectedIndex < playlists.length) {
                        final selectedPlaylist = playlists[selectedIndex];
                        if (playerState.currentPlaylist == selectedPlaylist) {
                          notifier.togglePlay();
                        } else {
                          notifier.playPlaylist(selectedPlaylist);
                        }
                      }
                    }
                  },
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
