import 'package:flutter_test/flutter_test.dart';
import 'package:pokerly/game/poker_engine.dart';
import 'package:pokerly/models/card.dart';
import 'package:pokerly/models/deck.dart';
import 'package:pokerly/models/game_state.dart';
import 'package:pokerly/models/player.dart';

void main() {
  test('startNewHand deals two cards to active players', () {
    final engine = PokerEngine();
    final state = GameState.initial(
      players: const [
        Player(id: 'h', name: 'Human', chips: 2000, isBot: false, aiLevel: 0),
        Player(id: 'b1', name: 'Bot1', chips: 2000, isBot: true, aiLevel: 1),
        Player(id: 'b2', name: 'Bot2', chips: 2000, isBot: true, aiLevel: 2),
      ],
      smallBlind: 25,
      bigBlind: 50,
    );

    final started = engine.startNewHand(state);
    for (final player in started.players) {
      expect(player.holeCards.length, 2);
    }
    expect(started.pot, greaterThan(0));
    expect(started.phase, BettingRound.preFlop);
  });

  test('fold leaves single winner and completes hand', () {
    final engine = PokerEngine();
    var state = GameState.initial(
      players: const [
        Player(id: 'h', name: 'Human', chips: 2000, isBot: false, aiLevel: 0),
        Player(id: 'b1', name: 'Bot1', chips: 2000, isBot: true, aiLevel: 1),
      ],
      smallBlind: 25,
      bigBlind: 50,
    );
    state = engine.startNewHand(state);

    state = engine.applyAction(state, const PlayerAction(type: PlayerActionType.fold));
    expect(state.isHandComplete, true);
    expect(state.phase, BettingRound.showdown);
    expect(state.winnerIndexes.length, 1);
  });

  test('showdown resolves one side pot correctly', () {
    final engine = PokerEngine();
    final state = GameState(
      players: const [
        Player(
          id: 'p1',
          name: 'P1',
          chips: 0,
          isBot: false,
          aiLevel: 0,
          holeCards: [
            Card(rank: CardRank.jack, suit: CardSuit.hearts),
            Card(rank: CardRank.ten, suit: CardSuit.hearts),
          ],
          currentBet: 0,
        ),
        Player(
          id: 'p2',
          name: 'P2',
          chips: 0,
          isBot: true,
          aiLevel: 1,
          holeCards: [
            Card(rank: CardRank.ace, suit: CardSuit.clubs),
            Card(rank: CardRank.ace, suit: CardSuit.diamonds),
          ],
          currentBet: 0,
        ),
        Player(
          id: 'p3',
          name: 'P3',
          chips: 0,
          isBot: true,
          aiLevel: 1,
          holeCards: [
            Card(rank: CardRank.king, suit: CardSuit.clubs),
            Card(rank: CardRank.king, suit: CardSuit.diamonds),
          ],
          currentBet: 0,
        ),
      ],
      communityCards: const [
        Card(rank: CardRank.ace, suit: CardSuit.hearts),
        Card(rank: CardRank.king, suit: CardSuit.hearts),
        Card(rank: CardRank.queen, suit: CardSuit.hearts),
        Card(rank: CardRank.two, suit: CardSuit.clubs),
        Card(rank: CardRank.three, suit: CardSuit.diamonds),
      ],
      deck: const Deck([]),
      pot: 2200,
      dealerIndex: 0,
      currentTurnIndex: 0,
      currentBet: 0,
      minRaise: 50,
      smallBlind: 25,
      bigBlind: 50,
      phase: BettingRound.river,
      actedPlayerIndexes: const {1, 2},
      lastChipSourceIndex: null,
      handNumber: 1,
      isHandComplete: false,
      winnerIndexes: const [],
      showdownValues: const {},
      handMessage: '',
      totalContributions: const [200, 1000, 1000],
      isTournamentMode: false,
      handsPerLevel: 5,
      blindLevel: 1,
      initialSmallBlind: 25,
      initialBigBlind: 50,
    );

    final resolved = engine.applyAction(state, const PlayerAction(type: PlayerActionType.check));
    expect(resolved.isHandComplete, true);
    expect(resolved.players[0].chips, 600);
    expect(resolved.players[1].chips, 1600);
    expect(resolved.players[2].chips, 0);
  });

  test('showdown splits tied side pot correctly', () {
    final engine = PokerEngine();
    final state = GameState(
      players: const [
        Player(
          id: 'p1',
          name: 'P1',
          chips: 0,
          isBot: false,
          aiLevel: 0,
          holeCards: [
            Card(rank: CardRank.three, suit: CardSuit.hearts),
            Card(rank: CardRank.four, suit: CardSuit.diamonds),
          ],
          currentBet: 0,
        ),
        Player(
          id: 'p2',
          name: 'P2',
          chips: 0,
          isBot: true,
          aiLevel: 1,
          holeCards: [
            Card(rank: CardRank.nine, suit: CardSuit.clubs),
            Card(rank: CardRank.eight, suit: CardSuit.clubs),
          ],
          currentBet: 0,
        ),
        Player(
          id: 'p3',
          name: 'P3',
          chips: 0,
          isBot: true,
          aiLevel: 1,
          holeCards: [
            Card(rank: CardRank.nine, suit: CardSuit.spades),
            Card(rank: CardRank.eight, suit: CardSuit.spades),
          ],
          currentBet: 0,
        ),
      ],
      communityCards: const [
        Card(rank: CardRank.ace, suit: CardSuit.hearts),
        Card(rank: CardRank.king, suit: CardSuit.diamonds),
        Card(rank: CardRank.queen, suit: CardSuit.clubs),
        Card(rank: CardRank.two, suit: CardSuit.spades),
        Card(rank: CardRank.seven, suit: CardSuit.hearts),
      ],
      deck: const Deck([]),
      pot: 2200,
      dealerIndex: 0,
      currentTurnIndex: 0,
      currentBet: 0,
      minRaise: 50,
      smallBlind: 25,
      bigBlind: 50,
      phase: BettingRound.river,
      actedPlayerIndexes: const {1, 2},
      lastChipSourceIndex: null,
      handNumber: 1,
      isHandComplete: false,
      winnerIndexes: const [],
      showdownValues: const {},
      handMessage: '',
      totalContributions: const [200, 1000, 1000],
      isTournamentMode: false,
      handsPerLevel: 5,
      blindLevel: 1,
      initialSmallBlind: 25,
      initialBigBlind: 50,
    );

    final resolved = engine.applyAction(state, const PlayerAction(type: PlayerActionType.check));
    expect(resolved.isHandComplete, true);
    expect(resolved.players[0].chips, 0);
    expect(resolved.players[1].chips, 1100);
    expect(resolved.players[2].chips, 1100);
  });

  test('tournament mode increases blinds by level', () {
    final engine = PokerEngine();
    var state = GameState.initial(
      players: const [
        Player(id: 'h', name: 'Human', chips: 2000, isBot: false, aiLevel: 0),
        Player(id: 'b1', name: 'Bot1', chips: 2000, isBot: true, aiLevel: 1),
        Player(id: 'b2', name: 'Bot2', chips: 2000, isBot: true, aiLevel: 2),
      ],
      smallBlind: 25,
      bigBlind: 50,
      isTournamentMode: true,
      handsPerLevel: 2,
    );

    state = engine.startNewHand(state);
    expect(state.smallBlind, 25);
    expect(state.bigBlind, 50);
    expect(state.blindLevel, 1);

    state = engine.startNewHand(state);
    expect(state.smallBlind, 25);
    expect(state.bigBlind, 50);
    expect(state.blindLevel, 1);

    state = engine.startNewHand(state);
    expect(state.smallBlind, 50);
    expect(state.bigBlind, 100);
    expect(state.blindLevel, 2);
  });
}
