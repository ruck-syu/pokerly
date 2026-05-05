import 'dart:math';

import '../game/hand_evaluator.dart';
import '../game/poker_engine.dart';
import '../models/game_state.dart';
import '../models/hand_rank.dart';
import '../models/player.dart';

enum BotPersonality { nervous, calculated, aggressive, tiltProne }

enum _PositionBucket { early, middle, late }

enum _HandTier { weak, medium, strong }

class BotAiService {
  BotAiService({Random? random}) : _random = random ?? Random();

  final Random _random;
  final Map<String, _PlayerTendency> _tendencies = {};
  final Map<String, _BotState> _botStates = {};

  void _updateBotState(GameState state, int playerIndex) {
    final player = state.players[playerIndex];
    final bState = _botStates.putIfAbsent(player.id, () => _BotState());

    if (bState.lastHandNumber != state.handNumber) {
      if (bState.lastHandNumber != -1) {
        final chipDiff = player.chips - bState.lastChips;
        if (chipDiff > 0) {
          // Won chips
          bState.confidence = (bState.confidence + 0.2).clamp(0.0, 1.0);
          bState.tilt = (bState.tilt - 0.3).clamp(0.0, 1.0);
        } else if (chipDiff < 0) {
          // Lost chips
          final lossRatio = (-chipDiff) / max(1, bState.lastChips);
          bState.confidence = (bState.confidence - lossRatio).clamp(0.0, 1.0);
          if (lossRatio > 0.2) {
            // Big loss -> Tilt
            bState.tilt = (bState.tilt + lossRatio * 1.5).clamp(0.0, 1.0);
          }
        }
      }
      
      // Decay tilt and drift confidence to 0.5 over hands
      bState.tilt = (bState.tilt * 0.8).clamp(0.0, 1.0);
      bState.confidence = bState.confidence + (0.5 - bState.confidence) * 0.1;
      
      bState.lastHandNumber = state.handNumber;
    }
    bState.lastChips = player.chips;
  }

  PlayerAction decideAction(GameState state, int playerIndex) {
    _updateBotState(state, playerIndex);
    
    final player = state.players[playerIndex];
    final bState = _botStates[player.id]!;
    final profile = _profileForLevel(player.aiLevel);
    
    // Inconsistent play style: slightly randomize profile per decision
    final dynTightness = (profile.tightness + (_random.nextDouble() * 0.2 - 0.1)).clamp(0.0, 1.0);
    final dynAggression = (profile.aggression + (_random.nextDouble() * 0.2 - 0.1)).clamp(0.0, 1.0);
    
    final toCall = state.currentBet - player.currentBet;
    final strength = _estimateStrength(state, playerIndex);
    
    // Confidence and Tilt affect perceived strength and aggression
    var effectiveStrength = strength;
    if (bState.confidence > 0.7) effectiveStrength += 0.1;
    if (bState.confidence < 0.3) effectiveStrength -= 0.1;
    if (bState.tilt > 0.5) effectiveStrength += 0.2; // Reckless
    
    final tier = _tierFromStrength(effectiveStrength);
    final position = _positionBucket(state, playerIndex);
    final opponentAdjustment = _opponentAggressionAdjustment(state, playerIndex);
    final stackRatio = player.chips / max(1, state.bigBlind * 20);
    
    // Calculate bluff chance
    final bluffChance = _bluffChance(
      profile: profile,
      position: position,
      stackRatio: stackRatio,
      toCall: toCall,
      opponentAdjustment: opponentAdjustment,
      tilt: bState.tilt,
      confidence: bState.confidence,
    );
    
    final isBluff = _random.nextDouble() < bluffChance && tier != _HandTier.strong;

    // Slow play (check strong hands occasionally)
    bool isSlowPlay = false;
    if (tier == _HandTier.strong && position == _PositionBucket.early && _random.nextDouble() < 0.2) {
      isSlowPlay = true;
    }

    PlayerAction action;
    if (toCall <= 0) {
      action = _decideNoBet(
        state: state,
        playerIndex: playerIndex,
        profile: profile,
        tier: tier,
        strength: effectiveStrength,
        isBluff: isBluff,
        isSlowPlay: isSlowPlay,
        opponentAdjustment: opponentAdjustment,
        dynAggression: dynAggression,
        bState: bState,
      );
    } else {
      action = _decideFacingBet(
        state: state,
        playerIndex: playerIndex,
        profile: profile,
        tier: tier,
        strength: effectiveStrength,
        isBluff: isBluff,
        isSlowPlay: isSlowPlay,
        opponentAdjustment: opponentAdjustment,
        dynTightness: dynTightness,
        dynAggression: dynAggression,
        bState: bState,
      );
    }
    
    // Mistake probability (Imperfect logic)
    final mistakeChance = 0.05 + (bState.tilt * 0.1); // 5% base, up to 15% when tilted
    if (_random.nextDouble() < mistakeChance) {
      action = _makeMistake(action, toCall, player);
    }

    return action;
  }

