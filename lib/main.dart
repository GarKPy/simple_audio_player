import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'models/playlist.dart';
import 'ui/main_screen.dart';
import 'package:hive_ce_flutter/adapters.dart';
import 'providers/player_provider.dart';
import 'services/audio_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  // Register adapters
  Hive.registerAdapter(PlaylistAdapter());
  Hive.registerAdapter(SongMetadataAdapter());

  await Hive.openBox<List<String>>('pinned_folders');
  await Hive.openBox<Playlist>('playlists');
  await Hive.openBox<int>('audio_durations');
  await Hive.openBox(
    'settings',
  ); // Box to store app settings like playlist order
  await Hive.openBox<double>('scroll_positions');

  // Create shared AudioPlayer instance
  final player = AudioPlayer();

  // Initialize audio service for lock screen controls
  final audioHandler = await AudioService.init(
    builder: () => SimpleAudioHandler(player),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.example.simple_player.channel.audio',
      androidNotificationChannelName: 'Audio playback',
      androidNotificationOngoing: false,
      androidNotificationIcon: 'mipmap/ic_launcher',
    ),
  );

  runApp(
    ProviderScope(
      overrides: [
        // Override both providers with the same instances
        audioPlayerProvider.overrideWithValue(player),
        audioHandlerProvider.overrideWithValue(audioHandler),
      ],
      child: const MainApp(),
    ),
  );
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
