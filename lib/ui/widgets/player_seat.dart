import 'package:flutter/material.dart';

import '../../models/player.dart';
import 'playing_card_widget.dart';

class PlayerSeat extends StatefulWidget {
  const PlayerSeat({
    required this.player,
    required this.isActive,
    required this.faceUp,
    required this.scale,
    required this.isDealer,
    required this.compact,
    required this.cardWidth,
    super.key,
  });

  final Player player;
  final bool isActive;
  final bool faceUp;
  final double scale;
  final bool isDealer;
  final bool compact;
  final double cardWidth;

  @override
  State<PlayerSeat> createState() => _PlayerSeatState();
}

class _PlayerSeatState extends State<PlayerSeat> with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
      lowerBound: 0.96,
      upperBound: 1.02,
    );
    if (widget.isActive) {
      _pulseController.repeat(reverse: true);
    } else {
      _pulseController.value = 1;
    }
  }

  @override
  void didUpdateWidget(covariant PlayerSeat oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController
          ..stop()
          ..value = 1;
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = widget.player;
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Transform.scale(scale: widget.scale * _pulseController.value, child: child);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: EdgeInsets.all(widget.compact ? 6 : 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.62),
              Colors.black.withValues(alpha: 0.42),
            ],
          ),
          borderRadius: BorderRadius.circular(widget.compact ? 12 : 16),
          border: Border.all(
            color: widget.isActive ? const Color(0xFFD4AF37) : Colors.white24,
            width: widget.isActive ? 2.2 : 1,
          ),
          boxShadow: widget.isActive
              ? [
                  BoxShadow(
                    color: const Color(0xFFD4AF37).withValues(alpha: 0.45),
                    blurRadius: 14,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: widget.compact ? 10 : 12,
                  backgroundColor: const Color(0xFF1F3A30),
                  child: Text(
                    player.name.substring(0, 1),
                    style: TextStyle(fontSize: widget.compact ? 10 : 12),
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    player.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: widget.compact ? 11 : 14,
                    ),
                  ),
                ),
                if (widget.isDealer) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: widget.compact ? 5 : 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD4AF37),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'D',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w800,
                        fontSize: widget.compact ? 10 : 11,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            SizedBox(height: widget.compact ? 2 : 4),
            Text(
              '\$${player.chips}',
              style: TextStyle(
                fontSize: widget.compact ? 10 : 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (player.currentBet > 0)
              Container(
                margin: const EdgeInsets.only(top: 3),
                padding: EdgeInsets.symmetric(
                  horizontal: widget.compact ? 6 : 8,
                  vertical: widget.compact ? 1 : 2,
                ),
                decoration: BoxDecoration(
                  color: _chipColor(player.currentBet).withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: _chipColor(player.currentBet).withValues(alpha: 0.7)),
                ),
                child: Text(
                  widget.compact ? 'B:${player.currentBet}' : 'Bet: ${player.currentBet}',
                  style: TextStyle(
                    fontSize: widget.compact ? 10 : 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            if (!widget.compact && player.lastAction.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  player.lastAction,
                  style: const TextStyle(fontSize: 11, color: Colors.white70),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            SizedBox(height: widget.compact ? 4 : 6),
            Wrap(
              spacing: widget.compact ? 3 : 4,
              children: player.holeCards
                  .map(
                    (card) => PlayingCardWidget(
                      card: card,
                      faceUp: widget.faceUp,
                      width: widget.cardWidth,
                    ),
                  )
                  .toList(growable: false),
            ),
            if (player.hasFolded) Text('Folded', style: TextStyle(color: Colors.orangeAccent, fontSize: widget.compact ? 10 : 11)),
            if (player.isAllIn) Text('All-in', style: TextStyle(color: Colors.cyanAccent, fontSize: widget.compact ? 10 : 11)),
            if (player.isBusted) Text('Busted', style: TextStyle(color: Colors.redAccent, fontSize: widget.compact ? 10 : 11)),
          ],
        ),
      ),
    );
  }

  Color _chipColor(int bet) {
    if (bet >= 500) return const Color(0xFF8E24AA);
    if (bet >= 250) return const Color(0xFFD32F2F);
    if (bet >= 100) return const Color(0xFF1565C0);
    return const Color(0xFF2E7D32);
  }
}
