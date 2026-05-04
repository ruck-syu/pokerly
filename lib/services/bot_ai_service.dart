import 'dart:math';

import '../game/hand_evaluator.dart';
import '../game/poker_engine.dart';
import '../models/game_state.dart';
import '../models/hand_rank.dart';

enum BotPersonality { tightPassive, balanced, looseAggressive, bluffHeavy }

enum _PositionBucket { early, middle, late }

enum _HandTier { weak, medium, strong }

class BotAiService {
  BotAiService({Random? random}) : _random = random ?? Random();

  final Random _random;
  final Map<String, _PlayerTendency> _tendencies = {};

  PlayerAction decideAction(GameState state, int playerIndex) {
    final player = state.players[playerIndex];
    final profile = _profileForLevel(player.aiLevel);
    final toCall = state.currentBet - player.currentBet;
    final strength = _estimateStrength(state, playerIndex);
    final tier = _tierFromStrength(strength);
    final position = _positionBucket(state, playerIndex);
    final opponentAdjustment = _opponentAggressionAdjustment(state, playerIndex);
    final stackRatio = player.chips / (state.bigBlind * 20);
    final bluffChance = _bluffChance(
      profile: profile,
      position: position,
      stackRatio: stackRatio,
      toCall: toCall,
      opponentAdjustment: opponentAdjustment,
    );
    final isBluff = _random.nextDouble() < bluffChance && tier != _HandTier.strong;

    if (toCall <= 0) {
      return _decideNoBet(
        state: state,
        playerIndex: playerIndex,
        profile: profile,
        tier: tier,
        strength: strength,
        isBluff: isBluff,
        opponentAdjustment: opponentAdjustment,
      );
    }

    return _decideFacingBet(
      state: state,
      playerIndex: playerIndex,
      profile: profile,
      tier: tier,
      strength: strength,
      isBluff: isBluff,
      opponentAdjustment: opponentAdjustment,
    );
  }

  Duration thinkDelayFor(GameState state, int playerIndex) {
    final player = state.players[playerIndex];
    final profile = _profileForLevel(player.aiLevel);
    final base = switch (profile.personality) {
      BotPersonality.tightPassive => 1200,
      BotPersonality.balanced => 1100,
      BotPersonality.looseAggressive => 900,
      BotPersonality.bluffHeavy => 1000,
    };
    final spread = 800;
    return Duration(milliseconds: base + _random.nextInt(spread) - 150);
  }

  void observeAction(String playerId, String actionText) {
    if (actionText.isEmpty) return;
    final tendency = _tendencies.putIfAbsent(playerId, _PlayerTendency.new);
    tendency.actions++;
    if (actionText.startsWith('Raise')) {
      tendency.raises++;
    } else if (actionText.startsWith('Fold')) {
      tendency.folds++;
    }
  }

  void resetMemory() {
    _tendencies.clear();
  }

  PlayerAction _decideNoBet({
    required GameState state,
    required int playerIndex,
    required _BotProfile profile,
    required _HandTier tier,
    required double strength,
    required bool isBluff,
    required double opponentAdjustment,
  }) {
    var raiseWeight = 0.05 + profile.aggression * 0.45 + strength * 0.5 + opponentAdjustment;
    var checkWeight = 1.0;

    switch (tier) {
      case _HandTier.strong:
        raiseWeight += 0.75;
      case _HandTier.medium:
        raiseWeight += 0.25;
      case _HandTier.weak:
        raiseWeight -= 0.12;
    }
    if (isBluff) {
      raiseWeight += 0.35;
    }

    final choice = _weightedChoice({
      PlayerActionType.check: checkWeight,
      PlayerActionType.raise: raiseWeight,
    });
    if (choice == PlayerActionType.raise) {
      final raiseTo = _chooseRaiseTarget(
        state: state,
        playerIndex: playerIndex,
        profile: profile,
        tier: tier,
        strength: strength,
      );
      if (raiseTo != null) {
        return PlayerAction(type: PlayerActionType.raise, raiseTo: raiseTo);
      }
    }
    return const PlayerAction(type: PlayerActionType.check);
  }

