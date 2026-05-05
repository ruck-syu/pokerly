import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../game/game_controller.dart';
import '../../models/game_state.dart';

class ResultScreen extends ConsumerWidget {
  const ResultScreen({required this.state, super.key});

  final GameState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(gameControllerProvider.notifier);
    final localIndex = controller.localPlayerIndex;
    final localPlayer = state.players[localIndex];
    final canRebuy = !state.isTournamentMode && localPlayer.chips < state.initialBigBlind * 10;
    final isSittingOut = localPlayer.isSittingOut;

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
                      if (!state.isTournamentMode)
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  controller.toggleSitOut();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(isSittingOut ? 'You will return next hand' : 'You will sit out next hand')),
                                  );
                                },
                                child: Text(isSittingOut ? 'Return to Table' : 'Sit Out'),
                              ),
                            ),
                            if (canRebuy) const SizedBox(width: 8),
                            if (canRebuy)
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () {
                                    controller.rebuy(state.initialBigBlind * 100);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Rebought 100 BB')),
                                    );
                                  },
                                  child: const Text('Rebuy'),
                                ),
                              ),
                          ],
                        ),
                      if (!state.isTournamentMode) const SizedBox(height: 12),
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

