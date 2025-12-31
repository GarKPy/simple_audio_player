import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';

class PlayerArea extends ConsumerWidget {
  const PlayerArea({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        border: const Border(top: BorderSide(color: Colors.grey, width: 0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Scrolling Artist & Title
          SizedBox(
            height: 40,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Text(
                    "${playerState.artist ?? 'Artist'} - ${playerState.title ?? 'Song Title'}",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(icon: const Icon(Icons.shuffle), onPressed: () {}),
              IconButton(icon: const Icon(Icons.replay_5), onPressed: () {}),
              IconButton(
                iconSize: 48,
                icon: Icon(
                  playerState.isPlaying ? Icons.pause : Icons.play_arrow,
                ),
                onPressed: () => ref.read(playerProvider.notifier).togglePlay(),
              ),
              IconButton(icon: const Icon(Icons.forward_5), onPressed: () {}),
              _RepeatPopup(),
            ],
          ),
        ],
      ),
    );
  }
}

class _RepeatPopup extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.repeat),
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'none', child: Text('No Repeat')),
        const PopupMenuItem(value: 'one', child: Text('Repeat One')),
        const PopupMenuItem(value: 'list', child: Text('Repeat List')),
      ],
      onSelected: (value) {
        // TODO: Handle repeat mode
      },
    );
  }
}
