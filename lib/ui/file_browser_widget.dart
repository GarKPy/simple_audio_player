import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:simple_player/providers/app_providers.dart';
import 'package:simple_player/providers/file_browser_provider.dart';
import 'package:path/path.dart' as p;

class FileBrowserWidget extends ConsumerWidget {
  const FileBrowserWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(fileBrowserProvider);
    final notifier = ref.read(fileBrowserProvider.notifier);

    final pinned = ref.watch(pinnedFoldersProvider);
    final pinnedNotifier = ref.read(pinnedFoldersProvider.notifier);
    print("-----FileBrowserWidget");
    return Column(
      children: [
        _PathBar(state: state, notifier: notifier),
        Expanded(
          child: _buildBody(
            context,
            ref,
            state,
            notifier,
            pinned,
            pinnedNotifier,
          ),
        ),
      ],
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    FileBrowserState state,
    FileBrowserNotifier notifier,
    List<String> pinned,
    PinnedFoldersNotifier pinnedNotifier,
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
      itemCount: state.items.length,
      itemBuilder: (context, index) {
        final item = state.items[index];
        final playlistsNotifier = ref.read(playlistsProvider.notifier);
        final metadata = !item.isDirectory
            ? playlistsNotifier.getMetadataForPath(item.path)
            : null;

        return ListTile(
          leading: Icon(
            item.isDirectory ? Icons.folder : Icons.music_note,
            color: item.isDirectory ? Colors.amber : Colors.blue,
          ),
          title: Text(item.name),
          subtitle: metadata != null
              ? Text(
                  "${metadata.artist ?? 'Unknown Artist'} • ${PlaylistsNotifier.formatDuration(metadata.durationMs)}",
                  style: Theme.of(context).textTheme.bodySmall,
                )
              : null,
          trailing: IconButton(
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
          onLongPress: item.isDirectory
              ? () async {
                  final playlistName = item.name;
                  final playlistsNotifier = ref.read(
                    playlistsProvider.notifier,
                  );

                  // Create playlist (safe to call if exists, handled by provider)
                  await playlistsNotifier.createPlaylist(playlistName);

                  // Find the playlist object (it should be in state now)
                  // We need to re-read the provider to get the updated list?
                  // createPlaylist updates state.
                  final playlists = ref.read(playlistsProvider);
                  final playlist = playlists.firstWhere(
                    (p) => p.name == playlistName,
                    orElse: () => throw Exception("Playlist creation failed"),
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
                            content: Text("No audio files found in folder"),
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
              : null,
          onTap: () {
            if (item.isDirectory) {
              notifier.navigateTo(item.path);
            } else {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text("Playing: ${item.name}")));
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
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_upward),
            onPressed: state.isRootScreen ? null : notifier.goBack,
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
