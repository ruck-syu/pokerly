import 'package:flutter_test/flutter_test.dart';
import 'package:pokerly/game/poker_engine.dart';
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
}