  PlayerAction _makeMistake(PlayerAction intended, int toCall, Player player) {
    if (intended.type == PlayerActionType.fold) {
      if (player.chips > toCall) {
        return const PlayerAction(type: PlayerActionType.call); // Call when should fold
      }
    } else if (intended.type == PlayerActionType.call) {
      return const PlayerAction(type: PlayerActionType.fold); // Fold when unsure/calling
    } else if (intended.type == PlayerActionType.raise) {
      return const PlayerAction(type: PlayerActionType.call); // Miss a raise opportunity
    }
    return intended;
  }

  Duration thinkDelayFor(GameState state, int playerIndex) {
    final player = state.players[playerIndex];
    final profile = _profileForLevel(player.aiLevel);
    final toCall = state.currentBet - player.currentBet;
    final strength = _estimateStrength(state, playerIndex);
    
    bool isEasyDecision = false;
    if (strength > 0.8) isEasyDecision = true; // Monster hand
    if (toCall > player.chips * 0.5 && strength < 0.3) isEasyDecision = true; // Easy fold
    if (toCall == 0 && strength < 0.3) isEasyDecision = true; // Easy check
    
    int baseDelay;
    int spread;
    
    if (isEasyDecision) {
      baseDelay = 300;
      spread = 400;
    } else {
      baseDelay = 800;
      spread = 1200;
    }
    
    // Nervous players hesitate more
    if (profile.personality == BotPersonality.nervous) {
      baseDelay += 400;
    }
    // Aggressive/Tilted players play fast
    final bState = _botStates[player.id];
    if (profile.personality == BotPersonality.aggressive || (bState != null && bState.tilt > 0.5)) {
      baseDelay = max(100, baseDelay - 300);
    }
    
    // Snap decisions occasionally
    if (_random.nextDouble() < 0.05) {
      baseDelay = 100;
      spread = 200;
    }
    
    // Long pause occasionally
    if (_random.nextDouble() < 0.05) {
      baseDelay += 1500;
    }

    return Duration(milliseconds: baseDelay + _random.nextInt(max(1, spread)));
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
    _botStates.clear();
  }

