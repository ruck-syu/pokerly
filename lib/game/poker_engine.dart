import '../models/deck.dart';
import '../models/game_state.dart';
import '../models/hand_rank.dart';
import '../models/player.dart';
import 'hand_evaluator.dart';

enum PlayerActionType { fold, check, call, raise }

class PlayerAction {
  const PlayerAction({required this.type, this.raiseTo});

  final PlayerActionType type;
  final int? raiseTo;
}

class PokerEngine {
  GameState startNewHand(GameState previousState) {
    final nextHandNumber = previousState.handNumber + 1;
    final tournamentLevel = previousState.isTournamentMode
        ? (((nextHandNumber - 1) ~/ previousState.handsPerLevel) + 1)
        : 1;
    final blindMultiplier = previousState.isTournamentMode ? (1 << (tournamentLevel - 1)) : 1;
    final appliedSmallBlind = previousState.initialSmallBlind * blindMultiplier;
    final appliedBigBlind = previousState.initialBigBlind * blindMultiplier;

    final players = previousState.players.map((p) {
      final busted = p.chips <= 0;
      return p.copyWith(
        holeCards: const [],
        currentBet: 0,
        hasFolded: false,
        isAllIn: false,
        isBusted: busted,
        lastAction: busted ? 'Out' : '',
      );
    }).toList(growable: false);

    final active = _activePlayerIndexes(players);
    if (active.length < 2) {
      return previousState.copyWith(
        players: players,
        isHandComplete: true,
        phase: BettingRound.showdown,
        handMessage: active.isEmpty ? 'No players with chips.' : '${players[active.first].name} wins the match.',
      );
    }

    final dealerIndex = _nextFrom(previousState.dealerIndex, players, includeCurrent: false);
    final smallBlindIndex = _nextFrom(dealerIndex, players, includeCurrent: false);
    final bigBlindIndex = _nextFrom(smallBlindIndex, players, includeCurrent: false);

    var deck = Deck.standard52();
    var updatedPlayers = players.toList();
    final contributions = List<int>.filled(players.length, 0, growable: false);

    for (var round = 0; round < 2; round++) {
      for (final index in _orderedFrom(dealerIndex, players)) {
        if (updatedPlayers[index].isBusted) {
          continue;
        }
        final drawResult = deck.draw();
        deck = drawResult.deck;
        final card = drawResult.cards.single;
        updatedPlayers[index] = updatedPlayers[index].copyWith(
          holeCards: [...updatedPlayers[index].holeCards, card],
        );
      }
    }

    var pot = 0;
    final sbCommit = updatedPlayers[smallBlindIndex].chips < appliedSmallBlind
        ? updatedPlayers[smallBlindIndex].chips
        : appliedSmallBlind;
    updatedPlayers[smallBlindIndex] = _commitChips(
      updatedPlayers[smallBlindIndex],
      sbCommit,
      action: 'SB $sbCommit',
    );
    contributions[smallBlindIndex] += sbCommit;
    pot += sbCommit;

    final bbCommit = updatedPlayers[bigBlindIndex].chips < appliedBigBlind
        ? updatedPlayers[bigBlindIndex].chips
        : appliedBigBlind;
    updatedPlayers[bigBlindIndex] = _commitChips(
      updatedPlayers[bigBlindIndex],
      bbCommit,
      action: 'BB $bbCommit',
    );
    contributions[bigBlindIndex] += bbCommit;
    pot += bbCommit;

    final currentBet = bbCommit > sbCommit ? bbCommit : sbCommit;
    final firstToAct = _nextToActFrom(bigBlindIndex, updatedPlayers);

    return previousState.copyWith(
      players: updatedPlayers,
      deck: deck,
      communityCards: const [],
      pot: pot,
      dealerIndex: dealerIndex,
      currentTurnIndex: firstToAct,
      currentBet: currentBet,
      minRaise: appliedBigBlind,
      phase: BettingRound.preFlop,
      actedPlayerIndexes: const <int>{},
      lastChipSourceIndex: bigBlindIndex,
      handNumber: nextHandNumber,
      isHandComplete: false,
      winnerIndexes: const [],
      showdownValues: const {},
      handMessage: previousState.isTournamentMode
          ? 'Hand $nextHandNumber • Level $tournamentLevel'
          : 'Hand $nextHandNumber',
      totalContributions: contributions,
      smallBlind: appliedSmallBlind,
      bigBlind: appliedBigBlind,
      blindLevel: tournamentLevel,
    );
  }

