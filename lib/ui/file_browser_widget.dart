import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/file_browser_provider.dart';
import '../providers/app_providers.dart';
import 'package:path/path.dart' as p;

class FileBrowserWidget extends ConsumerWidget {
  const FileBrowserWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(fileBrowserProvider);
    final notifier = ref.read(fileBrowserProvider.notifier);
    final pinned = ref.watch(pinnedFoldersProvider);
    final pinnedNotifier = ref.read(pinnedFoldersProvider.notifier);

    print("FileBrowserWidget");

    return Column(
      children: [
        _BrowserTopBar(state: state, notifier: notifier),
        Expanded(
          child: state.isLoading
              ? const Center(child: CircularProgressIndicator())
              : state.error != null
              ? Center(child: Text(state.error!))
              : ListView.builder(
                  itemCount: state.items.length,
                  itemBuilder: (context, index) {
                    final item = state.items[index];
                    return ListTile(
                      leading: Icon(
                        item.isDirectory ? Icons.folder : Icons.music_note,
                        color: item.isDirectory ? Colors.amber : Colors.blue,
                      ),
                      title: Text(item.name),
                      trailing: item.isDirectory
                          ? IconButton(
                              icon: const Icon(Icons.push_pin_outlined),
                              onPressed: () {
                                print(
                                  "------------Pinned folder added ${item.path}",
                                );
                                //pinnedNotifier.addFolder(item.path, item.name);
                              },
                            )
                          : null,
                      onTap: () {
                        if (item.isDirectory) {
                          notifier.navigateTo(item.path);
                        } else {
                          ref
                              .read(playerProvider.notifier)
                              .play(item.path, title: item.name);
                        }
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _BrowserTopBar extends StatelessWidget {
  final FileBrowserState state;
  final FileBrowserNotifier notifier;

  const _BrowserTopBar({required this.state, required this.notifier});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      color: Colors.black12,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_upward),
            onPressed: () {
              print("BACK PRESSED");
              state.isRootScreen ? null : notifier.goBack;
            },
          ),
          Expanded(
            child: Text(
              state.isRootScreen ? "Select Storage" : state.currentPath,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
