import '../../models/card.dart';
import '../../models/deck.dart';
import '../../models/game_state.dart';
import '../../models/hand_rank.dart';
import '../../models/player.dart';

Map<String, dynamic> gameStateToJson(GameState state) {
  return {
    'players': state.players.map(playerToJson).toList(growable: false),
    'communityCards': state.communityCards.map(cardToJson).toList(growable: false),
    'deck': deckToJson(state.deck),
    'pot': state.pot,
    'dealerIndex': state.dealerIndex,
    'currentTurnIndex': state.currentTurnIndex,
    'currentBet': state.currentBet,
    'minRaise': state.minRaise,
    'smallBlind': state.smallBlind,
    'bigBlind': state.bigBlind,
    'phase': state.phase.name,
    'actedPlayerIndexes': state.actedPlayerIndexes.toList(growable: false),
    'lastChipSourceIndex': state.lastChipSourceIndex,
    'handNumber': state.handNumber,
    'isHandComplete': state.isHandComplete,
    'winnerIndexes': state.winnerIndexes,
    'showdownValues': state.showdownValues.map((k, v) => MapEntry(k.toString(), handValueToJson(v))),
    'handMessage': state.handMessage,
  };
}

GameState gameStateFromJson(Map<String, dynamic> json) {
  return GameState(
    players: (json['players'] as List<dynamic>)
        .map((e) => playerFromJson(Map<String, dynamic>.from(e as Map)))
        .toList(growable: false),
    communityCards: (json['communityCards'] as List<dynamic>)
        .map((e) => cardFromJson(Map<String, dynamic>.from(e as Map)))
        .toList(growable: false),
    deck: deckFromJson(Map<String, dynamic>.from(json['deck'] as Map)),
    pot: json['pot'] as int,
    dealerIndex: json['dealerIndex'] as int,
    currentTurnIndex: json['currentTurnIndex'] as int,
    currentBet: json['currentBet'] as int,
    minRaise: json['minRaise'] as int,
    smallBlind: json['smallBlind'] as int,
    bigBlind: json['bigBlind'] as int,
    phase: BettingRound.values.firstWhere((r) => r.name == json['phase']),
    actedPlayerIndexes: ((json['actedPlayerIndexes'] as List<dynamic>).map((e) => e as int)).toSet(),
    lastChipSourceIndex: json['lastChipSourceIndex'] as int?,
    handNumber: json['handNumber'] as int,
    isHandComplete: json['isHandComplete'] as bool,
    winnerIndexes: ((json['winnerIndexes'] as List<dynamic>).map((e) => e as int)).toList(growable: false),
    showdownValues: (json['showdownValues'] as Map<String, dynamic>).map(
      (key, value) => MapEntry(int.parse(key), handValueFromJson(Map<String, dynamic>.from(value as Map))),
    ),
    handMessage: json['handMessage'] as String? ?? '',
  );
}

Map<String, dynamic> playerToJson(Player player) {
  return {
    'id': player.id,
    'name': player.name,
    'chips': player.chips,
    'isBot': player.isBot,
    'aiLevel': player.aiLevel,
    'holeCards': player.holeCards.map(cardToJson).toList(growable: false),
    'currentBet': player.currentBet,
    'hasFolded': player.hasFolded,
    'isAllIn': player.isAllIn,
    'isBusted': player.isBusted,
    'lastAction': player.lastAction,
  };
}

Player playerFromJson(Map<String, dynamic> json) {
  return Player(
    id: json['id'] as String,
    name: json['name'] as String,
    chips: json['chips'] as int,
    isBot: json['isBot'] as bool? ?? false,
    aiLevel: json['aiLevel'] as int? ?? 0,
    holeCards: (json['holeCards'] as List<dynamic>)
        .map((e) => cardFromJson(Map<String, dynamic>.from(e as Map)))
        .toList(growable: false),
    currentBet: json['currentBet'] as int? ?? 0,
    hasFolded: json['hasFolded'] as bool? ?? false,
    isAllIn: json['isAllIn'] as bool? ?? false,
    isBusted: json['isBusted'] as bool? ?? false,
    lastAction: json['lastAction'] as String? ?? '',
  );
}

Map<String, dynamic> deckToJson(Deck deck) => {
      'cards': deck.cards.map(cardToJson).toList(growable: false),
    };

Deck deckFromJson(Map<String, dynamic> json) {
  return Deck(
    List.unmodifiable(
      (json['cards'] as List<dynamic>)
          .map((e) => cardFromJson(Map<String, dynamic>.from(e as Map)))
          .toList(growable: false),
    ),
  );
}

Map<String, dynamic> cardToJson(Card card) => {
      'rank': card.rank.name,
      'suit': card.suit.name,
    };

Card cardFromJson(Map<String, dynamic> json) {
  return Card(
    rank: CardRank.values.firstWhere((r) => r.name == json['rank']),
    suit: CardSuit.values.firstWhere((s) => s.name == json['suit']),
  );
}

Map<String, dynamic> handValueToJson(HandValue value) => {
      'rank': value.rank.name,
      'kickers': value.kickers,
    };

HandValue handValueFromJson(Map<String, dynamic> json) {
  return HandValue(
    rank: HandRank.values.firstWhere((r) => r.name == json['rank']),
    kickers: ((json['kickers'] as List<dynamic>).map((e) => e as int)).toList(growable: false),
  );
}
