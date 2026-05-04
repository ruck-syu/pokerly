import 'card.dart';

class Player {
  const Player({
    required this.id,
    required this.name,
    required this.chips,
    required this.isBot,
    required this.aiLevel,
    this.holeCards = const [],
    this.currentBet = 0,
    this.hasFolded = false,
    this.isAllIn = false,
    this.isBusted = false,
    this.lastAction = '',
  });

  final String id;
  final String name;
  final int chips;
  final bool isBot;
  final int aiLevel;
  final List<Card> holeCards;
  final int currentBet;
  final bool hasFolded;
  final bool isAllIn;
  final bool isBusted;
  final String lastAction;

  Player copyWith({
    String? id,
    String? name,
    int? chips,
    bool? isBot,
    int? aiLevel,
    List<Card>? holeCards,
    int? currentBet,
    bool? hasFolded,
    bool? isAllIn,
    bool? isBusted,
    String? lastAction,
  }) {
    return Player(
      id: id ?? this.id,
      name: name ?? this.name,
      chips: chips ?? this.chips,
      isBot: isBot ?? this.isBot,
      aiLevel: aiLevel ?? this.aiLevel,
      holeCards: holeCards ?? this.holeCards,
      currentBet: currentBet ?? this.currentBet,
      hasFolded: hasFolded ?? this.hasFolded,
      isAllIn: isAllIn ?? this.isAllIn,
      isBusted: isBusted ?? this.isBusted,
      lastAction: lastAction ?? this.lastAction,
    );
  }
}
