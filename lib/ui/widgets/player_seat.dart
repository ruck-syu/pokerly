import 'package:flutter/material.dart';

import '../../models/player.dart';
import 'playing_card_widget.dart';

class PlayerSeat extends StatelessWidget {
  const PlayerSeat({
    required this.player,
    required this.isActive,
    required this.faceUp,
    required this.scale,
    super.key,
  });

  final Player player;
  final bool isActive;
  final bool faceUp;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? Colors.amberAccent : Colors.white24,
          width: isActive ? 2 : 1,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: Colors.amber.withValues(alpha: 0.5),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Transform.scale(
        scale: scale,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              player.name,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            Text('\$${player.chips}', style: const TextStyle(fontSize: 12)),
            if (player.currentBet > 0) Text('Bet: ${player.currentBet}', style: const TextStyle(fontSize: 11)),
            if (player.lastAction.isNotEmpty) Text(player.lastAction, style: const TextStyle(fontSize: 11, color: Colors.white70)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              children: player.holeCards
                  .map(
                    (card) => AnimatedScale(
                      duration: const Duration(milliseconds: 250),
                      scale: 1,
                      child: PlayingCardWidget(card: card, faceUp: faceUp),
                    ),
                  )
                  .toList(growable: false),
            ),
            if (player.hasFolded) const Text('Folded', style: TextStyle(color: Colors.orangeAccent, fontSize: 11)),
            if (player.isAllIn) const Text('All-in', style: TextStyle(color: Colors.cyanAccent, fontSize: 11)),
            if (player.isBusted) const Text('Busted', style: TextStyle(color: Colors.redAccent, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
