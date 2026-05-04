import 'dart:math';

import '../game/hand_evaluator.dart';
import '../game/poker_engine.dart';
import '../models/game_state.dart';
import '../models/hand_rank.dart';

class BotAiService {
  BotAiService({Random? random}) : _random = random ?? Random();

  final Random _random;

  PlayerAction decideAction(GameState state, int playerIndex) {
    final player = state.players[playerIndex];
    final toCall = state.currentBet - player.currentBet;
    final strength = _estimateStrength(state, playerIndex);

    return player.aiLevel == 1
        ? _levelOneDecision(state: state, playerIndex: playerIndex, toCall: toCall, strength: strength)
        : _levelTwoDecision(state: state, playerIndex: playerIndex, toCall: toCall, strength: strength);
  }

  PlayerAction _levelOneDecision({
    required GameState state,
    required int playerIndex,
    required int toCall,
    required double strength,
  }) {
    final player = state.players[playerIndex];

    if (toCall == 0) {
      if (strength > 0.74 && player.chips > state.minRaise) {
        return PlayerAction(
          type: PlayerActionType.raise,
          raiseTo: state.currentBet + state.minRaise + (state.bigBlind ~/ 2),
        );
      }
      return const PlayerAction(type: PlayerActionType.check);
    }

    if (strength < 0.28 && toCall > state.bigBlind ~/ 2) {
      return const PlayerAction(type: PlayerActionType.fold);
    }
    if (strength > 0.72 && player.chips > toCall + state.minRaise) {
      return PlayerAction(
        type: PlayerActionType.raise,
        raiseTo: state.currentBet + state.minRaise,
      );
    }
    return const PlayerAction(type: PlayerActionType.call);
  }

  PlayerAction _levelTwoDecision({
    required GameState state,
    required int playerIndex,
    required int toCall,
    required double strength,
  }) {
    final bluff = _random.nextDouble();
    final raiseMultiplier = 1 + _random.nextInt(3);

    if (toCall == 0) {
      if (strength > 0.62 || bluff > 0.87) {
        final raiseBy = state.minRaise * raiseMultiplier;
        return PlayerAction(
          type: PlayerActionType.raise,
          raiseTo: state.currentBet + raiseBy,
        );
      }
      return const PlayerAction(type: PlayerActionType.check);
    }

    final potOdds = toCall / (state.pot + toCall);
    if (strength + (_random.nextDouble() * 0.1) < potOdds && bluff < 0.15) {
      return const PlayerAction(type: PlayerActionType.fold);
    }
    if (strength > 0.78 || bluff > 0.92) {
      final raiseBy = state.minRaise * raiseMultiplier;
      return PlayerAction(
        type: PlayerActionType.raise,
        raiseTo: state.currentBet + raiseBy,
      );
    }
    return const PlayerAction(type: PlayerActionType.call);
  }

  double _estimateStrength(GameState state, int playerIndex) {
    final player = state.players[playerIndex];
    final cards = [...player.holeCards, ...state.communityCards];
    if (cards.length >= 5) {
      final value = HandEvaluator.evaluateHandValue(cards);
      return _valueToStrength(value);
    }

    final ranks = player.holeCards.map((c) => c.rank.value).toList()..sort();
    if (ranks.length < 2) {
      return 0.0;
    }
    final isPair = ranks[0] == ranks[1];
    final high = ranks[1];
    final low = ranks[0];
    var score = 0.15;

    if (isPair) {
      score += 0.35 + (high / 20);
    } else {
      score += high / 25;
      if (high >= 12 && low >= 10) {
        score += 0.1;
      }
      if ((high - low).abs() <= 2) {
        score += 0.05;
      }
    }

    return score.clamp(0, 1);
  }

  double _valueToStrength(HandValue value) {
    final base = value.rank.strength / HandRank.values.length;
    final kickerBoost = value.kickers.isEmpty ? 0 : value.kickers.first / 20;
    return (base + (kickerBoost * 0.3)).clamp(0, 1);
  }
}
