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
    final sbCommit = updatedPlayers[smallBlindIndex].chips < previousState.smallBlind
        ? updatedPlayers[smallBlindIndex].chips
        : previousState.smallBlind;
    updatedPlayers[smallBlindIndex] = _commitChips(
      updatedPlayers[smallBlindIndex],
      sbCommit,
      action: 'SB $sbCommit',
    );
    pot += sbCommit;

    final bbCommit = updatedPlayers[bigBlindIndex].chips < previousState.bigBlind
        ? updatedPlayers[bigBlindIndex].chips
        : previousState.bigBlind;
    updatedPlayers[bigBlindIndex] = _commitChips(
      updatedPlayers[bigBlindIndex],
      bbCommit,
      action: 'BB $bbCommit',
    );
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
      minRaise: previousState.bigBlind,
      phase: BettingRound.preFlop,
      actedPlayerIndexes: const <int>{},
      lastChipSourceIndex: bigBlindIndex,
      handNumber: previousState.handNumber + 1,
      isHandComplete: false,
      winnerIndexes: const [],
      showdownValues: const {},
      handMessage: 'Hand ${previousState.handNumber + 1}',
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
      while (updated.phase != BettingRound.river) {
        updated = _advanceRound(updated);
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

    HandValue? best;
    for (final value in handValues.values) {
      if (best == null || value.compareTo(best) > 0) {
        best = value;
      }
    }

    final winners = handValues.entries.where((e) => e.value.compareTo(best!) == 0).map((e) => e.key).toList();
    final share = state.pot ~/ winners.length;
    final remainder = state.pot % winners.length;

    final players = state.players.toList();
    for (var i = 0; i < winners.length; i++) {
      final winnerIndex = winners[i];
      final bonus = i == 0 ? remainder : 0;
      final winner = players[winnerIndex];
      players[winnerIndex] = winner.copyWith(
        chips: winner.chips + share + bonus,
        lastAction: 'Won ${share + bonus}',
      );
    }

    final winnerNames = winners.map((i) => players[i].name).join(', ');
    final handName = best?.describe() ?? 'Showdown';
    return state.copyWith(
      players: players,
      phase: BettingRound.showdown,
      isHandComplete: true,
      winnerIndexes: winners,
      showdownValues: handValues,
      handMessage: '$winnerNames won with $handName',
      clearChipSource: true,
    );
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
      if (!players[idx].isBusted && players[idx].chips > 0) {
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