  PlayerAction _decideFacingBet({
    required GameState state,
    required int playerIndex,
    required _BotProfile profile,
    required _HandTier tier,
    required double strength,
    required bool isBluff,
    required double opponentAdjustment,
  }) {
    final player = state.players[playerIndex];
    final toCall = state.currentBet - player.currentBet;
    final potOdds = toCall / (state.pot + toCall);
    final commitRatio = player.chips == 0 ? 1.0 : toCall / player.chips;
    final stackRatio = player.chips / (state.bigBlind * 20);

    var foldWeight = 0.18 + profile.tightness * 0.4 + (potOdds - strength).clamp(0, 1);
    var callWeight = 0.42 + (strength * 0.7) - (profile.tightness * 0.12);
    var raiseWeight = 0.12 + profile.aggression * 0.45 + opponentAdjustment;

    switch (tier) {
      case _HandTier.strong:
        raiseWeight += 0.85;
        callWeight += 0.35;
        foldWeight -= 0.15;
      case _HandTier.medium:
        callWeight += 0.45;
        raiseWeight += 0.2;
      case _HandTier.weak:
        foldWeight += 0.72;
        raiseWeight -= 0.16;
    }

    if (isBluff) {
      raiseWeight += 0.32;
      foldWeight -= 0.1;
    }

    // Risk management for short stacks / high commitment calls.
    if (commitRatio > 0.45 && tier == _HandTier.weak) {
      foldWeight += 1.1;
      raiseWeight = 0;
    }
    if (commitRatio > 0.65 && tier == _HandTier.medium) {
      raiseWeight *= 0.35;
    }
    if (stackRatio < 0.35 && tier != _HandTier.strong) {
      raiseWeight *= 0.4;
      foldWeight += 0.2;
    }

    final choice = _weightedChoice({
      PlayerActionType.fold: foldWeight,
      PlayerActionType.call: callWeight,
      PlayerActionType.raise: raiseWeight,
    });

    if (choice == PlayerActionType.raise) {
      final raiseTo = _chooseRaiseTarget(
        state: state,
        playerIndex: playerIndex,
        profile: profile,
        tier: tier,
        strength: strength,
      );
      if (raiseTo != null) {
        final maxReach = player.currentBet + player.chips;
        if (raiseTo >= maxReach && tier == _HandTier.weak) {
          return const PlayerAction(type: PlayerActionType.call);
        }
        return PlayerAction(type: PlayerActionType.raise, raiseTo: raiseTo);
      }
      return const PlayerAction(type: PlayerActionType.call);
    }
    if (choice == PlayerActionType.fold) {
      return const PlayerAction(type: PlayerActionType.fold);
    }
    return const PlayerAction(type: PlayerActionType.call);
  }

  int? _chooseRaiseTarget({
    required GameState state,
    required int playerIndex,
    required _BotProfile profile,
    required _HandTier tier,
    required double strength,
  }) {
    final player = state.players[playerIndex];
    final minRaiseTo = state.currentBet + state.minRaise;
    final maxRaiseTo = player.currentBet + player.chips;
    if (maxRaiseTo <= minRaiseTo) {
      return null;
    }

    final aggressionFactor = (profile.aggression + strength).clamp(0, 1);
    final raiseByBlindPart = state.minRaise * (1 + _random.nextInt(2 + (aggressionFactor * 2).round()));
    final raiseByPotPart = (state.pot * (0.08 + (aggressionFactor * 0.24))).round();
    var target = state.currentBet + raiseByBlindPart + raiseByPotPart;

    if (tier == _HandTier.weak) {
      target = state.currentBet + raiseByBlindPart;
    }
    if (tier != _HandTier.strong && target >= maxRaiseTo) {
      final softCap = player.currentBet + (player.chips * 0.72).floor();
      target = softCap;
    }

    if (target < minRaiseTo) target = minRaiseTo;
    if (target > maxRaiseTo) target = maxRaiseTo;
    return target;
  }

