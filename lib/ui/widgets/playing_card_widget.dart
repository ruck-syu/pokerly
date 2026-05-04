import 'package:flutter/material.dart' hide Card;

import '../../models/card.dart';

class PlayingCardWidget extends StatelessWidget {
  const PlayingCardWidget({
    required this.card,
    required this.faceUp,
    this.width = 42,
    super.key,
  });

  final Card card;
  final bool faceUp;
  final double width;

  @override
  Widget build(BuildContext context) {
    final height = width * 1.4;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
      child: faceUp
          ? Container(
              key: ValueKey('up_${card.label}'),
              width: width,
              height: height,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.black12),
              ),
              child: Text(
                card.label,
                style: TextStyle(
                  color: card.isRed ? Colors.red : Colors.black,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          : Container(
              key: const ValueKey('down'),
              width: width,
              height: height,
              decoration: BoxDecoration(
                color: const Color(0xFF203A87),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white70),
              ),
              child: const Center(
                child: Icon(Icons.casino, color: Colors.white70, size: 18),
              ),
            ),
    );
  }
}
