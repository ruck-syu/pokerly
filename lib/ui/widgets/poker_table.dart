import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../models/game_state.dart';
import 'player_seat.dart';
import 'playing_card_widget.dart';

class PokerTable extends StatefulWidget {
  const PokerTable({required this.state, super.key});

  final GameState state;

  @override
  State<PokerTable> createState() => _PokerTableState();
}

class _PokerTableState extends State<PokerTable> with SingleTickerProviderStateMixin {
  late final AnimationController _chipController;
  late Animation<Alignment> _chipAlignment;
  bool _showChip = false;
  int _lastPot = 0;

  @override
  void initState() {
    super.initState();
    _chipController = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
    _chipAlignment = AlignmentTween(
      begin: Alignment.center,
      end: Alignment.center,
    ).animate(CurvedAnimation(parent: _chipController, curve: Curves.easeOutCubic));
    _lastPot = widget.state.pot;
  }

  @override
  void didUpdateWidget(covariant PokerTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state.pot != _lastPot && widget.state.lastChipSourceIndex != null) {
      final begin = _seatAlignment(widget.state.lastChipSourceIndex!, widget.state.players.length);
      _chipAlignment = AlignmentTween(
        begin: begin,
        end: Alignment.center,
      ).animate(CurvedAnimation(parent: _chipController, curve: Curves.easeOutCubic));
      _showChip = true;
      _chipController.forward(from: 0).whenComplete(() {
        if (mounted) {
          setState(() => _showChip = false);
        }
      });
      _lastPot = widget.state.pot;
    }
  }

  @override
  void dispose() {
    _chipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    return LayoutBuilder(
      builder: (context, constraints) {
        final seatScale = constraints.maxWidth < 700 ? 0.9 : 1.0;
        return Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: tableGreen,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Colors.white24, width: 2),
                ),
              ),
            ),
            Align(
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Pot: \$${state.pot}',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    children: state.communityCards
                        .map(
                          (card) => TweenAnimationBuilder<double>(
                            key: ValueKey('community_${state.handNumber}_${card.label}'),
                            tween: Tween(begin: 0.6, end: 1),
                            duration: const Duration(milliseconds: 250),
                            builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
                            child: PlayingCardWidget(
                              card: card,
                              faceUp: true,
                              width: constraints.maxWidth < 700 ? 36 : 42,
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ],
              ),
            ),
            for (var i = 0; i < state.players.length; i++)
              Align(
                alignment: _seatAlignment(i, state.players.length),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: PlayerSeat(
                    player: state.players[i],
                    isActive: !state.isHandComplete && state.currentTurnIndex == i,
                    faceUp: !state.players[i].isBot || state.phase == BettingRound.showdown,
                    scale: seatScale,
                  ),
                ),
              ),
            if (_showChip)
              AnimatedBuilder(
                animation: _chipController,
                builder: (context, _) {
                  return Align(
                    alignment: _chipAlignment.value,
                    child: Opacity(
                      opacity: 1 - _chipController.value,
                      child: const Icon(Icons.monetization_on, color: Colors.amber, size: 28),
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }

  Alignment _seatAlignment(int index, int total) {
    if (total == 1) {
      return const Alignment(0, 0.85);
    }
    final angle = (pi / 2) + ((2 * pi * index) / total);
    final x = cos(angle) * 0.82;
    final y = sin(angle) * 0.78;
    return Alignment(x, y);
  }
}
