import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:simple_player/ui/browser_view_widget.dart';
import 'package:simple_player/models/tab_model.dart';
import 'package:simple_player/providers/tab_provider.dart';

final List<AppTab> appTabs = [
  AppTab(name: 'Browser', icon: Icons.search, content: BrowserView()),
  AppTab(name: 'Playlist', icon: Icons.queue_music, content: PlaylistTab()),
  AppTab(name: 'Settings', icon: Icons.settings, content: SettingsTab()),
];

class TabControllerWidget extends ConsumerWidget {
  const TabControllerWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(tabProvider);
    print("-----TabControllerWidget");
    return Column(
      children: [
        // TabBar
        TabBar(
          onTap: (index) => ref.read(tabProvider.notifier).state = index,
          tabs: appTabs
              .map((tab) => Tab(text: tab.name, icon: Icon(tab.icon)))
              .toList(),
          labelColor: Colors.deepPurpleAccent,
          unselectedLabelColor: Colors.white70,
        ),
        // Tab content
        SizedBox(
          height: 400, // or wrap in Expanded depending on your layout
          child: IndexedStack(
            index: currentIndex,
            children: appTabs.map((tab) => tab.content).toList(),
          ),
        ),
      ],
    );
  }
}

// Dummy tabs

class BrowserTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(child: Text("Browser"));
}

class PlaylistTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(child: Text("Playlist"));
}

class SettingsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(child: Text("Settings"));
}