  GameState applyAction(GameState state, PlayerAction action) {
    if (state.isHandComplete) {
      return state;
    }

    final actorIndex = state.currentTurnIndex;
    final actor = state.players[actorIndex];
    if (actor.hasFolded || actor.isAllIn || actor.isBusted) {
      return _advanceTurn(state);
    }

    final toCall = state.currentBet - actor.currentBet;
    var players = state.players.toList();
    var pot = state.pot;
    var currentBet = state.currentBet;
    var minRaise = state.minRaise;
    var acted = state.actedPlayerIndexes.toSet();
    var chipSource = state.lastChipSourceIndex;
    var message = state.handMessage;
    final totalContributions = state.totalContributions.toList(growable: false);

    switch (action.type) {
      case PlayerActionType.fold:
        players[actorIndex] = actor.copyWith(hasFolded: true, lastAction: 'Fold');
        acted.add(actorIndex);
        break;
      case PlayerActionType.check:
        if (toCall > 0) {
          return state;
        }
        players[actorIndex] = actor.copyWith(lastAction: 'Check');
        acted.add(actorIndex);
        break;
      case PlayerActionType.call:
        if (toCall <= 0) {
          players[actorIndex] = actor.copyWith(lastAction: 'Check');
          acted.add(actorIndex);
          break;
        }
        final commit = actor.chips < toCall ? actor.chips : toCall;
        players[actorIndex] = _commitChips(actor, commit, action: 'Call $commit');
        totalContributions[actorIndex] += commit;
        pot += commit;
        chipSource = actorIndex;
        acted.add(actorIndex);
        break;
      case PlayerActionType.raise:
        final raiseTo = action.raiseTo;
        if (raiseTo == null) {
          return state;
        }
        final maxReach = actor.currentBet + actor.chips;
        var legalRaiseTo = raiseTo;
        if (legalRaiseTo > maxReach) {
          legalRaiseTo = maxReach;
        }
        final minLegalRaiseTo = currentBet + minRaise;
        if (legalRaiseTo < minLegalRaiseTo && legalRaiseTo != maxReach) {
          return state;
        }
        final commit = legalRaiseTo - actor.currentBet;
        if (commit <= 0) {
          return state;
        }
        players[actorIndex] = _commitChips(actor, commit, action: 'Raise $legalRaiseTo');
        totalContributions[actorIndex] += commit;
        pot += commit;
        final raiseSize = legalRaiseTo - currentBet;
        if (raiseSize > 0) {
          minRaise = raiseSize;
        }
        currentBet = legalRaiseTo;
        chipSource = actorIndex;
        acted = <int>{actorIndex};
        break;
    }

    final activeNotFolded = _contendingPlayers(players);
    if (activeNotFolded.length == 1) {
      final winnerIndex = players.indexOf(activeNotFolded.single);
      final winner = players[winnerIndex];
      players[winnerIndex] = winner.copyWith(chips: winner.chips + pot, lastAction: 'Won $pot');
      return state.copyWith(
        players: players,
        pot: pot,
        phase: BettingRound.showdown,
        isHandComplete: true,
        winnerIndexes: [winnerIndex],
        showdownValues: const {},
        handMessage: '${winner.name} wins $pot (everyone else folded).',
        totalContributions: totalContributions,
      );
    }

    var updated = state.copyWith(
      players: players,
      pot: pot,
      currentBet: currentBet,
      minRaise: minRaise,
      actedPlayerIndexes: acted,
      lastChipSourceIndex: chipSource,
      handMessage: message,
      totalContributions: totalContributions,
    );

    if (_isBettingRoundComplete(updated)) {
      updated = _advanceRound(updated);
    } else {
      updated = _advanceTurn(updated);
    }
    return updated;
  }

