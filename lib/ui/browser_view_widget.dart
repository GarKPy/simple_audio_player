import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:simple_player/ui/pinned_folders_widget.dart';
import 'package:simple_player/ui/file_browser_widget.dart';
import 'package:simple_player/providers/file_browser_provider.dart';

class BrowserView extends ConsumerWidget {
  const BrowserView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    //print("-----BrowserView");
    final browserState = ref.watch(fileBrowserProvider);

    return PopScope(
      canPop: browserState.isRootScreen,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop && !browserState.isRootScreen) {
          await ref.read(fileBrowserProvider.notifier).goBack();
        }
      },
      child: Column(
        children: [
          const PinnedFoldersWidget(),
          const Expanded(child: FileBrowserWidget()),
        ],
      ),
    );
  }
}
