import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import '../providers/app_providers.dart';
import '../models/playlist.dart';
import 'package:path/path.dart' as p;

class PlaylistTab extends ConsumerStatefulWidget {
  const PlaylistTab({super.key});

  @override
  ConsumerState<PlaylistTab> createState() => _PlaylistTabState();
}

class _PlaylistTabState extends ConsumerState<PlaylistTab> {
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();

  void _scrollToCurrentSong(List<String> songPaths) {
    // We need to know which song is currently playing and if it belongs to this playlist
    final playerState = ref.read(playerProvider);
    if (playerState.currentSongPath != null) {
      final index = songPaths.indexOf(playerState.currentSongPath!);
      if (index != -1) {
        if (_itemScrollController.isAttached) {
          _itemScrollController.scrollTo(
            index: index,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            alignment: 0.5, // Center the item
          );
        }
      }
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final playlists = ref.read(playlistsProvider);
      final index = ref.read(selectedPlaylistIndexProvider);
      if (index < playlists.length) {
        _scrollToCurrentSong(playlists[index].songPaths);
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    //print("PlaylistTab: build called");
    final playlists = ref.watch(playlistsProvider);
    var selectedPlaylistIndex = ref.watch(selectedPlaylistIndexProvider);

    // Listen for playlist selection changes to scroll
    ref.listen(selectedPlaylistIndexProvider, (previous, next) {
      if (next < playlists.length) {
        _scrollToCurrentSong(playlists[next].songPaths);
      }
    });
    //print("PlaylistTab: playlists count: ${playlists.length}");
    final playerState = ref.watch(playerProvider);

    // Safety check if playlists is empty (shouldn't be, due to init)
    if (playlists.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    // Ensure index is valid
    if (selectedPlaylistIndex >= playlists.length) {
      selectedPlaylistIndex = 0;
      // Defer state update to next frame to avoid build error, or just rely on local var correction for this build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(selectedPlaylistIndexProvider.notifier).state = 0;
      });
    }

    final selectedPlaylist = playlists[selectedPlaylistIndex];

    // Listen for song changes to auto-scroll
    ref.listen(playerProvider, (previous, next) {
      bool shouldScroll = false;

      // Condition 1: Song path changed
      if (previous?.currentSongPath != next.currentSongPath &&
          next.currentSongPath != null) {
        shouldScroll = true;
      }

      if (shouldScroll) {
        _scrollToCurrentSong(selectedPlaylist.songPaths);
      }
    });

    // Condition 2: Started playing (and path matches)
    ref.listen(playerPlayingProvider, (previousAsync, nextAsync) {
      final previous = previousAsync?.value ?? false;
      final next = nextAsync.value ?? false;

      if (!previous && next) {
        // Started playing
        _scrollToCurrentSong(selectedPlaylist.songPaths);
      }
    });

    return Column(
      children: [
        // Horizontal Playlists + Add Button
        SizedBox(
          height: 50,
          child: Stack(
            children: [
              ReorderableListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                // Removes background's shade
                proxyDecorator: (child, index, animation) {
                  return AnimatedBuilder(
                    animation: animation,
                    builder: (context, child) {
                      return Material(
                        elevation: 10,
                        color: Colors.transparent,
                        child: child,
                      );
                    },
                    child: child,
                  );
                },
                itemCount: playlists.length,
                onReorder: (oldIndex, newIndex) {
                  ref
                      .read(playlistsProvider.notifier)
                      .reorderPlaylists(oldIndex, newIndex);
                },
                itemBuilder: (context, index) {
                  final playlist = playlists[index];
                  final isSelected = index == selectedPlaylistIndex;
                  return ReorderableDelayedDragStartListener(
                    key: ValueKey(playlists[index]),
                    index: index,
                    child: Center(
                      child: Row(
                        children: [
                          Dismissible(
                            key: ValueKey("dismiss_${playlist.name}"),
                            direction: playlist.name == 'Favorites'
                                ? DismissDirection.none
                                : DismissDirection.up,
                            confirmDismiss: (direction) async {
                              return await _confirmDeletePlaylist(
                                context,
                                playlist,
                              );
                            },
                            onDismissed: (direction) async {
                              // Check if currently playing track is from this playlist
                              final currentSongPath =
                                  playerState.currentSongPath;
                              final isPlayingFromThisPlaylist =
                                  currentSongPath != null &&
                                  playlist.songPaths.contains(currentSongPath);

                              if (isPlayingFromThisPlaylist) {
                                // Stop playback if playing from dismissed playlist
                                await ref
                                    .read(playerProvider.notifier)
                                    .stopPlayback();
                              }

                              // Delete the playlist
                              await ref
                                  .read(playlistsProvider.notifier)
                                  .deletePlaylist(playlist);

                              // Determine which playlist to display next
                              final updatedPlaylists = ref.read(
                                playlistsProvider,
                              );
                              int newIndex = 0; // Default to Favorites

                              if (!isPlayingFromThisPlaylist &&
                                  currentSongPath != null) {
                                // Find which playlist contains the currently playing track
                                for (
                                  int i = 0;
                                  i < updatedPlaylists.length;
                                  i++
                                ) {
                                  if (updatedPlaylists[i].songPaths.contains(
                                    currentSongPath,
                                  )) {
                                    newIndex = i;
                                    break;
                                  }
                                }
                              }

                              // Update selected playlist index
                              ref
                                      .read(
                                        selectedPlaylistIndexProvider.notifier,
                                      )
                                      .state =
                                  newIndex;
                            },
                            background: Container(
                              color: Colors.red,
                              alignment: Alignment.bottomCenter,
                              padding: const EdgeInsets.only(bottom: 8),
                              child: const Icon(
                                Icons.delete,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            child: Material(
                              color: isSelected
                                  ? Theme.of(
                                      context,
                                    ).colorScheme.primaryContainer
                                  : Theme.of(
                                      context,
                                    ).colorScheme.surfaceContainerHighest,
                              elevation: 5,
                              surfaceTintColor: Theme.of(
                                context,
                              ).colorScheme.primary,
                              child: Ink(
                                decoration: BoxDecoration(
                                  border: isSelected
                                      ? Border.all(
                                          color: const Color.fromARGB(
                                            255,
                                            32,
                                            255,
                                            244,
                                          ).withValues(alpha: 1),
                                          width: 2,
                                        )
                                      : Border.all(
                                          color: const Color.fromARGB(
                                            255,
                                            32,
                                            255,
                                            244,
                                          ).withValues(alpha: 0.5),
                                          width: 2,
                                        ),
                                ),
                                child: InkWell(
                                  onTap: () {
                                    ref
                                            .read(
                                              selectedPlaylistIndexProvider
                                                  .notifier,
                                            )
                                            .state =
                                        index;
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8.0,
                                      vertical: 2.0,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          playlist.name,
                                          style: TextStyle(
                                            color: isSelected
                                                ? Theme.of(context)
                                                      .colorScheme
                                                      .onPrimaryContainer
                                                : Theme.of(context)
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                            fontWeight: isSelected
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                          ),
                                        ),
                                        if (isSelected) ...[
                                          const SizedBox(width: 4),
                                          InkWell(
                                            onTap: () {
                                              ref
                                                  .read(playerProvider.notifier)
                                                  .playPlaylist(
                                                    playlist,
                                                    initialIndex: playlist
                                                        .lastPlayedIndex,
                                                    initialPosition: Duration(
                                                      milliseconds: playlist
                                                          .lastPlayedPosition,
                                                    ),
                                                  );
                                            },
                                            child: Icon(
                                              Icons.play_arrow,
                                              size: 20,
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onPrimaryContainer,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const VerticalDivider(
                            width: 8,
                            color: Colors.transparent,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              Positioned(
                right: 0,
                height: 50,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Theme.of(context).colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0), // fully visible
                        Theme.of(context).colorScheme.surfaceContainerHighest
                            .withValues(alpha: 1), // fully transparent
                      ],
                    ),
                  ),
                  child: InkWell(
                    onTap: () => _showCreatePlaylistDialog(context),
                    child: Icon(
                      Icons.add,
                      size: 32,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Divider(
          color: Theme.of(context).colorScheme.primary,
          thickness: 2,
          height: 2,
        ),
        // Vertical List of Items
        Expanded(
          child: selectedPlaylist.songPaths.isEmpty
              ? Center(
                  child: Text(
                    "No songs in ${selectedPlaylist.name}",
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                )
              : ScrollablePositionedList.builder(
                  itemScrollController: _itemScrollController,
                  itemPositionsListener: _itemPositionsListener,
                  itemCount: selectedPlaylist.songPaths.length,
                  itemBuilder: (context, index) {
                    final songPath = selectedPlaylist.songPaths[index];
                    final songMeta = selectedPlaylist.songs?.firstWhere(
                      (s) => s.path == songPath,
                      orElse: () => SongMetadata(path: songPath),
                    );

                    final isLastPlayed =
                        (playerState.currentSongPath == songPath) ||
                        (playerState.currentSongPath == null &&
                            index == selectedPlaylist.lastPlayedIndex);

                    return ListTile(
                      title: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Text(
                          songMeta?.title ?? p.basename(songPath),
                          style: TextStyle(
                            fontWeight: isLastPlayed
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                      subtitle: Text(
                        songMeta?.artist ?? "Unknown Artist",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      leading: Icon(
                        Icons.music_note,
                        color: isLastPlayed
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                      selected: isLastPlayed,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            PlaylistsNotifier.formatDuration(
                              songMeta?.durationMs,
                            ),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: () {
                              ref
                                  .read(playlistsProvider.notifier)
                                  .removeSongFromPlaylist(
                                    selectedPlaylist,
                                    index,
                                  );
                            },
                          ),
                        ],
                      ),
                      onTap: () {
                        ref
                            .read(playlistsProvider.notifier)
                            .setLastPlayed(selectedPlaylist, index);

                        ref
                            .read(playerProvider.notifier)
                            .playPlaylist(
                              selectedPlaylist,
                              initialIndex: index,
                            );
                      },
                      onLongPress: () {
                        ref
                            .read(playerProvider.notifier)
                            .playNext(songPath, selectedPlaylist);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              "Queueing next: ${songMeta?.title ?? p.basename(songPath)}",
                            ),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _showCreatePlaylistDialog(BuildContext context) {
    final TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("New Playlist"),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: "Playlist Name",
              hintText: "My Awesome Jams",
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Cancel"),
            ),
            FilledButton(
              onPressed: () {
                final name = controller.text.trim();
                if (name.isNotEmpty) {
                  ref.read(playlistsProvider.notifier).createPlaylist(name);
                  Navigator.of(context).pop();
                }
              },
              child: const Text("Create"),
            ),
          ],
        );
      },
    );
  }

  Future<bool?> _confirmDeletePlaylist(
    BuildContext context,
    Playlist playlist,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Delete Playlist"),
          content: Text("Are you sure you want to delete '${playlist.name}'?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text("Cancel"),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text("Delete"),
            ),
          ],
        );
      },
    );
  }
}
