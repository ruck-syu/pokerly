import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../game/game_controller.dart';
import '../../models/game_state.dart';
import 'result_screen.dart';
import '../widgets/poker_table.dart';

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  @override
  Widget build(BuildContext context) {
    ref.listen<GameState>(gameControllerProvider, (prev, next) async {
      if (!(prev?.isHandComplete ?? false) && next.isHandComplete) {
        final shouldContinue = await Navigator.of(context).push<bool>(
          MaterialPageRoute(builder: (_) => ResultScreen(state: next)),
        );
        if (shouldContinue == true && mounted) {
          ref.read(gameControllerProvider.notifier).nextHand();
        }
      }
    });

    final state = ref.watch(gameControllerProvider);
    final controller = ref.read(gameControllerProvider.notifier);
    final human = state.players[state.humanPlayerIndex];
    final toCall = state.currentBet - human.currentBet;
    final isHumanTurn = !state.isHandComplete && state.currentTurnIndex == state.humanPlayerIndex;

    return Scaffold(
      appBar: AppBar(
        title: Text('Texas Hold\'em - Hand ${state.handNumber}'),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(
                _phaseLabel(state.phase),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Expanded(child: PokerTable(state: state)),
            const SizedBox(height: 10),
            if (isHumanTurn)
              _ActionBar(
                canCheck: toCall == 0,
                toCall: toCall,
                maxRaiseTo: human.currentBet + human.chips,
                minRaiseTo: state.currentBet + state.minRaise,
                onFold: controller.fold,
                onCheck: controller.check,
                onCall: controller.call,
                onRaise: controller.raiseTo,
              )
            else
              SizedBox(
                height: 76,
                child: Center(
                  child: Text(
                    state.isHandComplete ? state.handMessage : '${state.currentPlayer.name} is thinking...',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _phaseLabel(BettingRound round) {
    return switch (round) {
      BettingRound.preFlop => 'Pre-flop',
      BettingRound.flop => 'Flop',
      BettingRound.turn => 'Turn',
      BettingRound.river => 'River',
      BettingRound.showdown => 'Showdown',
    };
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.canCheck,
    required this.toCall,
    required this.maxRaiseTo,
    required this.minRaiseTo,
    required this.onFold,
    required this.onCheck,
    required this.onCall,
    required this.onRaise,
  });

  final bool canCheck;
  final int toCall;
  final int maxRaiseTo;
  final int minRaiseTo;
  final VoidCallback onFold;
  final VoidCallback onCheck;
  final VoidCallback onCall;
  final void Function(int raiseTo) onRaise;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 10,
      runSpacing: 10,
      children: [
        OutlinedButton(onPressed: onFold, child: const Text('Fold')),
        FilledButton(
          onPressed: canCheck ? onCheck : onCall,
          child: Text(canCheck ? 'Check' : 'Call $toCall'),
        ),
        FilledButton.tonal(
          onPressed: maxRaiseTo <= minRaiseTo
              ? null
              : () async {
                  final raiseTo = await showModalBottomSheet<int>(
                    context: context,
                    builder: (context) {
                      var selected = minRaiseTo;
                      return StatefulBuilder(
                        builder: (context, setState) {
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text('Raise to $selected', style: Theme.of(context).textTheme.titleMedium),
                                Slider(
                                  min: minRaiseTo.toDouble(),
                                  max: maxRaiseTo.toDouble(),
                                  divisions: (maxRaiseTo - minRaiseTo).clamp(1, 100),
                                  value: selected.toDouble().clamp(minRaiseTo.toDouble(), maxRaiseTo.toDouble()),
                                  onChanged: (value) => setState(() => selected = value.round()),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.of(context).pop(selected),
                                  child: const Text('Confirm Raise'),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  );
                  if (raiseTo != null) {
                    onRaise(raiseTo);
                  }
                },
          child: const Text('Raise'),
        ),
      ],
    );
  }
}
