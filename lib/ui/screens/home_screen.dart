import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart' as constants;
import '../../game/game_controller.dart';
import 'game_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _botCount = constants.maxBots;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 700;

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Pokerly',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Offline Texas Hold\'em with bots',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    DropdownButtonFormField<int>(
                      initialValue: _botCount,
                      decoration: const InputDecoration(
                        labelText: 'Bot count',
                        border: OutlineInputBorder(),
                      ),
                      items: List<int>.generate(
                        constants.maxBots - constants.minBots + 1,
                        (i) => constants.minBots + i,
                      )
                          .map((count) => DropdownMenuItem(value: count, child: Text('$count bots')))
                          .toList(growable: false),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _botCount = value);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () {
                        ref.read(gameControllerProvider.notifier).startGame(botCount: _botCount);
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const GameScreen()),
                        );
                      },
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: compact ? 10 : 14),
                        child: const Text('Start Game'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
