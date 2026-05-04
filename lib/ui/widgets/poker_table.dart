import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/constants.dart' as constants;
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
        final playerCount = state.players.length;
        final seatScale = _seatScale(constraints.maxWidth, playerCount);
        final compactSeats = playerCount >= 7 || constraints.maxWidth < 720;
        final seatCardWidth = _seatCardWidth(constraints.maxWidth, playerCount);
        final seatPadding = playerCount >= 8 ? 4.0 : (playerCount >= 6 ? 6.0 : 10.0);
        final isCompact = constraints.maxWidth < 700;
        return Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF0E5B40), Color(0xFF08402E)],
                  ),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white24, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.45),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: CustomPaint(painter: _FeltTexturePainter()),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.05),
                    radius: 1.05,
                    colors: [
                      Colors.white.withValues(alpha: 0.08),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.center,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Pot \$${state.pot}',
                      style: TextStyle(
                        fontSize: isCompact ? 18 : 21,
                        fontWeight: FontWeight.w800,
                        color: constants.pokerGold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Current bet: ${state.currentBet}',
                      style: const TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      children: state.communityCards
                          .asMap()
                          .entries
                          .map(
                            (entry) => TweenAnimationBuilder<double>(
                              key: ValueKey('community_${state.handNumber}_${entry.key}_${entry.value.label}'),
                              tween: Tween(begin: 0, end: 1),
                              duration: Duration(milliseconds: 220 + (entry.key * 60)),
                              curve: Curves.easeOutCubic,
                              builder: (context, t, child) {
                                return Opacity(
                                  opacity: t,
                                  child: Transform.translate(
                                    offset: Offset(0, (1 - t) * 14),
                                    child: child,
                                  ),
                                );
                              },
                              child: PlayingCardWidget(
                                card: entry.value,
                                faceUp: true,
                                width: isCompact ? 36 : 42,
                              ),
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ],
                ),
              ),
            ),
            for (var i = 0; i < state.players.length; i++)
              Align(
                alignment: _seatAlignment(i, state.players.length),
                child: Padding(
                  padding: EdgeInsets.all(seatPadding),
                  child: PlayerSeat(
                    player: state.players[i],
                    isActive: !state.isHandComplete && state.currentTurnIndex == i,
                    faceUp: !state.players[i].isBot || state.phase == BettingRound.showdown,
                    scale: seatScale,
                    isDealer: state.dealerIndex == i,
                    compact: compactSeats,
                    cardWidth: seatCardWidth,
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
                      opacity: 1 - (_chipController.value * 0.3),
                      child: Transform.scale(
                        scale: 0.9 + (_chipController.value * 0.4),
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: constants.pokerGold,
                            border: Border.all(color: Colors.white, width: 1.6),
                          ),
                          child: const Center(
                            child: Text(
                              '5',
                              style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 11),
                            ),
                          ),
                        ),
                      ),
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

    final (radiusX, radiusY) = switch (total) {
      <= 4 => (0.93, 0.84),
      <= 6 => (0.95, 0.88),
      <= 8 => (0.97, 0.90),
      _ => (0.985, 0.93),
    };

    final angle = (pi / 2) + ((2 * pi * index) / total);
    final x = cos(angle) * radiusX;
    final y = sin(angle) * radiusY;
    return Alignment(x, y);
  }

  double _seatScale(double width, int total) {
    final widthScale = switch (width) {
      < 500 => 0.72,
      < 700 => 0.84,
      < 1024 => 0.96,
      _ => 1.0,
    };
    final countScale = switch (total) {
      <= 4 => 1.0,
      <= 6 => 0.88,
      <= 8 => 0.76,
      _ => 0.64,
    };
    return widthScale * countScale;
  }

  double _seatCardWidth(double width, int total) {
    if (total <= 4) return width < 700 ? 38 : 42;
    if (total <= 6) return width < 700 ? 32 : 36;
    if (total <= 8) return width < 700 ? 26 : 30;
    return width < 700 ? 22 : 26;
  }
}

class _FeltTexturePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.018);
    const spacing = 14.0;
    for (double y = 8; y < size.height; y += spacing) {
      for (double x = 8; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), 0.8, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
