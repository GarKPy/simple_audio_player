import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:simple_player/providers/app_providers.dart';
import 'package:simple_player/providers/file_browser_provider.dart';
import 'package:simple_player/models/playlist.dart';
import 'package:path/path.dart' as p;

class FileBrowserWidget extends ConsumerStatefulWidget {
  const FileBrowserWidget({super.key});

  @override
  ConsumerState<FileBrowserWidget> createState() => _FileBrowserWidgetState();
}

class _FileBrowserWidgetState extends ConsumerState<FileBrowserWidget> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final state = ref.read(fileBrowserProvider);
    final path = state.isRootScreen ? "root" : state.currentPath;
    if (path.isNotEmpty) {
      ref
          .read(fileBrowserProvider.notifier)
          .setScrollPosition(path, _scrollController.offset);
    }
  }

  void _scrollToCurrentTrack(String? currentPath, List<FileBrowserItem> items) {
    if (currentPath == null || !_scrollController.hasClients) return;

    final index = items.indexWhere((item) => item.path == currentPath);
    if (index != -1) {
      // Small delay to ensure the list is built
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollController.hasClients) return;
        final position = index * 50.0; // Estimate tile height
        final maxScroll = _scrollController.position.maxScrollExtent;
        _scrollController.animateTo(
          position.clamp(0.0, maxScroll),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(fileBrowserProvider);
    final notifier = ref.read(fileBrowserProvider.notifier);

    final pinned = ref.watch(pinnedFoldersProvider);
    final pinnedNotifier = ref.read(pinnedFoldersProvider.notifier);

    final playerState = ref.watch(playerProvider);

    // Listen for track changes to auto-scroll
    ref.listen(playerProvider.select((s) => s.currentSongPath), (prev, next) {
      if (next != null) {
        _scrollToCurrentTrack(next, state.items);
      }
    });

    // Listen for folder changes to restore scroll position
    ref.listen(fileBrowserProvider.select((s) => s.isLoading), (prev, next) {
      if (prev == true && next == false) {
        // isLoading finished
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_scrollController.hasClients) return;
          final currentState = ref.read(fileBrowserProvider);
          final path = currentState.isRootScreen
              ? "root"
              : currentState.currentPath;
          final savedOffset = currentState.scrollPositions[path];
          if (savedOffset != null) {
            _scrollController.jumpTo(savedOffset);
          } else {
            _scrollController.jumpTo(0.0);
          }
        });
      }
    });

    return Column(
      children: [
        _PathBar(state: state, notifier: notifier),
        Divider(
          color: Theme.of(context).colorScheme.primary,
          thickness: 2,
          height: 2,
        ),
        Expanded(
          child: _buildBody(
            context,
            state,
            notifier,
            pinned,
            pinnedNotifier,
            playerState,
          ),
        ),
      ],
    );
  }

  Widget _buildBody(
    BuildContext context,
    FileBrowserState state,
    FileBrowserNotifier notifier,
    List<String> pinned,
    PinnedFoldersNotifier pinnedNotifier,
    PlayerMetadata playerState,
  ) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Error: ${state.error}",
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: notifier.goBack,
                child: const Text("Go Back"),
              ),
            ],
          ),
        ),
      );
    }

    if (state.items.isEmpty) {
      return const Center(child: Text("Folder is empty or access denied"));
    }

    return ListView.builder(
      controller: _scrollController,
      itemCount: state.items.length,
      itemBuilder: (context, index) {
        final item = state.items[index];
        final playlistsNotifier = ref.read(playlistsProvider.notifier);
        final isPlaying = playerState.currentSongPath == item.path;

        return ListTile(
          isThreeLine: false,
          selected: isPlaying,
          leading: Icon(
            item.isDirectory
                ? Icons.folder
                : (isPlaying ? Icons.music_note : Icons.music_note_outlined),
            color: item.isDirectory
                ? Colors.amber
                : (isPlaying
                      ? Theme.of(context).colorScheme.primary
                      : Colors.blue),
          ),
          title: item.isDirectory
              ? Text(
                  item.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: isPlaying ? FontWeight.bold : FontWeight.normal,
                  ),
                )
              : SizedBox(
                  height: 40, // Reduced height for single line scrolling
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Center(
                      child: Text(
                        item.name,
                        style: TextStyle(
                          fontWeight: isPlaying
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!item.isDirectory)
                FutureBuilder<Duration?>(
                  future: playlistsNotifier.getCachedDuration(item.path),
                  builder: (context, snapshot) {
                    if (snapshot.hasData && snapshot.data != null) {
                      return Text(
                        PlaylistsNotifier.formatDuration(
                          snapshot.data!.inMilliseconds,
                        ),
                        style: Theme.of(context).textTheme.bodySmall,
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              if (!item.isDirectory) const SizedBox(width: 2),
              IconButton(
                icon: Icon(
                  item.isDirectory
                      ? (pinned.contains(item.path)
                            ? Icons.push_pin
                            : Icons.push_pin_outlined)
                      : Icons.playlist_add,
                ),
                onPressed: item.isDirectory
                    ? () => pinnedNotifier.toggle(item.path)
                    : () => _addFileToPlaylist(context, ref, item),
              ),
            ],
          ),
          onLongPress: item.isDirectory
              ? () async {
                  final playlistName = item.name;
                  final playlistsNotifier = ref.read(
                    playlistsProvider.notifier,
                  );

                  // Scan for files
                  try {
                    final dir = Directory(item.path);
                    final entities = await dir.list().toList();
                    final audioExtensions = {
                      '.mp3',
                      '.wav',
                      '.flac',
                      '.m4a',
                      '.aac',
                      '.ogg',
                      '.opus',
                    };

                    final audioPaths = entities
                        .whereType<File>()
                        .where(
                          (e) => audioExtensions.contains(
                            p.extension(e.path).toLowerCase(),
                          ),
                        )
                        .map((e) => e.path)
                        .toList();

                    if (audioPaths.isNotEmpty) {
                      // Create playlist (safe to call if exists, handled by provider)
                      await playlistsNotifier.createPlaylist(playlistName);

                      final playlists = ref.read(playlistsProvider);
                      final playlist = playlists.firstWhere(
                        (p) => p.name == playlistName,
                        orElse: () =>
                            throw Exception("Playlist creation failed"),
                      );

                      await playlistsNotifier.addSongsToPlaylist(
                        playlist,
                        audioPaths,
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              "Created playlist '$playlistName' with ${audioPaths.length} songs",
                            ),
                          ),
                        );
                      }
                    } else {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              "No audio files found in folder. \nPlaylist not created.",
                            ),
                          ),
                        );
                      }
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Error scanning folder: $e")),
                      );
                    }
                  }
                }
              : () {
                  final audioItems = state.items
                      .where((i) => !i.isDirectory)
                      .toList();
                  final audioPaths = audioItems.map((i) => i.path).toList();

                  final tempPlaylist = Playlist(
                    name: "Folder: ${p.basename(state.currentPath)}",
                    songPaths: audioPaths,
                  );

                  ref
                      .read(playerProvider.notifier)
                      .playNext(item.path, tempPlaylist);

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Queueing next: ${item.name}"),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
          onTap: () {
            if (item.isDirectory) {
              notifier.navigateTo(item.path);
            } else {
              // Get all audio files from current state to create a temporary playlist
              final audioItems = state.items
                  .where((i) => !i.isDirectory)
                  .toList();
              final audioPaths = audioItems.map((i) => i.path).toList();
              final currentIndex = audioPaths.indexOf(item.path);

              if (currentIndex != -1) {
                final tempPlaylist = Playlist(
                  name: "Folder: ${p.basename(state.currentPath)}",
                  songPaths: audioPaths,
                );

                ref
                    .read(playerProvider.notifier)
                    .playPlaylist(tempPlaylist, initialIndex: currentIndex);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      "Playing folder: ${p.basename(state.currentPath)}",
                    ),
                    duration: const Duration(seconds: 1),
                  ),
                );
              }
            }
          },
        );
      },
    );
  }

  Future<void> _addFileToPlaylist(
    BuildContext context,
    WidgetRef ref,
    FileBrowserItem item,
  ) async {
    final playlists = ref.read(playlistsProvider);
    final notifier = ref.read(playlistsProvider.notifier);

    if (playlists.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("No playlists available")));
      }
      return;
    }

    if (playlists.length == 1) {
      await notifier.addSongsToPlaylist(playlists.first, [item.path]);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Added '${item.name}' to ${playlists.first.name}"),
          ),
        );
      }
      return;
    }

    // Multiple playlists
    if (context.mounted) {
      showDialog(
        context: context,
        builder: (context) => SimpleDialog(
          title: const Text("Select Playlist"),
          children: playlists
              .map(
                (p) => SimpleDialogOption(
                  child: Text(p.name),
                  onPressed: () {
                    notifier.addSongsToPlaylist(p, [item.path]);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("Added '${item.name}' to ${p.name}"),
                        ),
                      );
                    }
                    Navigator.pop(context);
                  },
                ),
              )
              .toList(),
        ),
      );
    }
  }
}

class _PathBar extends StatelessWidget {
  final FileBrowserState state;
  final FileBrowserNotifier notifier;

  const _PathBar({required this.state, required this.notifier});

  @override
  Widget build(BuildContext context) {
    String pathText = "Select Storage";
    IconData? icon;

    if (!state.isRootScreen) {
      if (state.storages.isNotEmpty) {
        icon = state.rootPath == "/storage/emulated/0"
            ? Icons.phone_android_sharp
            : Icons.sd_card_sharp;

        final relative = p.relative(state.currentPath, from: state.rootPath);
        pathText = relative == "." ? "" : "/ $relative";
      }
    }

    Widget pathTextWidget = Row(
      children: [
        if (icon != null) Icon(icon, size: 20, color: Colors.blueGrey),
        if (icon != null) const SizedBox(width: 4),
        Text(
          pathText,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );

    return SizedBox(
      height: 50,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          InkWell(
            //splashColor: Colors.red,
            onTap: state.isRootScreen ? null : notifier.goBack,
            child: Icon(
              Icons.arrow_upward,
              size: 40,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: pathTextWidget,
            ),
          ),
        ],
      ),
    );
  }
}
