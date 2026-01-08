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
    return Container(
      height: 50,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemCount: pinnedFolders.length,
        itemBuilder: (context, index) {
          final folder = pinnedFolders[index];
          return Center(
            child: Material(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              elevation: 5,
              surfaceTintColor: Theme.of(context).colorScheme.primary,

              child: Ink(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: const Color.fromARGB(
                      255,
                      32,
                      255,
                      244,
                    ).withValues(alpha: 1),
                    width: 2,
                  ),
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  boxShadow: [
                    BoxShadow(
                      color: const Color.fromARGB(
                        255,
                        32,
                        255,
                        244,
                      ).withValues(alpha: 0.2),
                      blurRadius: 2,
                      offset: const Offset(3, 3),
                    ),
                  ],
                ),
                child: InkWell(
                  onLongPress: () =>
                      ref.read(pinnedFoldersProvider.notifier).toggle(folder),
                  onTap: () {
                    ref.read(fileBrowserProvider.notifier).navigateTo(folder);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8.0,
                      vertical: 2.0,
                    ),
                    child: Text(
                      p.basename(folder),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
