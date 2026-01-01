import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
import 'package:path/path.dart' as p;

class PlaylistTab extends ConsumerStatefulWidget {
  const PlaylistTab({super.key});

  @override
  ConsumerState<PlaylistTab> createState() => _PlaylistTabState();
}

class _PlaylistTabState extends ConsumerState<PlaylistTab> {
  int _selectedPlaylistIndex = 0;

  @override
  Widget build(BuildContext context) {
    print("PlaylistTab: build called");
    final playlists = ref.watch(playlistsProvider);
    print("PlaylistTab: playlists count: ${playlists.length}");

    // Safety check if playlists is empty (shouldn't be, due to init)
    if (playlists.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    // Ensure index is valid
    if (_selectedPlaylistIndex >= playlists.length) {
      _selectedPlaylistIndex = 0;
    }

    final selectedPlaylist = playlists[_selectedPlaylistIndex];

    // return Center(
    //   child: Text("Playlist Tab Debug: ${playlists.length} playlists"),
    // );

    return Column(
      children: [
        // Horizontal Playlists + Add Button
        Container(
          height: 60,
          color: Theme.of(context).colorScheme.surface,
          child: Row(
            children: [
              Expanded(
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: playlists.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final playlist = playlists[index];
                    final isSelected = index == _selectedPlaylistIndex;
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: Material(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primaryContainer
                              : Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(20),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () {
                              setState(() {
                                _selectedPlaylistIndex = index;
                              });
                            },
                            onLongPress: () {
                              if (playlist.name == 'Favorites') return;
                              _confirmDeletePlaylist(context, playlist);
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12.0,
                                vertical: 8.0,
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
                    );
                  },
                ),
              ),
              const VerticalDivider(width: 1),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () => _showCreatePlaylistDialog(context),
                tooltip: "Create Playlist",
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
        const Divider(height: 1),

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
                  itemCount: selectedPlaylist.songPaths.length,
                  itemBuilder: (context, index) {
                    final songPath = selectedPlaylist.songPaths[index];
                    final isLastPlayed =
                        index == selectedPlaylist.lastPlayedIndex;

                    return ListTile(
                      title: Text(p.basename(songPath)),
                      subtitle: Text(songPath),
                      leading: Icon(
                        Icons.music_note,
                        color: isLastPlayed
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                      selected: isLastPlayed,
                      trailing: IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: () {
                          ref
                              .read(playlistsProvider.notifier)
                              .removeSongFromPlaylist(selectedPlaylist, index);
                        },
                      ),
                      onTap: () {
                        ref
                            .read(playlistsProvider.notifier)
                            .setLastPlayed(selectedPlaylist, index);

                        ref
                            .read(playerProvider.notifier)
                            .play(songPath, title: p.basename(songPath));
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

  void _confirmDeletePlaylist(BuildContext context, dynamic playlist) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Delete Playlist"),
          content: Text("Are you sure you want to delete '${playlist.name}'?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Cancel"),
            ),
            FilledButton(
              onPressed: () {
                ref.read(playlistsProvider.notifier).deletePlaylist(playlist);
                if (_selectedPlaylistIndex >= 1) {
                  _selectedPlaylistIndex =
                      0; // Reset to favorites or safer index
                }
                setState(() {});
                Navigator.of(context).pop();
              },
              child: const Text("Delete"),
            ),
          ],
        );
      },
    );
  }
}