  PlayerAction _decideNoBet({
    required GameState state,
    required int playerIndex,
    required _BotProfile profile,
    required _HandTier tier,
    required double strength,
    required bool isBluff,
    required bool isSlowPlay,
    required double opponentAdjustment,
    required double dynAggression,
    required _BotState bState,
  }) {
    if (isSlowPlay) return const PlayerAction(type: PlayerActionType.check);

    var raiseWeight = 0.05 + dynAggression * 0.45 + strength * 0.5 + opponentAdjustment;
    var checkWeight = 1.0;

    switch (tier) {
      case _HandTier.strong:
        raiseWeight += 0.75;
      case _HandTier.medium:
        raiseWeight += 0.25;
      case _HandTier.weak:
        raiseWeight -= 0.12;
    }
    if (isBluff) raiseWeight += 0.4;
    
    if (bState.confidence > 0.7) raiseWeight += 0.2;
    if (bState.tilt > 0.6) raiseWeight += 0.5;

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
        bState: bState,
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
    required bool isSlowPlay,
    required double opponentAdjustment,
    required double dynTightness,
    required double dynAggression,
    required _BotState bState,
  }) {
    final player = state.players[playerIndex];
    final toCall = state.currentBet - player.currentBet;
    final potOdds = toCall / (state.pot + toCall);
    final commitRatio = player.chips == 0 ? 1.0 : toCall / player.chips;
    final stackRatio = player.chips / max(1, state.bigBlind * 20);

    var foldWeight = 0.18 + dynTightness * 0.4 + (potOdds - strength).clamp(0, 1);
    var callWeight = 0.42 + (strength * 0.7) - (dynTightness * 0.12);
    var raiseWeight = 0.12 + dynAggression * 0.45 + opponentAdjustment;

    if (isSlowPlay && tier == _HandTier.strong) {
      return const PlayerAction(type: PlayerActionType.call);
    }

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
      raiseWeight += 0.4;
      foldWeight -= 0.2;
    }

    if (bState.confidence < 0.3) foldWeight += 0.3;
    if (bState.tilt > 0.5) {
      raiseWeight += 0.6;
      foldWeight -= 0.3;
    }

    // Encourage entering the pot pre-flop if facing only the initial big blind (limping)
    if (state.phase == BettingRound.preFlop && state.currentBet <= state.bigBlind) {
      if (tier == _HandTier.weak) {
        foldWeight *= 0.5; // Still fold absolute garbage half the time
        callWeight += 0.2;
      } else {
        foldWeight *= 0.2; // Heavily reduce fold chance for decent hands
        callWeight += 0.6; 
      }
    }

    // Risk management for short stacks / high commitment calls.
    if (commitRatio > 0.45 && tier == _HandTier.weak && bState.tilt < 0.8) {
      foldWeight += 1.5;
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
        bState: bState,
      );
      if (raiseTo != null) {
        final maxReach = player.currentBet + player.chips;
        if (raiseTo >= maxReach && tier == _HandTier.weak && !isBluff) {
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
    required _BotState bState,
  }) {
    final player = state.players[playerIndex];
    final minRaiseTo = state.currentBet + state.minRaise;
    final maxRaiseTo = player.currentBet + player.chips;
    if (maxRaiseTo <= minRaiseTo) {
      return null;
    }

    final aggressionFactor = (profile.aggression + strength + bState.tilt).clamp(0, 1);
    
    // Overbet or underbet slightly
    double betVariation = 1.0 + (_random.nextDouble() * 0.4 - 0.2); // 0.8x to 1.2x
    
    final raiseByBlindPart = state.minRaise * (1 + _random.nextInt(2 + (aggressionFactor * 2).round()));
    final raiseByPotPart = (state.pot * (0.08 + (aggressionFactor * 0.24))).round();
    var target = state.currentBet + ((raiseByBlindPart + raiseByPotPart) * betVariation).round();

    if (tier == _HandTier.weak && bState.tilt < 0.5) {
      target = state.currentBet + (raiseByBlindPart * betVariation).round();
    }
    if (tier != _HandTier.strong && target >= maxRaiseTo && bState.tilt < 0.7) {
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
      if (!p.hasFolded && !p.isBusted && !p.isSittingOut) {
        active.add(idx);
      }
    }
    if (active.length <= 2) {
      return _PositionBucket.late;
    }
    final order = active.indexOf(playerIndex);
    final ratio = order / max(1, active.length - 1);
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
    required double tilt,
    required double confidence,
  }) {
    var chance = profile.baseBluffRate;
    if (position == _PositionBucket.late) chance += 0.06;
    if (position == _PositionBucket.early) chance -= 0.03;
    if (toCall > 0) chance -= 0.02;
    if (stackRatio < 0.3) chance -= 0.08;
    chance += opponentAdjustment * 0.3; // More bluff vs weak/passive
    chance += tilt * 0.2; // Tilted players bluff way more
    if (confidence > 0.8) chance += 0.05;
    
    // Unpredictability: Sometimes bluff bad timing
    if (_random.nextDouble() < 0.05) {
      chance += 0.2;
    }
    
    return chance.clamp(0.01, 0.4);
  }

  double _opponentAggressionAdjustment(GameState state, int playerIndex) {
    final opponentRaiseRates = <double>[];
    for (var i = 0; i < state.players.length; i++) {
      if (i == playerIndex) continue;
      final p = state.players[i];
      if (p.hasFolded || p.isBusted || p.isSittingOut) continue;
      
      final tendency = _tendencies[p.id];
      if (tendency == null || tendency.actions < 3) {
        // Assume human is balanced until known
        if (!p.isBot) opponentRaiseRates.add(0.25);
        continue;
      }
      opponentRaiseRates.add(tendency.raiseRate);
    }
    if (opponentRaiseRates.isEmpty) return 0;
    final avg = opponentRaiseRates.reduce((a, b) => a + b) / opponentRaiseRates.length;
    if (avg > 0.34) return -0.15; // Play safer against aggressive
    if (avg < 0.16) return 0.15;  // Bluff more against passive
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
          personality: BotPersonality.nervous,
          tightness: 0.85,
          aggression: 0.15,
          baseBluffRate: 0.02,
        ),
      3 => const _BotProfile(
          personality: BotPersonality.aggressive,
          tightness: 0.25,
          aggression: 0.85,
          baseBluffRate: 0.15,
        ),
      4 => const _BotProfile(
          personality: BotPersonality.tiltProne,
          tightness: 0.45,
          aggression: 0.65,
          baseBluffRate: 0.18,
        ),
      _ => const _BotProfile(
          personality: BotPersonality.calculated,
          tightness: 0.5,
          aggression: 0.5,
          baseBluffRate: 0.08,
        ),
    };
  }

  double _estimateStrength(GameState state, int playerIndex) {
    final player = state.players[playerIndex];
    final cards = [...player.holeCards, ...state.communityCards];
    
    // Intentional misread sometimes
    bool misread = _random.nextDouble() < 0.05;

    if (cards.length >= 5) {
      final value = HandEvaluator.evaluateHandValue(cards);
      var strength = _valueToStrength(value);
      if (misread) strength = (strength + (_random.nextDouble() * 0.4 - 0.2)).clamp(0, 1);
      return strength;
    }

    final ranks = player.holeCards.map((c) => c.rank.value).toList()..sort();
    if (ranks.length < 2) {
      return 0.0;
    }
    final isPair = ranks[0] == ranks[1];
    final high = ranks[1];
    final low = ranks[0];
    final isSuited = player.holeCards[0].suit == player.holeCards[1].suit;
    var score = 0.0;

    if (isPair) {
      score = 0.4 + (high / 30);
    } else {
      score = (high / 40) + (low / 50);
      if (high >= 12 && low >= 10) {
        score += 0.15;
      }
      if ((high - low).abs() <= 2) {
        score += 0.05;
      }
      if (isSuited) {
        score += 0.05;
      }
    }

    score *= 0.85;
    if (misread) score = (score + (_random.nextDouble() * 0.3 - 0.15)).clamp(0, 1);

    return score.clamp(0, 1);
  }

  double _valueToStrength(HandValue value) {
    final base = value.rank.strength / HandRank.values.length;
    final kickerBoost = value.kickers.isEmpty ? 0 : value.kickers.first / 20;
    return (base + (kickerBoost * 0.3)).clamp(0, 1);
  }
}

class _BotState {
  double confidence = 0.5;
  double tilt = 0.0;
  int lastChips = -1;
  int lastHandNumber = -1;
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