  _PositionBucket _positionBucket(GameState state, int playerIndex) {
    final active = <int>[];
    for (var step = 1; step <= state.players.length; step++) {
      final idx = (state.dealerIndex + step) % state.players.length;
      final p = state.players[idx];
      if (!p.hasFolded && !p.isBusted) {
        active.add(idx);
      }
    }
    if (active.length <= 2) {
      return _PositionBucket.late;
    }
    final order = active.indexOf(playerIndex);
    final ratio = order / (active.length - 1);
    if (ratio <= 0.33) return _PositionBucket.early;
    if (ratio >= 0.66) return _PositionBucket.late;
    return _PositionBucket.middle;
  }

  _HandTier _tierFromStrength(double strength) {
    if (strength >= 0.7) return _HandTier.strong;
    if (strength >= 0.42) return _HandTier.medium;
    return _HandTier.weak;
  }

  double _bluffChance({
    required _BotProfile profile,
    required _PositionBucket position,
    required double stackRatio,
    required int toCall,
    required double opponentAdjustment,
  }) {
    var chance = profile.baseBluffRate;
    if (position == _PositionBucket.late) chance += 0.04;
    if (position == _PositionBucket.early) chance -= 0.02;
    if (toCall > 0) chance -= 0.02;
    if (stackRatio < 0.3) chance -= 0.06;
    chance += opponentAdjustment * 0.25;
    return chance.clamp(0.03, 0.16);
  }

  double _opponentAggressionAdjustment(GameState state, int playerIndex) {
    final opponentRaiseRates = <double>[];
    for (var i = 0; i < state.players.length; i++) {
      if (i == playerIndex) continue;
      final tendency = _tendencies[state.players[i].id];
      if (tendency == null || tendency.actions < 3) continue;
      opponentRaiseRates.add(tendency.raiseRate);
    }
    if (opponentRaiseRates.isEmpty) return 0;
    final avg = opponentRaiseRates.reduce((a, b) => a + b) / opponentRaiseRates.length;
    if (avg > 0.34) return -0.12;
    if (avg < 0.16) return 0.08;
    return 0;
  }

  PlayerActionType _weightedChoice(Map<PlayerActionType, double> weights) {
    final cleaned = <PlayerActionType, double>{};
    for (final entry in weights.entries) {
      if (entry.value > 0) {
        cleaned[entry.key] = entry.value;
      }
    }
    if (cleaned.isEmpty) {
      return PlayerActionType.check;
    }
    final sum = cleaned.values.reduce((a, b) => a + b);
    var roll = _random.nextDouble() * sum;
    for (final entry in cleaned.entries) {
      roll -= entry.value;
      if (roll <= 0) {
        return entry.key;
      }
    }
    return cleaned.keys.first;
  }

  _BotProfile _profileForLevel(int level) {
    return switch (level) {
      1 => const _BotProfile(
          personality: BotPersonality.tightPassive,
          tightness: 0.82,
          aggression: 0.22,
          baseBluffRate: 0.05,
        ),
      3 => const _BotProfile(
          personality: BotPersonality.looseAggressive,
          tightness: 0.3,
          aggression: 0.82,
          baseBluffRate: 0.1,
        ),
      4 => const _BotProfile(
          personality: BotPersonality.bluffHeavy,
          tightness: 0.4,
          aggression: 0.6,
          baseBluffRate: 0.14,
        ),
      _ => const _BotProfile(
          personality: BotPersonality.balanced,
          tightness: 0.52,
          aggression: 0.52,
          baseBluffRate: 0.08,
        ),
    };
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

class _BotProfile {
  const _BotProfile({
    required this.personality,
    required this.tightness,
    required this.aggression,
    required this.baseBluffRate,
  });

  final BotPersonality personality;
  final double tightness;
  final double aggression;
  final double baseBluffRate;
}

class _PlayerTendency {
  int actions = 0;
  int raises = 0;
  int folds = 0;

  double get raiseRate => actions == 0 ? 0 : raises / actions;
}
