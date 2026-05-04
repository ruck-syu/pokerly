import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../models/game_state.dart';

class ResultScreen extends StatelessWidget {
  const ResultScreen({required this.state, super.key});

  final GameState state;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hand Result')),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0A2119), Color(0xFF050E0A)],
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        state.handMessage,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(color: pokerGold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 14),
                      ...state.showdownValues.entries.map((entry) {
                        final player = state.players[entry.key];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: ListTile(
                            dense: true,
                            title: Text(player.name),
                            trailing: Text(entry.value.describe()),
                          ),
                        );
                      }),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('Next Hand'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
