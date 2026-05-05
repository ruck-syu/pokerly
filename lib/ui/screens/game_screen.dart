import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../game/game_controller.dart';
import '../../models/game_state.dart';
import '../widgets/poker_table.dart';
import 'result_screen.dart';

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  ProviderSubscription<GameState>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = ref.listenManual<GameState>(gameControllerProvider, (prev, next) async {
      _maybeShowActionFeedback(prev, next);
      if (!(prev?.isHandComplete ?? false) && next.isHandComplete && mounted) {
        final shouldContinue = await Navigator.of(context).push<bool>(
          MaterialPageRoute(builder: (_) => ResultScreen(state: next)),
        );
        if (shouldContinue == true && mounted) {
          ref.read(gameControllerProvider.notifier).nextHand();
        }
      }
    });
  }

  @override
  void dispose() {
    _subscription?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(gameControllerProvider);
    final controller = ref.read(gameControllerProvider.notifier);
    final localIndex = controller.localPlayerIndex;
    final localPlayer = state.players[localIndex];
    final toCall = state.currentBet - localPlayer.currentBet;
    final isHumanTurn = controller.canLocalPlayerAct();

    return Scaffold(
      appBar: AppBar(
        title: Text('Texas Hold\'em - Hand ${state.handNumber}'),
        actions: [
          if (state.isTournamentMode)
            Center(
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Level ${state.blindLevel} • ${state.smallBlind}/${state.bigBlind}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          Center(
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                isHumanTurn
                    ? 'Your turn'
                    : (controller.awaitingHostAck ? 'Waiting for host...' : '${state.currentPlayer.name} to act'),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _phaseLabel(state.phase),
                  style: TextStyle(fontWeight: FontWeight.w700, color: pokerGold.withValues(alpha: 0.95)),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Expanded(child: PokerTable(state: state, localPlayerIndex: localIndex)),
            const SizedBox(height: 10),
            _ActionBar(
              enabled: isHumanTurn,
              canCheck: toCall == 0,
              toCall: toCall,
              playerChips: localPlayer.chips,
              maxRaiseTo: localPlayer.currentBet + localPlayer.chips,
              minRaiseTo: state.currentBet + state.minRaise,
              onFold: () {
                HapticFeedback.selectionClick();
                controller.fold();
              },
              onCheck: () async {
                HapticFeedback.selectionClick();
                controller.check();
              },
              onCall: () async {
                final allInCall = toCall >= localPlayer.chips && localPlayer.chips > 0;
                if (allInCall) {
                  final confirmed = await _confirmAllIn(context, amount: localPlayer.chips);
                  if (!confirmed) return;
                }
                HapticFeedback.mediumImpact();
                controller.call();
              },
              onRaise: (raiseTo) async {
                final allInRaise = raiseTo >= (localPlayer.currentBet + localPlayer.chips) && localPlayer.chips > 0;
                if (allInRaise) {
                  final confirmed = await _confirmAllIn(context, amount: localPlayer.chips);
                  if (!confirmed) return;
                }
                HapticFeedback.mediumImpact();
                controller.raiseTo(raiseTo);
              },
            ),
            const SizedBox(height: 8),
            Text(
              state.isHandComplete
                  ? state.handMessage
                  : (controller.awaitingHostAck
                      ? 'Action sent. Waiting for host response...'
                      : '${state.currentPlayer.name} is thinking...'),
              style: const TextStyle(color: Colors.white70),
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

  Future<bool> _confirmAllIn(BuildContext context, {required int amount}) async {
    final decision = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirm All-in'),
          content: Text('This move commits all your remaining chips (\$$amount). Continue?'),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('All-in')),
          ],
        );
      },
    );
    return decision ?? false;
  }

  void _maybeShowActionFeedback(GameState? previous, GameState next) {
    if (!mounted || previous == null) return;
    for (var i = 0; i < next.players.length; i++) {
      final oldAction = previous.players[i].lastAction;
      final newAction = next.players[i].lastAction;
      if (newAction.isNotEmpty && newAction != oldAction) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              duration: const Duration(milliseconds: 900),
              content: Text('${next.players[i].name}: $newAction'),
            ),
          );
        break;
      }
    }
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.enabled,
    required this.canCheck,
    required this.toCall,
    required this.playerChips,
    required this.maxRaiseTo,
    required this.minRaiseTo,
    required this.onFold,
    required this.onCheck,
    required this.onCall,
    required this.onRaise,
  });

  final bool enabled;
  final bool canCheck;
  final int toCall;
  final int playerChips;
  final int maxRaiseTo;
  final int minRaiseTo;
  final VoidCallback onFold;
  final Future<void> Function() onCheck;
  final Future<void> Function() onCall;
  final Future<void> Function(int raiseTo) onRaise;

  @override
  Widget build(BuildContext context) {
    return AbsorbPointer(
      absorbing: !enabled,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: enabled ? 1 : 0.45,
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 10,
          children: [
            _AnimatedActionButton(
              onPressed: onFold,
              outlined: true,
              child: const Text('Fold'),
            ),
            _AnimatedActionButton(
              onPressed: canCheck ? onCheck : onCall,
              child: Text(canCheck ? 'Check' : 'Call $toCall'),
            ),
            _AnimatedActionButton(
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
                                    Text('Stack: $playerChips', style: const TextStyle(color: Colors.white70)),
                                    Slider(
                                      min: minRaiseTo.toDouble(),
                                      max: maxRaiseTo.toDouble(),
                                      divisions: (maxRaiseTo - minRaiseTo).clamp(1, 100),
                                      value: selected.toDouble().clamp(minRaiseTo.toDouble(), maxRaiseTo.toDouble()),
                                      onChanged: (value) => setState(() => selected = value.round()),
                                    ),
                                    FilledButton(
                                      onPressed: () => Navigator.of(context).pop(selected),
                                      child: Text(selected >= maxRaiseTo ? 'Confirm Raise (All-in)' : 'Confirm Raise'),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      );
                      if (raiseTo != null) {
                        await onRaise(raiseTo);
                      }
                    },
              child: const Text('Raise'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedActionButton extends StatefulWidget {
  const _AnimatedActionButton({
    required this.onPressed,
    required this.child,
    this.outlined = false,
  });

  final FutureOr<void> Function()? onPressed;
  final Widget child;
  final bool outlined;

  @override
  State<_AnimatedActionButton> createState() => _AnimatedActionButtonState();
}

class _AnimatedActionButtonState extends State<_AnimatedActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final callback = widget.onPressed;
    final button = widget.outlined
        ? OutlinedButton(onPressed: callback == null ? null : () => callback(), child: widget.child)
        : FilledButton(onPressed: callback == null ? null : () => callback(), child: widget.child);
    return GestureDetector(
      onTapDown: callback == null ? null : (_) => setState(() => _pressed = true),
      onTapUp: callback == null ? null : (_) => setState(() => _pressed = false),
      onTapCancel: callback == null ? null : () => setState(() => _pressed = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 90),
        scale: _pressed ? 0.97 : 1,
        child: button,
      ),
    );
  }
}
