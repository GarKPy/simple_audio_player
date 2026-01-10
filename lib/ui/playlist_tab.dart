import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
import '../models/playlist.dart';
import 'package:path/path.dart' as p;

class PlaylistTab extends ConsumerStatefulWidget {
  const PlaylistTab({super.key});

  @override
  ConsumerState<PlaylistTab> createState() => _PlaylistTabState();
}

class _PlaylistTabState extends ConsumerState<PlaylistTab> {
  final ScrollController _scrollController = ScrollController();

  void _scrollToCurrentSong(List<String> songPaths) {
    // We need to know which song is currently playing and if it belongs to this playlist
    final playerState = ref.read(playerProvider);
    //print(
    //  "AutoScroll: Checking scroll. CurrentPath: ${playerState.currentSongPath}",
    //);
    // Simple check: specific file path match.
    if (playerState.currentSongPath != null) {
      final index = songPaths.indexOf(playerState.currentSongPath!);
      //print("AutoScroll: Index in playlist: $index");
      if (index != -1) {
        // Scroll to index * itemHeight. Let's estimate itemHeight ~ 72.0 (ListTile default)
        if (_scrollController.hasClients) {
          //print("AutoScroll: Animating to ${index * 65.0}");
          _scrollController.animateTo(
            index * 65.0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        } else {
          //print("AutoScroll: Controller has no clients");
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
    _scrollController.dispose();
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

      // Condition 2: Started playing (and path matches) - useful if paused on a track then resumed/started
      if (previous?.isPlaying == false && next.isPlaying == true) {
        shouldScroll = true;
      }

      if (shouldScroll) {
        //print(
        //  "AutoScroll: Triggered by listen. Path: ${next.currentSongPath}, Playing: ${next.isPlaying}",
        //);
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
                //ListView.builder(
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
                            onDismissed: (direction) {
                              ref
                                  .read(playlistsProvider.notifier)
                                  .deletePlaylist(playlist);
                              final currentIndex = ref.read(
                                selectedPlaylistIndexProvider,
                              );
                              if (currentIndex >= 1) {
                                ref
                                        .read(
                                          selectedPlaylistIndexProvider
                                              .notifier,
                                        )
                                        .state =
                                    0;
                              }
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
                                    child: Text(
                                      playlist.name,
                                      style: TextStyle(
                                        color: isSelected
                                            ? Theme.of(
                                                context,
                                              ).colorScheme.onPrimaryContainer
                                            : Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
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
                  //color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: InkWell(
                    //splashColor: Colors.red,
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
              : ListView.builder(
                  controller: _scrollController,
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