  GameState _advanceRound(GameState state) {
    if (state.phase == BettingRound.river) {
      return _resolveShowdown(state);
    }

    var deck = state.deck;
    var community = state.communityCards.toList();
    final players = state.players.map((p) => p.copyWith(currentBet: 0)).toList(growable: false);

    if (state.phase == BettingRound.preFlop) {
      final drawResult = deck.draw(3);
      deck = drawResult.deck;
      community.addAll(drawResult.cards);
    } else {
      final drawResult = deck.draw();
      deck = drawResult.deck;
      community.add(drawResult.cards.single);
    }

    final nextPhase = switch (state.phase) {
      BettingRound.preFlop => BettingRound.flop,
      BettingRound.flop => BettingRound.turn,
      BettingRound.turn => BettingRound.river,
      BettingRound.river => BettingRound.showdown,
      BettingRound.showdown => BettingRound.showdown,
    };

    final firstToAct = _nextToActFrom(state.dealerIndex, players);
    var updated = state.copyWith(
      players: players,
      deck: deck,
      communityCards: community,
      currentBet: 0,
      minRaise: state.bigBlind,
      currentTurnIndex: firstToAct,
      phase: nextPhase,
      actedPlayerIndexes: const <int>{},
      clearChipSource: true,
    );

    if (!_anyCanAct(updated.players)) {
      while (updated.phase != BettingRound.river && updated.phase != BettingRound.showdown) {
        updated = _advanceRound(updated);
      }
      if (updated.phase == BettingRound.showdown) {
        return updated;
      }
      return _resolveShowdown(updated);
    }

    return updated;
  }

  GameState _resolveShowdown(GameState state) {
    final contenders = <int, Player>{};
    for (var i = 0; i < state.players.length; i++) {
      final p = state.players[i];
      if (!p.hasFolded && !p.isBusted) {
        contenders[i] = p;
      }
    }

    final handValues = <int, HandValue>{};
    for (final entry in contenders.entries) {
      handValues[entry.key] = HandEvaluator.evaluateHandValue(
        [...entry.value.holeCards, ...state.communityCards],
      );
    }

    final players = state.players.toList();
    final winners = _resolveSidePots(
      state: state,
      handValues: handValues,
      players: players,
    );
    final winnerNames = winners.map((i) => players[i].name).join(', ');
    final isSplit = winners.length > 1;
    return state.copyWith(
      players: players,
      phase: BettingRound.showdown,
      isHandComplete: true,
      winnerIndexes: winners,
      showdownValues: handValues,
      handMessage: winnerNames.isEmpty 
          ? 'Showdown resolved.' 
          : (isSplit ? 'Split pot: $winnerNames' : '$winnerNames won at showdown'),
      clearChipSource: true,
    );
  }

