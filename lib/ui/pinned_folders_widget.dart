import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
import 'package:path/path.dart' as p;
import '../providers/file_browser_provider.dart';

class PinnedFoldersWidget extends ConsumerWidget {
  const PinnedFoldersWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pinnedFolders = ref.watch(pinnedFoldersProvider);

    if (pinnedFolders.isEmpty) return const SizedBox.shrink();
    print("-----PinnedFoldersRow");
    return SizedBox(
      height: 60,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: pinnedFolders.length,
        itemBuilder: (context, index) {
          final folder = pinnedFolders[index];
          return GestureDetector(
            onLongPress: () =>
                ref.read(pinnedFoldersProvider.notifier).toggle(folder),
            onTap: () {
              print("Pinned tapped: $folder");
              //final notifier = ref.read(fileBrowserProvider.notifier);
              //print("notifier hash: ${notifier.hashCode}");
              //notifier.navigateTo(folder);
              ref.read(fileBrowserProvider.notifier).navigateTo(folder);
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.blueGrey.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              alignment: Alignment.center,
              child: Text(p.basename(folder)),
            ),
          );
        },
      ),
    );
  }
}
