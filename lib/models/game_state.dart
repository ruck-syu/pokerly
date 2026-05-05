import 'deck.dart';
import 'card.dart';
import 'hand_rank.dart';
import 'player.dart';

enum BettingRound { preFlop, flop, turn, river, showdown }

class GameState {
  const GameState({
    required this.players,
    required this.communityCards,
    required this.deck,
    required this.pot,
    required this.dealerIndex,
    required this.currentTurnIndex,
    required this.currentBet,
    required this.minRaise,
    required this.smallBlind,
    required this.bigBlind,
    required this.phase,
    required this.actedPlayerIndexes,
    required this.lastChipSourceIndex,
    required this.handNumber,
    required this.isHandComplete,
    required this.winnerIndexes,
    required this.showdownValues,
    required this.handMessage,
    required this.totalContributions,
    required this.isTournamentMode,
    required this.handsPerLevel,
    required this.blindLevel,
    required this.initialSmallBlind,
    required this.initialBigBlind,
  });

  final List<Player> players;
  final List<Card> communityCards;
  final Deck deck;
  final int pot;
  final int dealerIndex;
  final int currentTurnIndex;
  final int currentBet;
  final int minRaise;
  final int smallBlind;
  final int bigBlind;
  final BettingRound phase;
  final Set<int> actedPlayerIndexes;
  final int? lastChipSourceIndex;
  final int handNumber;
  final bool isHandComplete;
  final List<int> winnerIndexes;
  final Map<int, HandValue> showdownValues;
  final String handMessage;
  final List<int> totalContributions;
  final bool isTournamentMode;
  final int handsPerLevel;
  final int blindLevel;
  final int initialSmallBlind;
  final int initialBigBlind;

  factory GameState.initial({
    required List<Player> players,
    required int smallBlind,
    required int bigBlind,
    bool isTournamentMode = false,
    int handsPerLevel = 5,
  }) {
    return GameState(
      players: List.unmodifiable(players),
      communityCards: const [],
      deck: Deck.standard52(),
      pot: 0,
      dealerIndex: 0,
      currentTurnIndex: 0,
      currentBet: 0,
      minRaise: bigBlind,
      smallBlind: smallBlind,
      bigBlind: bigBlind,
      phase: BettingRound.preFlop,
      actedPlayerIndexes: const <int>{},
      lastChipSourceIndex: null,
      handNumber: 0,
      isHandComplete: false,
      winnerIndexes: const [],
      showdownValues: const {},
      handMessage: '',
      totalContributions: List<int>.filled(players.length, 0, growable: false),
      isTournamentMode: isTournamentMode,
      handsPerLevel: handsPerLevel,
      blindLevel: 1,
      initialSmallBlind: smallBlind,
      initialBigBlind: bigBlind,
    );
  }

  Player get currentPlayer => players[currentTurnIndex];

  int get humanPlayerIndex => players.indexWhere((p) => !p.isBot);

  GameState copyWith({
    List<Player>? players,
    List<Card>? communityCards,
    Deck? deck,
    int? pot,
    int? dealerIndex,
    int? currentTurnIndex,
    int? currentBet,
    int? minRaise,
    int? smallBlind,
    int? bigBlind,
    BettingRound? phase,
    Set<int>? actedPlayerIndexes,
    int? lastChipSourceIndex,
    bool clearChipSource = false,
    int? handNumber,
    bool? isHandComplete,
    List<int>? winnerIndexes,
    Map<int, HandValue>? showdownValues,
    String? handMessage,
    List<int>? totalContributions,
    bool? isTournamentMode,
    int? handsPerLevel,
    int? blindLevel,
    int? initialSmallBlind,
    int? initialBigBlind,
  }) {
    return GameState(
      players: List.unmodifiable(players ?? this.players),
      communityCards: List.unmodifiable(communityCards ?? this.communityCards),
      deck: deck ?? this.deck,
      pot: pot ?? this.pot,
      dealerIndex: dealerIndex ?? this.dealerIndex,
      currentTurnIndex: currentTurnIndex ?? this.currentTurnIndex,
      currentBet: currentBet ?? this.currentBet,
      minRaise: minRaise ?? this.minRaise,
      smallBlind: smallBlind ?? this.smallBlind,
      bigBlind: bigBlind ?? this.bigBlind,
      phase: phase ?? this.phase,
      actedPlayerIndexes: Set.unmodifiable(actedPlayerIndexes ?? this.actedPlayerIndexes),
      lastChipSourceIndex: clearChipSource ? null : (lastChipSourceIndex ?? this.lastChipSourceIndex),
      handNumber: handNumber ?? this.handNumber,
      isHandComplete: isHandComplete ?? this.isHandComplete,
      winnerIndexes: List.unmodifiable(winnerIndexes ?? this.winnerIndexes),
      showdownValues: Map.unmodifiable(showdownValues ?? this.showdownValues),
      handMessage: handMessage ?? this.handMessage,
      totalContributions: List.unmodifiable(totalContributions ?? this.totalContributions),
      isTournamentMode: isTournamentMode ?? this.isTournamentMode,
      handsPerLevel: handsPerLevel ?? this.handsPerLevel,
      blindLevel: blindLevel ?? this.blindLevel,
      initialSmallBlind: initialSmallBlind ?? this.initialSmallBlind,
      initialBigBlind: initialBigBlind ?? this.initialBigBlind,
    );
  }
}