  List<int> _resolveSidePots({
    required GameState state,
    required Map<int, HandValue> handValues,
    required List<Player> players,
  }) {
    final contributions = state.totalContributions;
    final positiveLevels = contributions.where((c) => c > 0).toSet().toList()..sort();
    final winners = <int>{};
    var previousLevel = 0;

    for (final level in positiveLevels) {
      final participants = <int>[];
      for (var i = 0; i < contributions.length; i++) {
        if (contributions[i] >= level) {
          participants.add(i);
        }
      }
      final potAmount = (level - previousLevel) * participants.length;
      previousLevel = level;
      if (potAmount <= 0) {
        continue;
      }

      final eligible = participants.where((i) => !players[i].hasFolded && !players[i].isBusted).toList(growable: false);
      if (eligible.isEmpty) {
        continue;
      }
      final potWinners = _bestIndexes(eligible, handValues);
      final share = potAmount ~/ potWinners.length;
      final remainder = potAmount % potWinners.length;

      for (var i = 0; i < potWinners.length; i++) {
        final winnerIndex = potWinners[i];
        final bonus = i < remainder ? 1 : 0;
        final winner = players[winnerIndex];
        
        final currentWonMatch = RegExp(r'Won (\d+)').firstMatch(winner.lastAction);
        final previouslyWon = currentWonMatch != null ? int.parse(currentWonMatch.group(1)!) : 0;
        final totalWon = previouslyWon + share + bonus;

        players[winnerIndex] = winner.copyWith(
          chips: winner.chips + share + bonus,
          lastAction: 'Won $totalWon',
        );
        winners.add(winnerIndex);
      }
    }

    return winners.toList(growable: false);
  }

  List<int> _bestIndexes(List<int> candidates, Map<int, HandValue> values) {
    HandValue? best;
    final bestIndexes = <int>[];
    for (final index in candidates) {
      final value = values[index];
      if (value == null) continue;
      if (best == null) {
        best = value;
        bestIndexes
          ..clear()
          ..add(index);
        continue;
      }
      final cmp = value.compareTo(best);
      if (cmp > 0) {
        best = value;
        bestIndexes
          ..clear()
          ..add(index);
      } else if (cmp == 0) {
        bestIndexes.add(index);
      }
    }
    return bestIndexes;
  }

  bool _isBettingRoundComplete(GameState state) {
    for (var i = 0; i < state.players.length; i++) {
      final player = state.players[i];
      if (player.hasFolded || player.isBusted || player.isAllIn) {
        continue;
      }
      if (player.currentBet != state.currentBet) {
        return false;
      }
      if (!state.actedPlayerIndexes.contains(i)) {
        return false;
      }
    }
    return true;
  }

  GameState _advanceTurn(GameState state) {
    final nextIndex = _nextToActFrom(state.currentTurnIndex, state.players);
    return state.copyWith(currentTurnIndex: nextIndex);
  }

  List<int> _orderedFrom(int startIndex, List<Player> players) {
    final ordered = <int>[];
    for (var step = 1; step <= players.length; step++) {
      final idx = (startIndex + step) % players.length;
      if (!players[idx].isBusted) {
        ordered.add(idx);
      }
    }
    return ordered;
  }

  List<int> _activePlayerIndexes(List<Player> players) {
    return List<int>.generate(players.length, (i) => i)
        .where((i) => players[i].chips > 0 && !players[i].isBusted)
        .toList();
  }

  List<Player> _contendingPlayers(List<Player> players) {
    return players.where((p) => !p.hasFolded && !p.isBusted).toList();
  }

  int _nextFrom(int from, List<Player> players, {required bool includeCurrent}) {
    for (var step = includeCurrent ? 0 : 1; step <= players.length; step++) {
      final idx = (from + step) % players.length;
      if (!players[idx].isBusted && !players[idx].isSittingOut && players[idx].chips > 0) {
        return idx;
      }
    }
    return from;
  }

  int _nextToActFrom(int from, List<Player> players) {
    for (var step = 1; step <= players.length; step++) {
      final idx = (from + step) % players.length;
      final p = players[idx];
      if (!p.isBusted && !p.hasFolded && !p.isAllIn) {
        return idx;
      }
    }
    return from;
  }

  bool _anyCanAct(List<Player> players) {
    return players.any((p) => !p.isBusted && !p.hasFolded && !p.isAllIn);
  }

  Player _commitChips(Player player, int amount, {required String action}) {
    final chips = player.chips - amount;
    return player.copyWith(
      chips: chips,
      currentBet: player.currentBet + amount,
      isAllIn: chips == 0,
      lastAction: action,
    );
  }
}
