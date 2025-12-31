import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
import 'widgets.dart';
import '../models/playlist.dart';
//import 'package:simple_player/ui/file_browser_widget.dart';
import 'package:simple_player/file_browser.dart';

class MainScreen extends ConsumerWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTab = ref.watch(tabProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // 1. Tabs Area
            const TabsArea(),

            // 2. Custom Widgets Area
            Expanded(child: _buildCurrentTab(currentTab)),

            // 3. Player Area
            const PlayerArea(),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentTab(AppTab tab) {
    switch (tab) {
      case AppTab.browser:
        return const BrowserView();
      case AppTab.playlist:
        return const Center(child: Text("Playlist View"));
      case AppTab.settings:
        return const Center(child: Text("Settings View"));
    }
  }
}

class TabsArea extends ConsumerWidget {
  const TabsArea({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTab = ref.watch(tabProvider);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      color: Theme.of(context).colorScheme.surfaceVariant,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _TabItem(
            label: "Browser",
            isSelected: currentTab == AppTab.browser,
            onTap: () => ref.read(tabProvider.notifier).state = AppTab.browser,
          ),
          _TabItem(
            label: "Playlist",
            isSelected: currentTab == AppTab.playlist,
            onTap: () => ref.read(tabProvider.notifier).state = AppTab.playlist,
          ),
          _TabItem(
            label: "Settings",
            isSelected: currentTab == AppTab.settings,
            onTap: () => ref.read(tabProvider.notifier).state = AppTab.settings,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              // TODO: Add custom playlist
            },
          ),
        ],
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabItem({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Colors.blue : null,
            ),
          ),
          if (isSelected)
            Container(
              margin: const EdgeInsets.only(top: 2),
              height: 2,
              width: 20,
              color: Colors.blue,
            ),
        ],
      ),
    );
  }
}

class BrowserView extends StatelessWidget {
  const BrowserView({super.key});

  @override
  Widget build(BuildContext context) {
    //print("BrowserView");
    return Column(
      children: [
        const PinnedFoldersRow(),
        const Expanded(child: FileBrowserWidget()),
      ],
    );
  }
}
