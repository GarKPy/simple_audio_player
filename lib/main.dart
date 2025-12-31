import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
//import 'package:simple_player/file_browser.dart';
//import 'models/pinned_folder.dart';
import 'models/playlist.dart';
//import 'models/repeat_mode.dart';
import 'ui/main_screen.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:hive_ce_flutter/adapters.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  //await Hive.deleteBoxFromDisk('pinned_folders');

  // Register adapters
  //Hive.registerAdapter(PinnedFolderAdapter());
  Hive.registerAdapter(PlaylistAdapter());
  //Hive.registerAdapter(RepeatModeAdapter());

  await Hive.openBox<List<String>>('pinned_folders');

  runApp(const ProviderScope(child: MainApp()));
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Simple Player',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
      ),
      home: const MainScreen(),
    );
  }
}
