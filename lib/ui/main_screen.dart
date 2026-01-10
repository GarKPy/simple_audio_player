import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:simple_player/models/tab_model.dart';
import 'package:simple_player/ui/browser_view_widget.dart';
import 'package:simple_player/ui/playlist_tab.dart';
import 'player_area.dart';

final List<AppTab> appTabs = [
  AppTab(name: 'Browser', icon: Icons.search, content: BrowserView()),
  AppTab(
    name: 'Playlist',
    icon: Icons.queue_music,
    content: const PlaylistTab(),
  ),
  AppTab(name: 'Settings', icon: Icons.settings, content: SettingsTab()),
];

class MainScreen extends ConsumerWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    //print("-----MainScreen");
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // 1. Tabs area with DefaultTabController
            Expanded(
              child: DefaultTabController(
                length: appTabs.length,
                child: Column(
                  children: [
                    // Top tabs
                    TabBar(
                      dividerColor: Colors.transparent,
                      tabs: appTabs
                          .map(
                            (tab) => Tab(text: tab.name, icon: Icon(tab.icon)),
                          )
                          .toList(),
                    ),
                    Divider(
                      color: Theme.of(context).colorScheme.primary,
                      thickness: 2,
                      height: 2,
                    ),
                    // Tab content
                    Expanded(
                      child: TabBarView(
                        children: appTabs.map((tab) => tab.content).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Divider(
              color: Theme.of(context).colorScheme.primary,
              thickness: 2,
              height: 2,
            ),
            // 2. Player Area
            const PlayerArea(),
          ],
        ),
      ),
    );
  }
}

// Dummy tabs (Settings still dummy for now)
class BrowserTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(child: Text("Browser"));
}

class SettingsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image(
          image: AssetImage('assets/audio_player_logo.png'),
          width: 80,
          height: 80,
        ),
        Text("Made by GarK", style: TextStyle(fontWeight: FontWeight.bold)),
      ],
    ),
  );
}
