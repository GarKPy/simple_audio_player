import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'models/playlist.dart';
import 'ui/main_screen.dart';
import 'package:hive_ce_flutter/adapters.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  // Register adapters
  Hive.registerAdapter(PlaylistAdapter());
  Hive.registerAdapter(SongMetadataAdapter());

  await Hive.openBox<List<String>>('pinned_folders');
  await Hive.openBox<Playlist>('playlists');
  await Hive.openBox<int>('audio_durations');
  await Hive.openBox<double>('scroll_positions');

  runApp(const ProviderScope(child: MainApp()));
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Simple Player',
      theme: ThemeData(
        scaffoldBackgroundColor: const Color.fromARGB(255, 18, 127, 131),
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(255, 10, 255, 214),
          brightness: Brightness.dark,
          surfaceContainerHighest: const Color.fromARGB(255, 18, 127, 131),
        ),
      ),
      home: const MainScreen(),
    );
  }
}
