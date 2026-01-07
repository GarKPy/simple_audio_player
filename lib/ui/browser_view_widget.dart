import 'package:flutter/material.dart';
import 'package:simple_player/ui/pinned_folders_widget.dart';
import 'package:simple_player/ui/file_browser_widget.dart';

class BrowserView extends StatelessWidget {
  const BrowserView({super.key});

  @override
  Widget build(BuildContext context) {
    print("-----BrowserView");
    return Column(
      children: [
        const PinnedFoldersWidget(),
        Divider(
          color: Theme.of(context).colorScheme.primary,
          thickness: 2,
          height: 2,
        ),
        const Expanded(child: FileBrowserWidget()),
      ],
    );
  }
}
