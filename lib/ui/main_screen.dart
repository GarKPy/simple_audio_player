import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:simple_player/ui/tabs_controller_widget.dart';
import 'widgets.dart';

class MainScreen extends ConsumerWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    print("-----MainScreen");
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
                      tabs: appTabs
                          .map(
                            (tab) => Tab(text: tab.name, icon: Icon(tab.icon)),
                          )
                          .toList(),
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

            // 2. Player Area
            const PlayerArea(),
          ],
        ),
      ),
    );
  }
}
