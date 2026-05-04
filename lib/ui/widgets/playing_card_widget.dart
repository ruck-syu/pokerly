import 'dart:math' as math;

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
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 250),
      builder: (context, t, child) {
        final dy = (1 - t) * 12;
        return Opacity(
          opacity: t,
          child: Transform.translate(offset: Offset(0, dy), child: child),
        );
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        transitionBuilder: (child, animation) {
          return AnimatedBuilder(
            animation: animation,
            child: child,
            builder: (context, builtChild) {
              final rotation = (1 - animation.value) * math.pi;
              return Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateY(rotation),
                child: builtChild,
              );
            },
          );
        },
        child: faceUp ? _FrontCard(card: card, width: width, height: height) : _BackCard(width: width, height: height),
      ),
    );
  }
}

class _FrontCard extends StatelessWidget {
  const _FrontCard({required this.card, required this.width, required this.height});

  final Card card;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final color = card.isRed ? const Color(0xFFB71C1C) : const Color(0xFF101010);
    return Container(
      key: ValueKey('up_${card.label}'),
      width: width,
      height: height,
      padding: EdgeInsets.all(width * 0.1),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFFFFFFF), Color(0xFFF1F3F4)]),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: Colors.black12),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Stack(
        children: [
          Align(
            alignment: Alignment.topLeft,
            child: Text(
              card.label,
              style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: width * 0.24),
            ),
          ),
          Align(
            child: Text(
              card.suitSymbol,
              style: TextStyle(color: color.withValues(alpha: 0.9), fontWeight: FontWeight.w700, fontSize: width * 0.42),
            ),
          ),
        ],
      ),
    );
  }
}

class _BackCard extends StatelessWidget {
  const _BackCard({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('down'),
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E2A59), Color(0xFF2D4AA8)],
        ),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: Colors.white70),
      ),
      child: Center(
        child: Icon(Icons.casino, color: Colors.white.withValues(alpha: 0.8), size: width * 0.44),
      ),
    );
  }
}
